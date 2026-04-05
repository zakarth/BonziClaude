unit uConfig;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser;

type
  TBuddyConfig = record
    // Companion identity
    Name: string;
    Personality: string;
    Species: string;
    Eye: string;
    Hat: string;
    Rarity: string;
    Shiny: Boolean;

    // Stats
    Debugging: Integer;
    Patience: Integer;
    Chaos: Integer;
    Wisdom: Integer;
    Snark: Integer;

    // OAuth / API
    OrgUuid: string;

    // Window state
    WindowX: Integer;
    WindowY: Integer;

    // Behavior
    ClipboardWatch: Boolean;
    IdleReactMinutes: Integer;
    PrivacyMode: Integer;  // 0=chat only, 1=standard (time/day), 2=personalized (system info)
    PersonalizedMode: Boolean;  // derived: PrivacyMode = 2
  end;

function DefaultConfig: TBuddyConfig;
function LoadConfig(const APath: string): TBuddyConfig;
procedure SaveConfig(const APath: string; const AConfig: TBuddyConfig);
function GetConfigDir: string;
function GetConfigPath: string;

{ Import companion from Claude Code's .claude.json or latest backup }
function ImportFromClaudeCode(out AConfig: TBuddyConfig): Boolean;
function FindClaudeConfigFile: string;

implementation

uses
  uValidation;

function DefaultConfig: TBuddyConfig;
begin
  Result.Name := 'Buddy';
  Result.Personality := 'A small creature of few words who watches you code.';
  Result.Species := 'rabbit';
  Result.Eye := #$C2#$B7;  // ·
  Result.Hat := 'none';
  Result.Rarity := 'common';
  Result.Shiny := False;
  Result.Debugging := 50;
  Result.Patience := 50;
  Result.Chaos := 50;
  Result.Wisdom := 50;
  Result.Snark := 50;
  Result.OrgUuid := '';
  Result.WindowX := -1;
  Result.WindowY := -1;
  Result.ClipboardWatch := True;
  Result.IdleReactMinutes := 5;
  Result.PrivacyMode := 1;  // standard by default
  Result.PersonalizedMode := False;
end;

function GetConfigDir: string;
begin
  {$IFDEF WINDOWS}
  Result := GetEnvironmentVariable('APPDATA') + DirectorySeparator + 'BonziClaude' + DirectorySeparator;
  {$ELSE}
  Result := GetEnvironmentVariable('HOME') + DirectorySeparator + '.config' + DirectorySeparator + 'BonziClaude' + DirectorySeparator;
  {$ENDIF}
end;

function GetConfigPath: string;
begin
  Result := GetConfigDir + 'buddy_config.json';
end;

function LoadConfig(const APath: string): TBuddyConfig;
var
  FS: TFileStream;
  Parser: TJSONParser;
  Data: TJSONData;
  Obj: TJSONObject;
  Stats: TJSONObject;
begin
  Result := DefaultConfig;
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
          Result.Name := Obj.Get('name', Result.Name);
          Result.Personality := Obj.Get('personality', Result.Personality);
          Result.Species := Obj.Get('species', Result.Species);
          Result.Eye := Obj.Get('eye', Result.Eye);
          Result.Hat := Obj.Get('hat', Result.Hat);
          Result.Rarity := Obj.Get('rarity', Result.Rarity);
          Result.Shiny := Obj.Get('shiny', Result.Shiny);
          Result.OrgUuid := Obj.Get('orgUuid', Result.OrgUuid);
          Result.WindowX := Obj.Get('windowX', Result.WindowX);
          Result.WindowY := Obj.Get('windowY', Result.WindowY);
          Result.ClipboardWatch := Obj.Get('clipboardWatch', Result.ClipboardWatch);
          Result.IdleReactMinutes := Obj.Get('idleReactMinutes', Result.IdleReactMinutes);
          Result.PrivacyMode := Obj.Get('privacyMode', Result.PrivacyMode);
          Result.PersonalizedMode := Result.PrivacyMode = 2;

          if Obj.Find('stats') is TJSONObject then
          begin
            Stats := TJSONObject(Obj.Find('stats'));
            Result.Debugging := Stats.Get('DEBUGGING', Result.Debugging);
            Result.Patience := Stats.Get('PATIENCE', Result.Patience);
            Result.Chaos := Stats.Get('CHAOS', Result.Chaos);
            Result.Wisdom := Stats.Get('WISDOM', Result.Wisdom);
            Result.Snark := Stats.Get('SNARK', Result.Snark);
          end;
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

procedure SaveConfig(const APath: string; const AConfig: TBuddyConfig);
var
  Obj, Stats: TJSONObject;
  Dir: string;
  S: string;
  FS: TFileStream;
begin
  Dir := ExtractFilePath(APath);
  if not DirectoryExists(Dir) then
    ForceDirectories(Dir);

  Obj := TJSONObject.Create;
  try
    Obj.Add('name', ValidateName(AConfig.Name));
    Obj.Add('personality', ValidatePersonality(AConfig.Personality));
    Obj.Add('species', AConfig.Species);
    Obj.Add('eye', AConfig.Eye);
    Obj.Add('hat', AConfig.Hat);
    Obj.Add('rarity', AConfig.Rarity);
    Obj.Add('shiny', AConfig.Shiny);
    Obj.Add('orgUuid', AConfig.OrgUuid);
    Obj.Add('windowX', AConfig.WindowX);
    Obj.Add('windowY', AConfig.WindowY);
    Obj.Add('clipboardWatch', AConfig.ClipboardWatch);
    Obj.Add('idleReactMinutes', AConfig.IdleReactMinutes);
    Obj.Add('privacyMode', AConfig.PrivacyMode);

    Stats := TJSONObject.Create;
    Stats.Add('DEBUGGING', AConfig.Debugging);
    Stats.Add('PATIENCE', AConfig.Patience);
    Stats.Add('CHAOS', AConfig.Chaos);
    Stats.Add('WISDOM', AConfig.Wisdom);
    Stats.Add('SNARK', AConfig.Snark);
    Obj.Add('stats', Stats);

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

function FindClaudeConfigFile: string;
var
  ClaudeDir, LivePath, BackupDir: string;
  SR: TSearchRec;
  Latest: string;
  LatestTime: TDateTime;
begin
  Result := '';
  {$IFDEF WINDOWS}
  ClaudeDir := GetEnvironmentVariable('USERPROFILE') + DirectorySeparator + '.claude';
  {$ELSE}
  ClaudeDir := GetEnvironmentVariable('HOME') + DirectorySeparator + '.claude';
  {$ENDIF}
  LivePath := ClaudeDir + DirectorySeparator + '.claude.json';

  if FileExists(LivePath) then
    Exit(LivePath);

  // Fall back to latest backup
  BackupDir := ClaudeDir + DirectorySeparator + 'backups';
  if not DirectoryExists(BackupDir) then
    Exit;

  Latest := '';
  LatestTime := 0;
  if FindFirst(BackupDir + DirectorySeparator + '.claude.json.backup.*', faAnyFile, SR) = 0 then
  begin
    repeat
      if SR.TimeStamp > LatestTime then
      begin
        LatestTime := SR.TimeStamp;
        Latest := BackupDir + DirectorySeparator + SR.Name;
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
  Result := Latest;
end;

function ImportFromClaudeCode(out AConfig: TBuddyConfig): Boolean;
var
  ConfigPath: string;
  FS: TFileStream;
  Parser: TJSONParser;
  Data: TJSONData;
  Root, Companion, OAuth, Stats: TJSONObject;
begin
  Result := False;
  AConfig := DefaultConfig;

  ConfigPath := FindClaudeConfigFile;
  if ConfigPath = '' then
    Exit;

  FS := TFileStream.Create(ConfigPath, fmOpenRead or fmShareDenyNone);
  try
    Parser := TJSONParser.Create(FS);
    try
      Data := Parser.Parse;
      try
        if not (Data is TJSONObject) then
          Exit;

        Root := TJSONObject(Data);

        // Import companion (if it exists — may not be hatched yet)
        if Root.Find('companion') is TJSONObject then
        begin
          Companion := TJSONObject(Root.Find('companion'));
          AConfig.Name := Companion.Get('name', AConfig.Name);
          AConfig.Personality := Companion.Get('personality', AConfig.Personality);
          AConfig.Species := Companion.Get('species', AConfig.Species);
          AConfig.Eye := Companion.Get('eye', AConfig.Eye);
          AConfig.Hat := Companion.Get('hat', AConfig.Hat);
          AConfig.Rarity := Companion.Get('rarity', AConfig.Rarity);
          AConfig.Shiny := Companion.Get('shiny', AConfig.Shiny);

          if Companion.Find('stats') is TJSONObject then
          begin
            Stats := TJSONObject(Companion.Find('stats'));
            AConfig.Debugging := Stats.Get('DEBUGGING', AConfig.Debugging);
            AConfig.Patience := Stats.Get('PATIENCE', AConfig.Patience);
            AConfig.Chaos := Stats.Get('CHAOS', AConfig.Chaos);
            AConfig.Wisdom := Stats.Get('WISDOM', AConfig.Wisdom);
            AConfig.Snark := Stats.Get('SNARK', AConfig.Snark);
          end;
        end;

        // Import org UUID for API calls
        if Root.Find('oauthAccount') is TJSONObject then
        begin
          OAuth := TJSONObject(Root.Find('oauthAccount'));
          AConfig.OrgUuid := OAuth.Get('organizationUuid', '');
        end;

        // Success if we got at least an orgUuid
        Result := AConfig.OrgUuid <> '';

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

end.
