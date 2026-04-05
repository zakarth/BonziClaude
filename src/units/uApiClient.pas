unit uApiClient;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TBuddyReactParams = record
    Name: string;
    Personality: string;
    Species: string;
    Rarity: string;
    Stats: string;          // JSON object as string, e.g. {"DEBUGGING":50,...}
    Transcript: string;
    Reason: string;         // turn, error, test-fail, large-diff, hatch
    Recent: array of string;
    Addressed: Boolean;
  end;

  TBuddyReactResult = record
    Success: Boolean;
    Reaction: string;
    ErrorMsg: string;
    HttpStatus: Integer;
  end;

function BuddyReact(const AParams: TBuddyReactParams;
                     const AAccessToken, AOrgUuid: string): TBuddyReactResult;

function RefreshAccessToken(const ARefreshToken: string): string;

procedure EnsureSSL;

type
  TBuddyReactCallback = procedure(const AResult: TBuddyReactResult) of object;

  TBuddyReactThread = class(TThread)
  private
    FParams: TBuddyReactParams;
    FAccessToken: string;
    FOrgUuid: string;
    FResult: TBuddyReactResult;
    FCallback: TBuddyReactCallback;
    procedure DoCallback;
  protected
    procedure Execute; override;
  public
    constructor Create(const AParams: TBuddyReactParams;
                       const AAccessToken, AOrgUuid: string;
                       ACallback: TBuddyReactCallback);
  end;

implementation

uses
  fpjson, jsonparser, fphttpclient, ssockets, opensslsockets, openssl,
  dynlibs,
  {$IFDEF UNIX}BaseUnix,{$ENDIF}
  uValidation, uCredentials;

var
  SSLInitDone: Boolean = False;

procedure EnsureSSL;
{$IFDEF UNIX}
var
  LinkDir: string;
{$ENDIF}
begin
  if SSLInitDone then Exit;
  SSLInitDone := True;

  if IsSSLloaded then Exit;

  {$IFDEF UNIX}
  // FPC 3.2.2 on Unix tries libssl.so, libssl.so.1.1, etc. but never .so.3.
  // Fix: symlink libssl.so -> libssl.so.3 in a temp dir.
  LinkDir := '/tmp/bonziclaude-ssl';
  ForceDirectories(LinkDir);
  if not FileExists(LinkDir + '/libssl.so') then
  begin
    if FileExists('/lib/x86_64-linux-gnu/libssl.so.3') then
    begin
      fpSymlink('/lib/x86_64-linux-gnu/libssl.so.3', PChar(LinkDir + '/libssl.so'));
      fpSymlink('/lib/x86_64-linux-gnu/libcrypto.so.3', PChar(LinkDir + '/libcrypto.so'));
    end
    else if FileExists('/usr/lib/x86_64-linux-gnu/libssl.so.3') then
    begin
      fpSymlink('/usr/lib/x86_64-linux-gnu/libssl.so.3', PChar(LinkDir + '/libssl.so'));
      fpSymlink('/usr/lib/x86_64-linux-gnu/libcrypto.so.3', PChar(LinkDir + '/libcrypto.so'));
    end;
  end;
  DLLSSLName := LinkDir + '/libssl';
  DLLUtilName := LinkDir + '/libcrypto';
  {$ENDIF}

  {$IFDEF WINDOWS}
  // FPC 3.2.2 on Win64 tries ssleay32.dll, libssl32.dll, libssl-1_1-x64.dll.
  // OpenSSL 3 uses libssl-3-x64.dll / libcrypto-3-x64.dll.
  // Try OpenSSL 3 names first, then let FPC's defaults handle 1.1.
  if LoadLibrary('libssl-3-x64.dll') <> NilHandle then
  begin
    DLLSSLName := 'libssl-3-x64.dll';
    DLLUtilName := 'libcrypto-3-x64.dll';
  end
  else if LoadLibrary('libssl-3.dll') <> NilHandle then
  begin
    DLLSSLName := 'libssl-3.dll';
    DLLUtilName := 'libcrypto-3.dll';
  end;
  // else: leave defaults for OpenSSL 1.1
  {$ENDIF}

  InitSSLInterface;
end;

function BuildPayload(const AParams: TBuddyReactParams): string;
var
  Obj, StatsObj: TJSONObject;
  RecentArr: TJSONArray;
  StatsData: TJSONData;
  StatsParser: TJSONParser;
  I, Count: Integer;
  SS: TStringStream;
begin
  Obj := TJSONObject.Create;
  try
    Obj.Add('name', ValidateName(AParams.Name));
    Obj.Add('personality', ValidatePersonality(AParams.Personality));
    Obj.Add('species', AParams.Species);
    Obj.Add('rarity', AParams.Rarity);

    // Parse stats JSON string
    if AParams.Stats <> '' then
    begin
      SS := TStringStream.Create(AParams.Stats);
      try
        StatsParser := TJSONParser.Create(SS);
        try
          StatsData := StatsParser.Parse;
          if StatsData is TJSONObject then
            Obj.Add('stats', StatsData.Clone)
          else
          begin
            StatsData.Free;
            Obj.Add('stats', TJSONObject.Create);
          end;
          StatsData.Free;
        finally
          StatsParser.Free;
        end;
      finally
        SS.Free;
      end;
    end
    else
      Obj.Add('stats', TJSONObject.Create);

    Obj.Add('transcript', ValidateTranscript(AParams.Transcript));
    Obj.Add('reason', AParams.Reason);

    RecentArr := TJSONArray.Create;
    Count := Length(AParams.Recent);
    if Count > MAX_RECENT_COUNT then
      Count := MAX_RECENT_COUNT;
    for I := 0 to Count - 1 do
      RecentArr.Add(ValidateRecentEntry(AParams.Recent[I]));
    Obj.Add('recent', RecentArr);

    Obj.Add('addressed', AParams.Addressed);

    Result := Obj.AsJSON;
  finally
    Obj.Free;
  end;
end;

function BuddyReact(const AParams: TBuddyReactParams;
                     const AAccessToken, AOrgUuid: string): TBuddyReactResult;
var
  Client: TFPHTTPClient;
  URL, Payload, Response: string;
  ResponseStream: TStringStream;
  ResponseData: TJSONData;
  ResponseObj: TJSONObject;
begin
  Result.Success := False;
  Result.Reaction := '';
  Result.ErrorMsg := '';
  Result.HttpStatus := 0;

  if (AAccessToken = '') or (AOrgUuid = '') then
  begin
    Result.ErrorMsg := 'Missing access token or org UUID';
    Exit;
  end;

  EnsureSSL;

  URL := API_BASE_URL + '/api/organizations/' + AOrgUuid + '/claude_code/buddy_react';
  Payload := BuildPayload(AParams);

  Client := TFPHTTPClient.Create(nil);
  try
    Client.AddHeader('Authorization', 'Bearer ' + AAccessToken);
    Client.AddHeader('anthropic-beta', BETA_HEADER);
    Client.AddHeader('Content-Type', 'application/json');
    Client.IOTimeout := 10000;
    Client.ConnectTimeout := 5000;

    ResponseStream := TStringStream.Create('');
    try
      try
        Client.RequestBody := TStringStream.Create(Payload);
        Client.Post(URL, ResponseStream);
        Result.HttpStatus := Client.ResponseStatusCode;

        if Client.ResponseStatusCode = 200 then
        begin
          Response := ResponseStream.DataString;
          ResponseData := GetJSON(Response);
          try
            if ResponseData is TJSONObject then
            begin
              ResponseObj := TJSONObject(ResponseData);
              Result.Reaction := Trim(ResponseObj.Get('reaction', ''));
              Result.Success := True;
            end;
          finally
            ResponseData.Free;
          end;
        end
        else
        begin
          Result.ErrorMsg := Format('HTTP %d: %s',
            [Client.ResponseStatusCode, ResponseStream.DataString]);
        end;
      except
        on E: Exception do
          Result.ErrorMsg := E.Message;
      end;
    finally
      ResponseStream.Free;
    end;
  finally
    Client.Free;
  end;
end;

function RefreshAccessToken(const ARefreshToken: string): string;
var
  Client: TFPHTTPClient;
  Payload, Response: string;
  ResponseStream: TStringStream;
  Obj: TJSONObject;
  ResponseData: TJSONData;
begin
  Result := '';
  EnsureSSL;

  Obj := TJSONObject.Create;
  try
    Obj.Add('grant_type', 'refresh_token');
    Obj.Add('refresh_token', ARefreshToken);
    Obj.Add('client_id', OAUTH_CLIENT_ID);
    Obj.Add('scope', DEFAULT_SCOPES);
    Payload := Obj.AsJSON;
  finally
    Obj.Free;
  end;

  Client := TFPHTTPClient.Create(nil);
  try
    Client.AddHeader('Content-Type', 'application/json');
    Client.IOTimeout := 15000;

    ResponseStream := TStringStream.Create('');
    try
      try
        Client.RequestBody := TStringStream.Create(Payload);
        Client.Post(TOKEN_URL, ResponseStream);

        if Client.ResponseStatusCode = 200 then
        begin
          Response := ResponseStream.DataString;
          ResponseData := GetJSON(Response);
          try
            if ResponseData is TJSONObject then
              Result := TJSONObject(ResponseData).Get('access_token', '');
          finally
            ResponseData.Free;
          end;
        end;
      except
        // Silently fail — caller should handle empty result
      end;
    finally
      ResponseStream.Free;
    end;
  finally
    Client.Free;
  end;
end;

{ TBuddyReactThread }

constructor TBuddyReactThread.Create(const AParams: TBuddyReactParams;
                                      const AAccessToken, AOrgUuid: string;
                                      ACallback: TBuddyReactCallback);
begin
  inherited Create(True);  // suspended
  FreeOnTerminate := True;
  FParams := AParams;
  FAccessToken := AAccessToken;
  FOrgUuid := AOrgUuid;
  FCallback := ACallback;
  // Copy the Recent array (dynamic arrays share references)
  SetLength(FParams.Recent, Length(AParams.Recent));
  if Length(AParams.Recent) > 0 then
    Move(AParams.Recent[0], FParams.Recent[0], Length(AParams.Recent) * SizeOf(string));
  Start;
end;

procedure TBuddyReactThread.Execute;
begin
  EnsureSSL;
  FResult := BuddyReact(FParams, FAccessToken, FOrgUuid);
  Synchronize(@DoCallback);
end;

procedure TBuddyReactThread.DoCallback;
begin
  if Assigned(FCallback) then
    FCallback(FResult);
end;

end.
