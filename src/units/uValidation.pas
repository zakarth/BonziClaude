unit uValidation;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

const
  MAX_NAME_LEN        = 32;
  MAX_PERSONALITY_LEN  = 200;
  MAX_TRANSCRIPT_LEN   = 5000;
  MAX_RECENT_ENTRY_LEN = 200;
  MAX_RECENT_COUNT     = 3;
  MAX_OUTPUT_LEN       = 350;  // approximate server-side output cap

function TruncateStr(const S: string; MaxLen: Integer): string;
function ValidateName(const S: string): string;
function ValidatePersonality(const S: string): string;
function ValidateTranscript(const S: string): string;
function ValidateRecentEntry(const S: string): string;

implementation

function TruncateStr(const S: string; MaxLen: Integer): string;
begin
  if Length(S) <= MaxLen then
    Result := S
  else
    Result := Copy(S, 1, MaxLen);
end;

function ValidateName(const S: string): string;
begin
  Result := TruncateStr(Trim(S), MAX_NAME_LEN);
end;

function ValidatePersonality(const S: string): string;
begin
  Result := TruncateStr(Trim(S), MAX_PERSONALITY_LEN);
end;

function ValidateTranscript(const S: string): string;
begin
  Result := TruncateStr(S, MAX_TRANSCRIPT_LEN);
end;

function ValidateRecentEntry(const S: string): string;
begin
  Result := TruncateStr(S, MAX_RECENT_ENTRY_LEN);
end;

end.
