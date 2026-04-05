unit uFormHatch;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, StrUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  uCompanionData, uConfig, uCredentials, uApiClient, uValidation;

type
  THatchResult = record
    Success: Boolean;
    // Full bones — everything rolled fresh
    Name: string;
    Personality: string;
    Species: string;
    Eye: string;
    Hat: string;
    Rarity: string;
    Shiny: Boolean;
    Debugging: Integer;
    Patience: Integer;
    Chaos: Integer;
    Wisdom: Integer;
    Snark: Integer;
  end;

  TFormHatch = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormPaint(Sender: TObject);
  private
    FMonoFont: TFont;
    FAnimTimer: TTimer;
    FAnimFrame: Integer;
    FLoadingIdx: Integer;
    FHatchDone: Boolean;
    FResult: THatchResult;
    FConfig: TBuddyConfig;
    FCreds: TCredentials;
    FStatusLabel: TLabel;
    FLoadingLabel: TLabel;

    procedure OnAnimTimer(Sender: TObject);
    procedure DoHatch;
  public
    property HatchResult: THatchResult read FResult;
    procedure StartHatch(const AConfig: TBuddyConfig; const ACreds: TCredentials);
  end;

const
  EGG_FRAME_COUNT = 11;
  EggFrames: array[0..EGG_FRAME_COUNT-1] of array[0..5] of string = (
    ('    _____   ', '   /     \  ', '  /       \ ', ' |         |', '  \       / ', '   \_____/  '),
    ('    _____   ', '   /     \  ', '  /       \ ', ' |         |', '  \       / ', '   \_____/  '),
    ('   _____    ', '  /     \   ', ' /       \  ', '|         | ', ' \       /  ', '  \_____/   '),
    ('    _____   ', '   /     \  ', '  /       \ ', ' |         |', '  \       / ', '   \_____/  '),
    ('    _____   ', '   /     \  ', '  /       \ ', ' |    .    |', '  \       / ', '   \_____/  '),
    ('    _____   ', '   /     \  ', '  /       \ ', ' |    /    |', '  \       / ', '   \_____/  '),
    ('    _____   ', '   /     \  ', '  /   .   \ ', ' |   / \   |', '  \       / ', '   \_____/  '),
    ('    _____   ', '   /  .  \  ', '  /  / \  \ ', ' |  /   \  |', '  \   .   / ', '   \_____/  '),
    ('    _____   ', '   / / \ \  ', '  / /   \ \ ', ' | /     \ |', '  \   V   / ', '   \__V__/  '),
    ('    __ __   ', '   / V V \  ', '  / /   \ \ ', ' | /     \ |', '  \   V   / ', '   \__V__/  '),
    ('   .  *  .  ', '  .       . ', ' .    *    .', '  *       * ', ' .    .    .', '   .  *  .  ')
  );

  LOADING_WORD_COUNT = 20;
  LoadingWords: array[0..LOADING_WORD_COUNT-1] of string = (
    'baking', 'beaming', 'booping', 'brewing', 'bubbling',
    'crafting', 'dreaming', 'fluffing', 'growing', 'hatching',
    'knitting', 'mixing', 'nesting', 'polishing', 'simmering',
    'sparkling', 'sprouting', 'stirring', 'weaving', 'wishing'
  );

implementation

{$R *.lfm}

procedure TFormHatch.FormCreate(Sender: TObject);
begin
  Caption := 'Hatching...';
  Width := 320;
  Height := 280;
  Position := poScreenCenter;
  BorderStyle := bsSingle;
  BorderIcons := [];
  Color := $00000000;

  FMonoFont := TFont.Create;
  {$IFDEF WINDOWS}
  FMonoFont.Name := 'Consolas';
  {$ELSE}
  FMonoFont.Name := 'DejaVu Sans Mono';
  {$ENDIF}
  FMonoFont.Size := 14;

  FAnimFrame := 0;
  FLoadingIdx := 0;
  FHatchDone := False;

  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Parent := Self;
  FStatusLabel.Align := alBottom;
  FStatusLabel.Height := 30;
  FStatusLabel.Alignment := taCenter;
  FStatusLabel.Font.Color := $00808080;
  FStatusLabel.Font.Size := 10;
  FStatusLabel.Caption := '';

  FLoadingLabel := TLabel.Create(Self);
  FLoadingLabel.Parent := Self;
  FLoadingLabel.Left := 0;
  FLoadingLabel.Top := Height - 60;
  FLoadingLabel.Width := Width;
  FLoadingLabel.Alignment := taCenter;
  FLoadingLabel.Font.Color := $004AA316;
  FLoadingLabel.Font.Size := 11;
  FLoadingLabel.Caption := '';

  FAnimTimer := TTimer.Create(Self);
  FAnimTimer.Interval := 160;
  FAnimTimer.OnTimer := @OnAnimTimer;
  FAnimTimer.Enabled := False;
end;

procedure TFormHatch.FormPaint(Sender: TObject);
var
  Frame: Integer;
  I, Y, CX: Integer;
  Lines: array[0..5] of string;
begin
  Canvas.Brush.Color := $00000000;
  Canvas.FillRect(ClientRect);

  Canvas.Font.Assign(FMonoFont);
  Canvas.Font.Color := $004AA316;  // green
  Canvas.Brush.Style := bsClear;

  // Determine which egg frame to show
  if FAnimFrame < 12 then
    Frame := FAnimFrame mod 4  // wobble cycle
  else if FAnimFrame < 12 + 7 then
    Frame := 4 + (FAnimFrame - 12)  // crack sequence (frames 4-10)
  else
    Frame := 10;  // sparkle (hold)

  if Frame >= EGG_FRAME_COUNT then Frame := EGG_FRAME_COUNT - 1;

  // Center the egg
  CX := (ClientWidth - Canvas.TextWidth('M') * 12) div 2;
  Y := 30;

  for I := 0 to 5 do
  begin
    Canvas.TextOut(CX, Y, EggFrames[Frame][I]);
    Inc(Y, Canvas.TextHeight('M'));
  end;

  Canvas.Brush.Style := bsSolid;
end;

procedure TFormHatch.OnAnimTimer(Sender: TObject);
begin
  Inc(FAnimFrame);

  // Update loading word every few frames
  if (FAnimFrame mod 3) = 0 then
  begin
    FLoadingIdx := (FLoadingIdx + 1) mod LOADING_WORD_COUNT;
    FLoadingLabel.Caption := LoadingWords[FLoadingIdx] + '...';
  end;

  // If hatching is done and we've played through the crack animation
  if FHatchDone and (FAnimFrame >= 19) then
  begin
    FAnimTimer.Enabled := False;
    FStatusLabel.Caption := FResult.Name + ' has hatched!';
    FLoadingLabel.Caption := '';

    // Brief pause then close
    Sleep(1500);
    ModalResult := mrOK;
  end;

  // If we've wobbled enough but hatching isn't done, keep wobbling
  if (not FHatchDone) and (FAnimFrame >= 12) then
    FAnimFrame := 8;  // loop the late wobble

  Invalidate;
end;

procedure TFormHatch.DoHatch;
const
  RarityBase: array[0..RARITY_COUNT-1] of Integer = (5, 15, 25, 35, 50);
var
  Params: TBuddyReactParams;
  ApiResult: TBuddyReactResult;
  Token: string;
  InspirationIdxs: array[0..3] of Integer;
  I, J, RarIdx, Base, Primary, Secondary: Integer;
  R: Double;
  UserMsg, S: string;
  StatStr: string;
  StatVals: array[0..STAT_COUNT-1] of Integer;
  SeedStr: string;
  Hash: LongWord;
  RngState: LongWord;

  function FNV1a(const S: string): LongWord;
  var
    J: Integer;
    H: LongWord;
  begin
    H := 2166136261;
    for J := 1 to Length(S) do
    begin
      H := H xor Ord(S[J]);
      H := LongWord(Int64(H) * 16777619);
    end;
    Result := H;
  end;

  function NextRng: Double;
  var
    T: LongInt;
  begin
    RngState := LongWord(LongInt(RngState) + 1831565813);
    T := LongInt(RngState);
    T := LongInt(LongWord((T xor (LongWord(T) shr 15))) * LongWord(1 or T));
    T := T + LongInt(LongWord((T xor (LongWord(T) shr 7))) * LongWord(61 or T)) xor T;
    Result := (LongWord(T xor (LongWord(T) shr 14))) / 4294967296.0;
  end;

begin
  Randomize;

  // Generate FULL bones — same algorithm as Claude Code's Mb4(rng):
  // Seed from current time for uniqueness
  SeedStr := IntToStr(DateTimeToFileDate(Now)) + '-' + IntToStr(Random(1000000)) + '-buddy-hatch';
  Hash := FNV1a(SeedStr);
  RngState := Hash;

  // 1. Roll rarity (weighted: common:60, uncommon:25, rare:10, epic:4, legendary:1)
  R := NextRng * 100.0;
  if R < 60 then RarIdx := 0       // common
  else if R < 85 then RarIdx := 1  // uncommon
  else if R < 95 then RarIdx := 2  // rare
  else if R < 99 then RarIdx := 3  // epic
  else RarIdx := 4;                // legendary
  FResult.Rarity := RarityNames[RarIdx];
  Base := RarityBase[RarIdx];

  // 2. Roll species
  FResult.Species := SpeciesNames[Trunc(NextRng * SPECIES_COUNT)];

  // 3. Roll eye
  FResult.Eye := EyeChars[Trunc(NextRng * EYE_COUNT)];

  // 4. Roll hat (common = none, others get random)
  if RarIdx = 0 then
    FResult.Hat := 'none'
  else
    FResult.Hat := HatNames[Trunc(NextRng * HAT_COUNT)];

  // 5. Roll shiny (1% chance)
  FResult.Shiny := NextRng < 0.01;

  // 6. Roll stats (Yb4 algorithm)
  Primary := Trunc(NextRng * STAT_COUNT);
  Secondary := Trunc(NextRng * STAT_COUNT);
  while Secondary = Primary do
    Secondary := Trunc(NextRng * STAT_COUNT);

  for I := 0 to STAT_COUNT - 1 do
  begin
    if I = Primary then
      StatVals[I] := Min(100, Base + 50 + Trunc(NextRng * 30))
    else if I = Secondary then
      StatVals[I] := Max(1, Base - 10 + Trunc(NextRng * 15))
    else
      StatVals[I] := Base + Trunc(NextRng * 40);
  end;

  FResult.Debugging := StatVals[0];
  FResult.Patience := StatVals[1];
  FResult.Chaos := StatVals[2];
  FResult.Wisdom := StatVals[3];
  FResult.Snark := StatVals[4];

  // Update config with rolled bones for the API call
  FConfig.Species := FResult.Species;
  FConfig.Eye := FResult.Eye;
  FConfig.Hat := FResult.Hat;
  FConfig.Rarity := FResult.Rarity;
  FConfig.Debugging := StatVals[0];
  FConfig.Patience := StatVals[1];
  FConfig.Chaos := StatVals[2];
  FConfig.Wisdom := StatVals[3];
  FConfig.Snark := StatVals[4];

  // Pick 4 random inspiration words
  for I := 0 to 3 do
    InspirationIdxs[I] := Trunc(NextRng * INSPIRATION_WORD_COUNT);

  StatStr := Format('DEBUGGING:%d PATIENCE:%d CHAOS:%d WISDOM:%d SNARK:%d',
    [FConfig.Debugging, FConfig.Patience, FConfig.Chaos, FConfig.Wisdom, FConfig.Snark]);

  UserMsg := Format(
    'Generate a companion.'#10 +
    'Rarity: %s'#10 +
    'Species: %s'#10 +
    'Stats: %s'#10 +
    'Inspiration words: %s, %s, %s, %s'#10 +
    '%s'#10 +
    'Reply EXACTLY in this format (two lines only):'#10 +
    'NAME: (one word, max 12 chars)'#10 +
    'PERSONALITY: (one sentence personality description)',
    [UpperCase(FConfig.Rarity), FConfig.Species, StatStr,
     InspirationWords[InspirationIdxs[0]], InspirationWords[InspirationIdxs[1]],
     InspirationWords[InspirationIdxs[2]], InspirationWords[InspirationIdxs[3]],
     IfThen(FResult.Shiny, 'SHINY variant — extra special.', '')]);

  // Use buddy_react with the hatching prompt as transcript
  Token := FCreds.AccessToken;
  if Token = '' then
  begin
    FResult.Success := False;
    FResult.Name := '';
    FResult.Personality := 'Not logged in';
    FHatchDone := True;
    Exit;
  end;

  Params.Name := 'egg';
  Params.Personality := HATCHING_SYSTEM_PROMPT;
  Params.Species := FConfig.Species;
  Params.Rarity := FConfig.Rarity;
  Params.Stats := Format('{"DEBUGGING":%d,"PATIENCE":%d,"CHAOS":%d,"WISDOM":%d,"SNARK":%d}',
    [FConfig.Debugging, FConfig.Patience, FConfig.Chaos, FConfig.Wisdom, FConfig.Snark]);
  Params.Transcript := UserMsg;
  Params.Reason := 'hatch';
  Params.Addressed := False;
  SetLength(Params.Recent, 0);

  try
    ApiResult := BuddyReact(Params, Token, FConfig.OrgUuid);
    if ApiResult.Success and (ApiResult.Reaction <> '') then
    begin
      FResult.Success := True;
      // Parse "NAME: Xxx\nPERSONALITY: yyy" format
      FResult.Name := '';
      FResult.Personality := '';
      // Try to extract NAME: line
      I := Pos('NAME:', UpperCase(ApiResult.Reaction));
      if I > 0 then
      begin
        S := Copy(ApiResult.Reaction, I + 5, 50);
        J := Pos(#10, S);
        if J > 0 then S := Copy(S, 1, J - 1);
        FResult.Name := Trim(S);
      end;
      // Try to extract PERSONALITY: line
      I := Pos('PERSONALITY:', UpperCase(ApiResult.Reaction));
      if I > 0 then
        FResult.Personality := Trim(Copy(ApiResult.Reaction, I + 12, 200));

      // Fallback: if parsing failed, use first word as name, rest as personality
      if FResult.Name = '' then
      begin
        S := Trim(ApiResult.Reaction);
        I := Pos(' ', S);
        if I > 0 then
        begin
          FResult.Name := Copy(S, 1, I - 1);
          FResult.Personality := Trim(Copy(S, I + 1, 200));
        end
        else
        begin
          FResult.Name := S;
          FResult.Personality := Format('A %s %s.', [FConfig.Rarity, FConfig.Species]);
        end;
      end;
      if FResult.Personality = '' then
        FResult.Personality := Format('A %s %s of few words.', [FConfig.Rarity, FConfig.Species]);

      // Silently truncate personality to API limit
      if Length(FResult.Personality) > 200 then
        FResult.Personality := Copy(FResult.Personality, 1, 197) + '...';
      // Truncate name to API limit
      if Length(FResult.Name) > 14 then
        FResult.Name := Copy(FResult.Name, 1, 14);
    end
    else
    begin
      // Fallback
      FResult.Success := True;
      I := Random(Length(FallbackNames));
      FResult.Name := FallbackNames[I];
      FResult.Personality := Format('A %s %s of few words.',
        [FConfig.Rarity, FConfig.Species]);
    end;
  except
    on E: Exception do
    begin
      FResult.Success := True;
      I := Random(Length(FallbackNames));
      FResult.Name := FallbackNames[I];
      FResult.Personality := Format('A %s %s of few words.',
        [FConfig.Rarity, FConfig.Species]);
    end;
  end;

  FHatchDone := True;
end;

procedure TFormHatch.StartHatch(const AConfig: TBuddyConfig; const ACreds: TCredentials);
begin
  FConfig := AConfig;
  FCreds := ACreds;
  FAnimFrame := 0;
  FHatchDone := False;
  FStatusLabel.Caption := 'Hatching your companion...';
  FAnimTimer.Enabled := True;

  // Start the API call in the background (will complete while egg wobbles)
  Application.ProcessMessages;
  DoHatch;
end;

end.
