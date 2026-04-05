unit uCredentials;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TCredentials = record
    AccessToken: string;
    RefreshToken: string;
    ExpiresAt: Int64;     // Unix milliseconds
    Scopes: string;       // space-separated
    SubscriptionType: string;
    RateLimitTier: string;
  end;

const
  OAUTH_CLIENT_ID   = '9d1c250a-e61b-44d9-88ed-5944d1962f5e';
  // Claude AI authorize URL — for consumer users (claude.ai subscribers)
  // platform.claude.com/oauth/authorize is for platform/console users only
  AUTHORIZE_URL     = 'https://claude.com/cai/oauth/authorize';
  TOKEN_URL         = 'https://platform.claude.com/v1/oauth/token';
  PROFILE_URL       = 'https://api.anthropic.com/api/oauth/profile';
  API_BASE_URL      = 'https://api.anthropic.com';
  BETA_HEADER       = 'ccr-byoc-2025-07-29';
  DEFAULT_SCOPES    = 'user:profile user:inference user:sessions:claude_code user:mcp_servers user:file_upload';

  EXPIRY_BUFFER_MS  = 300000;  // 5-minute buffer before expiry

function LoadCredentials(const APath: string): TCredentials;
procedure SaveCredentials(const APath: string; const ACreds: TCredentials);
function GetCredentialsPath: string;
function GetClaudeCodeCredentialsPath: string;

{ Import credentials from Claude Code's ~/.claude/.credentials.json }
function ImportClaudeCodeCredentials(out ACreds: TCredentials): Boolean;

function IsTokenExpired(const ACreds: TCredentials): Boolean;
function CurrentTimeMillis: Int64;
function FetchOrgUuid(const AAccessToken: string): string;

implementation

uses
  fpjson, jsonparser, fphttpclient, opensslsockets;

function CurrentTimeMillis: Int64;
begin
  Result := Round((Now - EncodeDate(1970, 1, 1)) * 86400000);
end;

function IsTokenExpired(const ACreds: TCredentials): Boolean;
begin
  if ACreds.ExpiresAt = 0 then
    Result := False  // no expiry set, assume valid
  else
    Result := CurrentTimeMillis + EXPIRY_BUFFER_MS >= ACreds.ExpiresAt;
end;

function GetCredentialsPath: string;
begin
  // BonziClaude's own credential store — separate from Claude Code's
  // to avoid overwriting Claude Code's tokens with wrong scopes.
  {$IFDEF WINDOWS}
  Result := GetEnvironmentVariable('USERPROFILE') + DirectorySeparator + '.bonziclaude' + DirectorySeparator + 'credentials.json';
  {$ELSE}
  Result := GetEnvironmentVariable('HOME') + DirectorySeparator + '.bonziclaude' + DirectorySeparator + 'credentials.json';
  {$ENDIF}
end;

function GetClaudeCodeCredentialsPath: string;
begin
  // Claude Code's credentials — read-only for us
  {$IFDEF WINDOWS}
  Result := GetEnvironmentVariable('USERPROFILE') + DirectorySeparator + '.claude' + DirectorySeparator + '.credentials.json';
  {$ELSE}
  Result := GetEnvironmentVariable('HOME') + DirectorySeparator + '.claude' + DirectorySeparator + '.credentials.json';
  {$ENDIF}
end;

function LoadCredentials(const APath: string): TCredentials;
var
  FS: TFileStream;
  Parser: TJSONParser;
  Data: TJSONData;
  Obj, OAuth: TJSONObject;
  ScopesArr: TJSONArray;
  ScopeStr: string;
  I: Integer;
begin
  Result := Default(TCredentials);
  if not FileExists(APath) then
    Exit;

  FS := TFileStream.Create(APath, fmOpenRead or fmShareDenyNone);
  try
    Parser := TJSONParser.Create(FS);
    try
      Data := Parser.Parse;
      try
        if Data is TJSONObject then
        begin
          Obj := TJSONObject(Data);

          // Detect format: Claude Code wraps in "claudeAiOauth", ours is flat
          if Obj.Find('claudeAiOauth') is TJSONObject then
            OAuth := TJSONObject(Obj.Find('claudeAiOauth'))
          else
            OAuth := Obj;

          Result.AccessToken := OAuth.Get('accessToken', '');
          Result.RefreshToken := OAuth.Get('refreshToken', '');
          Result.ExpiresAt := OAuth.Get('expiresAt', Int64(0));
          Result.SubscriptionType := OAuth.Get('subscriptionType', '');
          Result.RateLimitTier := OAuth.Get('rateLimitTier', '');

          if OAuth.Find('scopes') is TJSONArray then
          begin
            ScopesArr := TJSONArray(OAuth.Find('scopes'));
            ScopeStr := '';
            for I := 0 to ScopesArr.Count - 1 do
            begin
              if ScopeStr <> '' then ScopeStr := ScopeStr + ' ';
              ScopeStr := ScopeStr + ScopesArr.Strings[I];
            end;
            Result.Scopes := ScopeStr;
          end
          else
            Result.Scopes := OAuth.Get('scopes', DEFAULT_SCOPES);
        end;
      finally
        Data.Free;
      end;
    finally
      Parser.Free;
    end;
  finally
    FS.Free;
  end;
end;

procedure SaveCredentials(const APath: string; const ACreds: TCredentials);
var
  Obj: TJSONObject;
  Dir, S: string;
  FS: TFileStream;
begin
  Dir := ExtractFilePath(APath);
  if not DirectoryExists(Dir) then
    ForceDirectories(Dir);

  Obj := TJSONObject.Create;
  try
    Obj.Add('accessToken', ACreds.AccessToken);
    Obj.Add('refreshToken', ACreds.RefreshToken);
    Obj.Add('expiresAt', ACreds.ExpiresAt);
    Obj.Add('scopes', ACreds.Scopes);
    Obj.Add('subscriptionType', ACreds.SubscriptionType);
    Obj.Add('rateLimitTier', ACreds.RateLimitTier);
    S := Obj.FormatJSON;

    FS := TFileStream.Create(APath, fmCreate);
    try
      if Length(S) > 0 then
        FS.Write(S[1], Length(S));
    finally
      FS.Free;
    end;
  finally
    Obj.Free;
  end;
end;

function FetchOrgUuid(const AAccessToken: string): string;
var
  Client: TFPHTTPClient;
  ResponseStream: TStringStream;
  Data: TJSONData;
  Obj, OrgObj: TJSONObject;
begin
  Result := '';
  if AAccessToken = '' then Exit;

  Client := TFPHTTPClient.Create(nil);
  try
    Client.AddHeader('Authorization', 'Bearer ' + AAccessToken);
    Client.IOTimeout := 10000;

    ResponseStream := TStringStream.Create('');
    try
      try
        Client.Get(PROFILE_URL, ResponseStream);
        if Client.ResponseStatusCode = 200 then
        begin
          Data := GetJSON(ResponseStream.DataString);
          try
            if Data is TJSONObject then
            begin
              Obj := TJSONObject(Data);
              if Obj.Find('organization') is TJSONObject then
              begin
                OrgObj := TJSONObject(Obj.Find('organization'));
                Result := OrgObj.Get('uuid', '');
              end;
            end;
          finally
            Data.Free;
          end;
        end;
      except
      end;
    finally
      ResponseStream.Free;
    end;
  finally
    Client.Free;
  end;
end;

function ImportClaudeCodeCredentials(out ACreds: TCredentials): Boolean;
begin
  // Read from Claude Code's credentials (read-only — never write to it)
  ACreds := LoadCredentials(GetClaudeCodeCredentialsPath);
  Result := ACreds.AccessToken <> '';
end;

// Keep the old implementation commented out for reference
{
function ImportClaudeCodeCredentials_Old(out ACreds: TCredentials): Boolean;
var
  ClaudeCreds: string;
  FS: TFileStream;
  Parser: TJSONParser;
  Data: TJSONData;
  Root, OAuth: TJSONObject;
  ScopesArr: TJSONArray;
  I: Integer;
  ScopeStr: string;
begin
  Result := False;
  ACreds := Default(TCredentials);

  ClaudeCreds := GetEnvironmentVariable('HOME') + DirectorySeparator +
                 '.claude' + DirectorySeparator + '.credentials.json';

  {$IFDEF WINDOWS}
  ClaudeCreds := GetEnvironmentVariable('USERPROFILE') + DirectorySeparator +
                 '.claude' + DirectorySeparator + '.credentials.json';
  {$ENDIF}

  if not FileExists(ClaudeCreds) then
    Exit;

  FS := TFileStream.Create(ClaudeCreds, fmOpenRead or fmShareDenyNone);
  try
    Parser := TJSONParser.Create(FS);
    try
      Data := Parser.Parse;
      try
        if not (Data is TJSONObject) then
          Exit;
        Root := TJSONObject(Data);

        if not (Root.Find('claudeAiOauth') is TJSONObject) then
          Exit;
        OAuth := TJSONObject(Root.Find('claudeAiOauth'));

        ACreds.AccessToken := OAuth.Get('accessToken', '');
        ACreds.RefreshToken := OAuth.Get('refreshToken', '');
        ACreds.ExpiresAt := OAuth.Get('expiresAt', Int64(0));
        ACreds.SubscriptionType := OAuth.Get('subscriptionType', '');
        ACreds.RateLimitTier := OAuth.Get('rateLimitTier', '');

        // Scopes can be array or string
        if OAuth.Find('scopes') is TJSONArray then
        begin
          ScopesArr := TJSONArray(OAuth.Find('scopes'));
          ScopeStr := '';
          for I := 0 to ScopesArr.Count - 1 do
          begin
            if ScopeStr <> '' then
              ScopeStr := ScopeStr + ' ';
            ScopeStr := ScopeStr + ScopesArr.Strings[I];
          end;
          ACreds.Scopes := ScopeStr;
        end
        else
          ACreds.Scopes := OAuth.Get('scopes', DEFAULT_SCOPES);

        Result := ACreds.AccessToken <> '';
      finally
        Data.Free;
      end;
    finally
      Parser.Free;
    end;
  finally
    FS.Free;
  end;
end;
}

end.
