unit uOAuth;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TOAuthResult = record
    Success: Boolean;
    AccessToken: string;
    RefreshToken: string;
    ExpiresIn: Integer;
    Scopes: string;
    ErrorMsg: string;
  end;

{ Generate PKCE code_verifier (43 chars, base64url-safe) }
function GenerateCodeVerifier: string;

{ Generate code_challenge = base64url(SHA256(verifier)) }
function GenerateCodeChallenge(const AVerifier: string): string;

{ Generate random state parameter }
function GenerateState: string;

{ Build the full authorization URL }
function BuildAuthorizeURL(const ACodeChallenge, AState: string;
                           APort: Integer): string;

{ Exchange authorization code for tokens }
function ExchangeCodeForTokens(const ACode, AState, ACodeVerifier: string;
                                APort: Integer): TOAuthResult;

{ Start a localhost HTTP server, open browser, wait for callback.
  Returns the authorization code and state, or empty on timeout. }
function RunOAuthFlow(out ACode, AState: string;
                      const ACodeChallenge, AExpectedState: string;
                      APort: Integer;
                      ATimeoutSec: Integer = 120): Boolean;

implementation

uses
  {$IFDEF UNIX}BaseUnix,{$ENDIF}
  {$IFDEF WINDOWS}WinSock2,{$ENDIF}
  ssockets, sockets, fpjson, jsonparser, fphttpclient, opensslsockets,
  uCredentials, uApiClient, LCLIntf;

function DoBase64URLEncode(const AData: TBytes): string;
const
  B64Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
var
  I, Len, Pad: Integer;
  B: Cardinal;
  S: string;
begin
  Len := Length(AData);
  S := '';
  I := 0;
  while I < Len do
  begin
    B := AData[I] shl 16;
    if I + 1 < Len then B := B or (AData[I+1] shl 8);
    if I + 2 < Len then B := B or AData[I+2];

    S := S + B64Chars[((B shr 18) and $3F) + 1];
    S := S + B64Chars[((B shr 12) and $3F) + 1];
    if I + 1 < Len then
      S := S + B64Chars[((B shr 6) and $3F) + 1]
    else
      S := S + '=';
    if I + 2 < Len then
      S := S + B64Chars[(B and $3F) + 1]
    else
      S := S + '=';

    Inc(I, 3);
  end;

  // Convert to URL-safe: + -> -, / -> _, strip =
  Result := '';
  for I := 1 to Length(S) do
    case S[I] of
      '+': Result := Result + '-';
      '/': Result := Result + '_';
      '=': ; // strip
    else
      Result := Result + S[I];
    end;
end;

function RandomBytes(ACount: Integer): TBytes;
var
  I: Integer;
  {$IFDEF UNIX}
  F: File;
  {$ENDIF}
begin
  SetLength(Result, ACount);

  {$IFDEF UNIX}
  // Read from /dev/urandom
  try
    AssignFile(F, '/dev/urandom');
    Reset(F, 1);
    BlockRead(F, Result[0], ACount);
    CloseFile(F);
    Exit;
  except
  end;
  {$ENDIF}

  // Fallback: use Pascal random (less secure but functional)
  Randomize;
  for I := 0 to ACount - 1 do
    Result[I] := Random(256);
end;

function SHA256(const AInput: string): TBytes;
var
  Context: record
    State: array[0..7] of Cardinal;
    Count: Int64;
    Buffer: array[0..63] of Byte;
  end;

  procedure SHA256Init;
  begin
    Context.State[0] := $6a09e667;
    Context.State[1] := $bb67ae85;
    Context.State[2] := $3c6ef372;
    Context.State[3] := $a54ff53a;
    Context.State[4] := $510e527f;
    Context.State[5] := $9b05688c;
    Context.State[6] := $1f83d9ab;
    Context.State[7] := $5be0cd19;
    Context.Count := 0;
  end;

  function RightRotate(X: Cardinal; N: Integer): Cardinal; inline;
  begin
    Result := (X shr N) or (X shl (32 - N));
  end;

  procedure SHA256Transform(const Block: array of Byte);
  const
    K: array[0..63] of Cardinal = (
      $428a2f98, $71374491, $b5c0fbcf, $e9b5dba5, $3956c25b, $59f111f1, $923f82a4, $ab1c5ed5,
      $d807aa98, $12835b01, $243185be, $550c7dc3, $72be5d74, $80deb1fe, $9bdc06a7, $c19bf174,
      $e49b69c1, $efbe4786, $0fc19dc6, $240ca1cc, $2de92c6f, $4a7484aa, $5cb0a9dc, $76f988da,
      $983e5152, $a831c66d, $b00327c8, $bf597fc7, $c6e00bf3, $d5a79147, $06ca6351, $14292967,
      $27b70a85, $2e1b2138, $4d2c6dfc, $53380d13, $650a7354, $766a0abb, $81c2c92e, $92722c85,
      $a2bfe8a1, $a81a664b, $c24b8b70, $c76c51a3, $d192e819, $d6990624, $f40e3585, $106aa070,
      $19a4c116, $1e376c08, $2748774c, $34b0bcb5, $391c0cb3, $4ed8aa4a, $5b9cca4f, $682e6ff3,
      $748f82ee, $78a5636f, $84c87814, $8cc70208, $90befffa, $a4506ceb, $bef9a3f7, $c67178f2
    );
  var
    W: array[0..63] of Cardinal;
    A, B, C, D, E, F, G, H: Cardinal;
    S0, S1, Ch, Maj, Temp1, Temp2: Cardinal;
    I: Integer;
  begin
    for I := 0 to 15 do
      W[I] := (Cardinal(Block[I*4]) shl 24) or (Cardinal(Block[I*4+1]) shl 16) or
              (Cardinal(Block[I*4+2]) shl 8) or Cardinal(Block[I*4+3]);

    for I := 16 to 63 do
    begin
      S0 := RightRotate(W[I-15], 7) xor RightRotate(W[I-15], 18) xor (W[I-15] shr 3);
      S1 := RightRotate(W[I-2], 17) xor RightRotate(W[I-2], 19) xor (W[I-2] shr 10);
      W[I] := W[I-16] + S0 + W[I-7] + S1;
    end;

    A := Context.State[0]; B := Context.State[1];
    C := Context.State[2]; D := Context.State[3];
    E := Context.State[4]; F := Context.State[5];
    G := Context.State[6]; H := Context.State[7];

    for I := 0 to 63 do
    begin
      S1 := RightRotate(E, 6) xor RightRotate(E, 11) xor RightRotate(E, 25);
      Ch := (E and F) xor ((not E) and G);
      Temp1 := H + S1 + Ch + K[I] + W[I];
      S0 := RightRotate(A, 2) xor RightRotate(A, 13) xor RightRotate(A, 22);
      Maj := (A and B) xor (A and C) xor (B and C);
      Temp2 := S0 + Maj;

      H := G; G := F; F := E; E := D + Temp1;
      D := C; C := B; B := A; A := Temp1 + Temp2;
    end;

    Context.State[0] := Context.State[0] + A;
    Context.State[1] := Context.State[1] + B;
    Context.State[2] := Context.State[2] + C;
    Context.State[3] := Context.State[3] + D;
    Context.State[4] := Context.State[4] + E;
    Context.State[5] := Context.State[5] + F;
    Context.State[6] := Context.State[6] + G;
    Context.State[7] := Context.State[7] + H;
  end;

  procedure SHA256Update(const Data: string);
  var
    I, Idx, Remaining: Integer;
  begin
    Idx := Context.Count mod 64;
    for I := 1 to Length(Data) do
    begin
      Context.Buffer[Idx] := Ord(Data[I]);
      Inc(Idx);
      Inc(Context.Count);
      if Idx = 64 then
      begin
        SHA256Transform(Context.Buffer);
        Idx := 0;
      end;
    end;
  end;

  function SHA256Final: TBytes;
  var
    Idx: Integer;
    BitLen: Int64;
    I: Integer;
  begin
    SetLength(Result, 32);
    Idx := Context.Count mod 64;
    Context.Buffer[Idx] := $80;
    Inc(Idx);

    if Idx > 56 then
    begin
      while Idx < 64 do begin Context.Buffer[Idx] := 0; Inc(Idx); end;
      SHA256Transform(Context.Buffer);
      Idx := 0;
    end;

    while Idx < 56 do begin Context.Buffer[Idx] := 0; Inc(Idx); end;

    BitLen := Context.Count * 8;
    for I := 7 downto 0 do
    begin
      Context.Buffer[56 + (7 - I)] := (BitLen shr (I * 8)) and $FF;
    end;
    SHA256Transform(Context.Buffer);

    for I := 0 to 7 do
    begin
      Result[I*4]     := (Context.State[I] shr 24) and $FF;
      Result[I*4 + 1] := (Context.State[I] shr 16) and $FF;
      Result[I*4 + 2] := (Context.State[I] shr 8) and $FF;
      Result[I*4 + 3] := Context.State[I] and $FF;
    end;
  end;

begin
  SHA256Init;
  SHA256Update(AInput);
  Result := SHA256Final;
end;

function GenerateCodeVerifier: string;
begin
  Result := DoBase64URLEncode(RandomBytes(32));
end;

function GenerateCodeChallenge(const AVerifier: string): string;
begin
  Result := DoBase64URLEncode(SHA256(AVerifier));
end;

function GenerateState: string;
begin
  Result := DoBase64URLEncode(RandomBytes(32));
end;

function BuildAuthorizeURL(const ACodeChallenge, AState: string;
                           APort: Integer): string;
begin
  Result := AUTHORIZE_URL +
    '?code=true' +
    '&client_id=' + OAUTH_CLIENT_ID +
    '&response_type=code' +
    '&redirect_uri=http%3A%2F%2Flocalhost%3A' + IntToStr(APort) + '%2Fcallback' +
    '&scope=' + StringReplace(DEFAULT_SCOPES, ' ', '%20', [rfReplaceAll]) +
    '&code_challenge=' + ACodeChallenge +
    '&code_challenge_method=S256' +
    '&state=' + AState;
end;

function ExchangeCodeForTokens(const ACode, AState, ACodeVerifier: string;
                                APort: Integer): TOAuthResult;
var
  Client: TFPHTTPClient;
  Payload, Response: string;
  ResponseStream: TStringStream;
  Obj, RespObj: TJSONObject;
  RespData: TJSONData;
begin
  Result.Success := False;

  Obj := TJSONObject.Create;
  try
    Obj.Add('grant_type', 'authorization_code');
    Obj.Add('code', ACode);
    Obj.Add('redirect_uri', 'http://localhost:' + IntToStr(APort) + '/callback');
    Obj.Add('client_id', OAUTH_CLIENT_ID);
    Obj.Add('code_verifier', ACodeVerifier);
    Obj.Add('state', AState);
    Payload := Obj.AsJSON;
  finally
    Obj.Free;
  end;

  EnsureSSL;

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
          RespData := GetJSON(Response);
          try
            if RespData is TJSONObject then
            begin
              RespObj := TJSONObject(RespData);
              Result.AccessToken := RespObj.Get('access_token', '');
              Result.RefreshToken := RespObj.Get('refresh_token', '');
              Result.ExpiresIn := RespObj.Get('expires_in', 0);
              Result.Scopes := RespObj.Get('scope', DEFAULT_SCOPES);
              Result.Success := Result.AccessToken <> '';
            end;
          finally
            RespData.Free;
          end;
        end
        else
          Result.ErrorMsg := Format('Token exchange failed: HTTP %d',
            [Client.ResponseStatusCode]);
      except
        on E: Exception do
          Result.ErrorMsg := 'Token exchange error: ' + E.Message;
      end;
    finally
      ResponseStream.Free;
    end;
  finally
    Client.Free;
  end;
end;

{ Simple single-shot HTTP server using raw sockets }
function RunOAuthFlow(out ACode, AState: string;
                      const ACodeChallenge, AExpectedState: string;
                      APort: Integer;
                      ATimeoutSec: Integer): Boolean;
var
  ServerSock, ClientSock: {$IFDEF WINDOWS}TSocket{$ELSE}LongInt{$ENDIF};
  {$IFDEF WINDOWS}
  Addr: TSockAddrIn;
  AddrLen: Integer;
  WSAData: TWSAData;
  FDS: TFDSet;
  TimeVal: WinSock2.TTimeVal;
  {$ELSE}
  Addr: TInetSockAddr;
  AddrLen: TSockLen;
  FDS: TFDSet;
  TimeVal: BaseUnix.TTimeVal;
  {$ENDIF}
  RequestBuf: array[0..4095] of Char;
  BytesRead: {$IFDEF WINDOWS}Integer{$ELSE}SizeInt{$ENDIF};
  RequestStr, QueryStr, ResponseHTML: string;
  Params: TStringList;
  StartTime: TDateTime;
  SelectRes: LongInt;
begin
  Result := False;
  ACode := '';
  AState := '';

  {$IFDEF WINDOWS}
  WSAStartup($0202, WSAData);
  {$ENDIF}

  ServerSock := {$IFDEF WINDOWS}WinSock2.socket{$ELSE}fpSocket{$ENDIF}(AF_INET, SOCK_STREAM, 0);
  if ServerSock {$IFDEF WINDOWS}= INVALID_SOCKET{$ELSE}< 0{$ENDIF} then Exit;

  try
    FillChar(Addr, SizeOf(Addr), 0);
    Addr.sin_family := AF_INET;
    Addr.sin_port := htons(APort);
    Addr.sin_addr.S_addr := htonl($7F000001);

    if {$IFDEF WINDOWS}WinSock2.bind(ServerSock, @Addr, SizeOf(Addr)){$ELSE}fpBind(ServerSock, @Addr, SizeOf(Addr)){$ENDIF} <> 0 then Exit;
    if {$IFDEF WINDOWS}WinSock2.listen(ServerSock, 1){$ELSE}fpListen(ServerSock, 1){$ENDIF} <> 0 then Exit;

    OpenURL(BuildAuthorizeURL(ACodeChallenge, AExpectedState, APort));

    StartTime := Now;

    while (Now - StartTime) * 86400 < ATimeoutSec do
    begin
      {$IFDEF WINDOWS}
      FD_ZERO(FDS);
      FD_SET(ServerSock, FDS);
      TimeVal.tv_sec := 1;
      TimeVal.tv_usec := 0;
      SelectRes := WinSock2.select(0, @FDS, nil, nil, @TimeVal);
      {$ELSE}
      fpFD_ZERO(FDS);
      fpFD_SET(ServerSock, FDS);
      TimeVal.tv_sec := 1;
      TimeVal.tv_usec := 0;
      SelectRes := fpSelect(ServerSock + 1, @FDS, nil, nil, @TimeVal);
      {$ENDIF}

      if SelectRes <= 0 then Continue;

      AddrLen := SizeOf(Addr);
      ClientSock := {$IFDEF WINDOWS}WinSock2.accept(ServerSock, @Addr, @AddrLen){$ELSE}fpAccept(ServerSock, @Addr, @AddrLen){$ENDIF};
      if ClientSock {$IFDEF WINDOWS}= INVALID_SOCKET{$ELSE}< 0{$ENDIF} then Continue;

      try
        BytesRead := {$IFDEF WINDOWS}WinSock2.recv(ClientSock, RequestBuf, SizeOf(RequestBuf) - 1, 0){$ELSE}fpRead(ClientSock, @RequestBuf[0], SizeOf(RequestBuf) - 1){$ENDIF};
        if BytesRead <= 0 then Continue;
        RequestBuf[BytesRead] := #0;
        RequestStr := StrPas(@RequestBuf[0]);

        if Pos('/callback?', RequestStr) > 0 then
        begin
          QueryStr := Copy(RequestStr,
            Pos('?', RequestStr) + 1,
            Pos(' HTTP', RequestStr) - Pos('?', RequestStr) - 1);

          Params := TStringList.Create;
          try
            Params.Delimiter := '&';
            Params.StrictDelimiter := True;
            Params.DelimitedText := QueryStr;
            ACode := Params.Values['code'];
            AState := Params.Values['state'];
          finally
            Params.Free;
          end;

          ResponseHTML :=
            'HTTP/1.1 200 OK'#13#10 +
            'Content-Type: text/html'#13#10 +
            'Connection: close'#13#10#13#10 +
            '<html><body><h2>BonziClaude authorized!</h2>' +
            '<p>You can close this tab.</p></body></html>';
          {$IFDEF WINDOWS}
          WinSock2.send(ClientSock, ResponseHTML[1], Length(ResponseHTML), 0);
          {$ELSE}
          fpWrite(ClientSock, @ResponseHTML[1], Length(ResponseHTML));
          {$ENDIF}

          Result := (ACode <> '') and (AState = AExpectedState);
        end;
      finally
        CloseSocket(ClientSock);
      end;

      if Result then Break;
    end;
  finally
    CloseSocket(ServerSock);
    {$IFDEF WINDOWS}
    WSACleanup;
    {$ENDIF}
  end;
end;

end.
