unit uFormMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StrUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  Menus, LCLIntf, LCLType, Clipbrd, process,
  uCompanionData, uConfig, uCredentials, uApiClient, uValidation;

type
  TFormMain = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure FormMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
  private
    FConfig: TBuddyConfig;
    FCreds: TCredentials;
    FSpeciesIdx: Integer;

    FAnimTimer: TTimer;
    FAnimTick: Integer;   // position in AnimSequence
    FFrameIdx: Integer;   // resolved art frame (0-2)
    FBlinking: Boolean;   // true = replace eyes with '-'

    FBubbleText: string;
    FBubbleTimer: TTimer;
    FBubbleForm: TForm;  // separate popup for speech bubble

    FPetTimer: TTimer;
    FPetFrame: Integer;
    FIsPetting: Boolean;
    FIsReading: Boolean;
    FChatting: Boolean;  // true while chat input is open

    FChatButton: TButton;
    FPetButton: TButton;

    FClipTimer: TTimer;
    FLastClipText: string;
    FLastApiCall: TDateTime;

    FIdleTimer: TTimer;
    FInitBubbleTimer: TTimer;
    FAmbientTimer: TTimer;
    FStartTime: TDateTime;

    FDragging: Boolean;
    FDragX, FDragY: Integer;

    FTrayIcon: TTrayIcon;
    FPopup: TPopupMenu;
    FAlwaysFrontItem: TMenuItem;
    FBubbleTopItem: TMenuItem;
    FBubbleLeftItem: TMenuItem;
    FBubbleRightItem: TMenuItem;
    FAlwaysFront: Boolean;
    FBubbleAnchor: Integer;  // 0=top, 1=left, 2=right
    FRecent: array of string;
    FChatLog: TStringList;  // rolling user+buddy conversation for context
    FHistory: TStringList;
    FBubbleLines: TStringList;

    FMonoFont: TFont;
    FBubbleFont: TFont;
    FCharW: Integer;
    FCharH: Integer;

    // Theme color (from rarity)
    FThemeColor: LongInt;

    // Fixed layout positions (computed once)
    FArtTop: Integer;
    FNameY: Integer;
    FInputY: Integer;
    FBubbleAreaBottom: Integer;  // top area reserved for bubble

    procedure SetupUI;
    procedure SetupTimers;
    procedure SetupPopupMenu;
    procedure LoadState;
    procedure SaveState;
    procedure ComputeLayout;

    procedure OnAnimTimer(Sender: TObject);
    procedure OnBubbleTimer(Sender: TObject);
    procedure OnPetTimer(Sender: TObject);
    procedure OnClipTimer(Sender: TObject);
    procedure OnIdleTimer(Sender: TObject);
    procedure OnInitBubble(Sender: TObject);
    procedure OnChatClick(Sender: TObject);
    procedure OnPetClick(Sender: TObject);
    procedure OnMenuConfig(Sender: TObject);
    procedure OnMenuReadFile(Sender: TObject);
    procedure OnMenuAlwaysFront(Sender: TObject);
    procedure OnMenuBubbleAnchor(Sender: TObject);
    procedure OnMenuHistory(Sender: TObject);
    procedure OnMenuMinimize(Sender: TObject);
    procedure OnMenuQuit(Sender: TObject);
    procedure OnFileDrop(Sender: TObject; const FileNames: array of string);
    procedure OnTrayClick(Sender: TObject);
    procedure OnAmbientTimer(Sender: TObject);
    procedure PaintReadingAnim(ACanvas: TCanvas);
    function BuildAmbientContext: string;

    procedure SendToApi(const ATranscript, AReason: string; AAddressed: Boolean);
    procedure OnApiResult(const AResult: TBuddyReactResult);
    procedure AddToChatLog(const ARole, AText: string);
    function BuildTranscriptWithHistory(const ANewMessage: string): string;
    procedure ShowBubble(const AText: string);
    procedure AddRecent(const AText: string);
    function BuildStatsJSON: string;
    function EnsureToken: string;

    procedure PositionBubble;
    procedure PaintTerminalFrame(ACanvas: TCanvas);
    procedure PaintCompanion(ACanvas: TCanvas);
    procedure PaintName(ACanvas: TCanvas);
    procedure PaintBubble(Sender: TObject);
    procedure PaintPetHearts(ACanvas: TCanvas);
    procedure PaintConnector(ACanvas: TCanvas);

    function GetArtLines: TStringList;
  public
  end;

var
  FormMain: TFormMain;

implementation

uses
  uOAuth, uFormConfig;

{$R *.lfm}

const
  MARGIN          = 16;
  BUBBLE_PAD      = 8;
  BUBBLE_MAX_W    = 340;
  BUBBLE_DISMISS  = 12000;
  FORM_BG         = $00000000;  // pure black
  DEFAULT_TEXT     = $0000DD00;  // default green (overridden by rarity)
  DIM_COLOR        = $00808080;  // grey for name
  HEART_COLOR     = $00DD00DD;  // magenta
  BUBBLE_BG       = $00101010;  // very dark bubble fill
  ANIM_INTERVAL   = 650;
  PET_INTERVAL    = 180;
  CLIP_INTERVAL   = 3000;
  API_COOLDOWN    = 30;
  CORNER_RADIUS   = 14;

  ART_INDENT      = 1;   // extra columns to shift art right for centering
  INPUT_H          = 28;

procedure TFormMain.FormCreate(Sender: TObject);
begin
  BorderStyle := bsNone;
  FormStyle := fsStayOnTop;
  Color := FORM_BG;
  DoubleBuffered := True;
  AutoScroll := False;
  Scaled := False;  // we handle our own DPI-aware layout

  FMonoFont := TFont.Create;
  {$IFDEF WINDOWS}
  FMonoFont.Name := 'Consolas';
  {$ELSE}
    {$IFDEF DARWIN}
    FMonoFont.Name := 'Menlo';
    {$ELSE}
    FMonoFont.Name := 'DejaVu Sans Mono';
    {$ENDIF}
  {$ENDIF}
  FMonoFont.Size := 14;  // slightly smaller to avoid cramping on high-DPI
  {$IFDEF WINDOWS}
  FMonoFont.Quality := fqClearType;
  {$ENDIF}

  FBubbleFont := TFont.Create;
  FBubbleFont.Name := FMonoFont.Name;
  FBubbleFont.Size := 10;
  {$IFDEF WINDOWS}
  FBubbleFont.Quality := fqClearType;
  {$ENDIF}

  Canvas.Font.Assign(FMonoFont);
  FCharW := Canvas.TextWidth('M');
  FCharH := Canvas.TextHeight('M');

  FAnimTick := 0;
  FFrameIdx := 0;
  FBlinking := False;
  FBubbleText := '';
  FIsPetting := False;
  FIsReading := False;
  FChatting := False;
  FDragging := False;
  FStartTime := Now;

  // Seed clipboard state so the watcher doesn't fire on whatever's already there
  try
    if Clipboard.HasFormat(CF_TEXT) then
      FLastClipText := Clipboard.AsText;
  except
  end;
  FLastApiCall := 0;
  FAlwaysFront := True;
  FBubbleAnchor := 0;  // 0=top (default)
  SetLength(FRecent, 0);
  FChatLog := TStringList.Create;
  FHistory := TStringList.Create;
  FBubbleLines := TStringList.Create;

  LoadState;
  ComputeLayout;
  SetupPopupMenu;
  SetupUI;
  SetupTimers;

  if (FConfig.WindowX >= 0) and (FConfig.WindowY >= 0) then
  begin
    Position := poDesigned;
    Left := FConfig.WindowX;
    Top := FConfig.WindowY;
  end
  else
  begin
    // Launch in lower-right of screen
    Position := poDesigned;
    Left := Screen.Width - Width - 40;
    Top := Screen.Height - Height - 80;
  end;

  // Enable drag-and-drop files
  AllowDropFiles := True;
  OnDropFiles := @OnFileDrop;

  // System tray icon
  FTrayIcon := TTrayIcon.Create(Self);
  FTrayIcon.Hint := 'BonziClaude - ' + FConfig.Name;
  FTrayIcon.PopUpMenu := FPopup;
  FTrayIcon.OnClick := @OnTrayClick;
  // Use the application icon for the tray
  FTrayIcon.Icon.Assign(Application.Icon);
  FTrayIcon.Visible := True;

  // Show in taskbar normally — tray icon is for restore when hidden
  ShowInTaskBar := stAlways;

  // Delay initial bubble until form is positioned on screen
  FInitBubbleTimer := TTimer.Create(Self);
  FInitBubbleTimer.Interval := 800;  // longer delay for WM to finalize position
  FInitBubbleTimer.OnTimer := @OnInitBubble;
  FInitBubbleTimer.Enabled := True;
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  SaveState;
  FMonoFont.Free;
  FBubbleFont.Free;
  FChatLog.Free;
  FHistory.Free;
  FBubbleLines.Free;
end;

procedure TFormMain.ComputeLayout;
var
  ArtLineCount, HatIdx: Integer;
begin
  // Art is 4 lines normally (blank line 0 removed), 5 with hat
  HatIdx := GetHatIndex(FConfig.Hat);
  if (HatIdx > 0) and (HatIdx < HAT_COUNT) and (HatArt[HatIdx] <> '') then
    ArtLineCount := 5   // hat + 4 body lines
  else
    ArtLineCount := 4;  // blank line 0 removed

  Width := FCharW * (14 + ART_INDENT) + MARGIN * 2;

  Height := MARGIN +
            ArtLineCount * FCharH +
            4 +
            FCharH +              // name
            6 +
            INPUT_H +             // input
            MARGIN;

  FInputY := Height - MARGIN - INPUT_H;
  FNameY := FInputY - 6 - FCharH;
  FArtTop := FNameY - 4 - ArtLineCount * FCharH;
  FBubbleAreaBottom := 0;
end;

procedure TFormMain.LoadState;
var
  Imported: TBuddyConfig;
  ImportedCreds: TCredentials;
  I: Integer;
begin
  FConfig := LoadConfig(GetConfigPath);

  if FConfig.OrgUuid = '' then
  begin
    if ImportFromClaudeCode(Imported) then
    begin
      FConfig := Imported;
      FConfig.ClipboardWatch := True;
      FConfig.IdleReactMinutes := 5;
      SaveConfig(GetConfigPath, FConfig);
    end;
  end;

  FCreds := LoadCredentials(GetCredentialsPath);
  if FCreds.AccessToken = '' then
  begin
    if ImportClaudeCodeCredentials(ImportedCreds) then
    begin
      FCreds := ImportedCreds;
      SaveCredentials(GetCredentialsPath, FCreds);
    end;
  end;

  FSpeciesIdx := GetSpeciesIndex(FConfig.Species);
  if FSpeciesIdx < 0 then
    FSpeciesIdx := 15;

  // Set theme color from rarity
  I := GetRarityIndex(FConfig.Rarity);
  if (I >= 0) and (I < RARITY_COUNT) then
    FThemeColor := RarityTColors[I]
  else
    FThemeColor := DEFAULT_TEXT;
end;

procedure TFormMain.SaveState;
begin
  FConfig.WindowX := Left;
  FConfig.WindowY := Top;
  SaveConfig(GetConfigPath, FConfig);
end;

procedure TFormMain.SetupUI;
var
  BtnW: Integer;
begin
  BtnW := (Width - MARGIN * 2 - 8) div 2;

  // Chat button — opens input in the bubble
  FChatButton := TButton.Create(Self);
  FChatButton.Parent := Self;
  FChatButton.Caption := 'Chat';
  FChatButton.Width := BtnW;
  FChatButton.Height := INPUT_H;
  FChatButton.Font.Size := 9;
  FChatButton.OnClick := @OnChatClick;
  FChatButton.Hint := 'Chat with ' + FConfig.Name;
  FChatButton.ShowHint := True;
  FChatButton.Top := FInputY;
  FChatButton.Left := MARGIN;

  // Pet button
  FPetButton := TButton.Create(Self);
  FPetButton.Parent := Self;
  FPetButton.Caption := #$E2#$99#$A5;  // ♥
  FPetButton.Width := BtnW;
  FPetButton.Height := INPUT_H;
  FPetButton.Font.Size := 10;
  FPetButton.OnClick := @OnPetClick;
  FPetButton.Hint := 'Pet ' + FConfig.Name;
  FPetButton.ShowHint := True;
  FPetButton.Top := FInputY;
  FPetButton.Left := FChatButton.Left + FChatButton.Width + 8;
end;

procedure TFormMain.SetupPopupMenu;
var
  MI: TMenuItem;
begin
  FPopup := TPopupMenu.Create(Self);
  PopupMenu := FPopup;

  MI := TMenuItem.Create(FPopup);
  MI.Caption := 'Configure...';
  MI.OnClick := @OnMenuConfig;
  FPopup.Items.Add(MI);

  MI := TMenuItem.Create(FPopup);
  MI.Caption := 'Read File...';
  MI.OnClick := @OnMenuReadFile;
  FPopup.Items.Add(MI);

  MI := TMenuItem.Create(FPopup);
  MI.Caption := 'History';
  MI.OnClick := @OnMenuHistory;
  FPopup.Items.Add(MI);

  MI := TMenuItem.Create(FPopup);
  MI.Caption := '-';
  FPopup.Items.Add(MI);

  // Bubble position submenu
  MI := TMenuItem.Create(FPopup);
  MI.Caption := 'Speech Bubble';
  FPopup.Items.Add(MI);

  FBubbleTopItem := TMenuItem.Create(MI);
  FBubbleTopItem.Caption := 'Above';
  FBubbleTopItem.Tag := 0;
  FBubbleTopItem.Checked := True;
  FBubbleTopItem.OnClick := @OnMenuBubbleAnchor;
  MI.Add(FBubbleTopItem);

  FBubbleLeftItem := TMenuItem.Create(MI);
  FBubbleLeftItem.Caption := 'Left';
  FBubbleLeftItem.Tag := 1;
  FBubbleLeftItem.OnClick := @OnMenuBubbleAnchor;
  MI.Add(FBubbleLeftItem);

  FBubbleRightItem := TMenuItem.Create(MI);
  FBubbleRightItem.Caption := 'Right';
  FBubbleRightItem.Tag := 2;
  FBubbleRightItem.OnClick := @OnMenuBubbleAnchor;
  MI.Add(FBubbleRightItem);

  FAlwaysFrontItem := TMenuItem.Create(FPopup);
  FAlwaysFrontItem.Caption := 'Always on Top';
  FAlwaysFrontItem.Checked := True;
  FAlwaysFrontItem.OnClick := @OnMenuAlwaysFront;
  FPopup.Items.Add(FAlwaysFrontItem);

  MI := TMenuItem.Create(FPopup);
  MI.Caption := 'Minimize';
  MI.OnClick := @OnMenuMinimize;
  FPopup.Items.Add(MI);

  MI := TMenuItem.Create(FPopup);
  MI.Caption := '-';
  FPopup.Items.Add(MI);

  MI := TMenuItem.Create(FPopup);
  MI.Caption := 'Quit';
  MI.OnClick := @OnMenuQuit;
  FPopup.Items.Add(MI);
end;

procedure TFormMain.SetupTimers;
begin
  FAnimTimer := TTimer.Create(Self);
  FAnimTimer.Interval := ANIM_INTERVAL;
  FAnimTimer.OnTimer := @OnAnimTimer;
  FAnimTimer.Enabled := True;

  FBubbleTimer := TTimer.Create(Self);
  FBubbleTimer.Interval := BUBBLE_DISMISS;
  FBubbleTimer.OnTimer := @OnBubbleTimer;
  FBubbleTimer.Enabled := False;

  FPetTimer := TTimer.Create(Self);
  FPetTimer.Interval := PET_INTERVAL;
  FPetTimer.OnTimer := @OnPetTimer;
  FPetTimer.Enabled := False;

  FClipTimer := TTimer.Create(Self);
  FClipTimer.Interval := CLIP_INTERVAL;
  FClipTimer.OnTimer := @OnClipTimer;
  FClipTimer.Enabled := FConfig.ClipboardWatch;

  FIdleTimer := TTimer.Create(Self);
  if FConfig.IdleReactMinutes > 0 then
    FIdleTimer.Interval := FConfig.IdleReactMinutes * 60000
  else
    FIdleTimer.Interval := 300000;
  FIdleTimer.OnTimer := @OnIdleTimer;
  FIdleTimer.Enabled := FConfig.IdleReactMinutes > 0;

  // Ambient timer — fires every 10 minutes with benign system observations
  FAmbientTimer := TTimer.Create(Self);
  FAmbientTimer.Interval := 600000;  // 10 minutes
  FAmbientTimer.OnTimer := @OnAmbientTimer;
  FAmbientTimer.Enabled := True;
end;

// ============================================================
//  Painting — fixed layout, nothing moves
// ============================================================

procedure TFormMain.FormPaint(Sender: TObject);
begin
  Canvas.Brush.Color := FORM_BG;
  Canvas.FillRect(ClientRect);

  PaintTerminalFrame(Canvas);
  PaintCompanion(Canvas);
  PaintName(Canvas);

  if FIsPetting then
    PaintPetHearts(Canvas);
  if FIsReading then
    PaintReadingAnim(Canvas);
end;

procedure TFormMain.PositionBubble;
var
  Pt: TPoint;
begin
  if FBubbleForm = nil then Exit;

  case FBubbleAnchor of
    0: begin  // Above: bottom of bubble flush with top of form
      Pt := ClientToScreen(Point(ClientWidth, 0));
      FBubbleForm.Left := Pt.X - FBubbleForm.Width;
      FBubbleForm.Top := Pt.Y - FBubbleForm.Height;
    end;
    1: begin  // Left: right edge of bubble at left edge of form
      Pt := ClientToScreen(Point(0, ClientHeight div 2));
      FBubbleForm.Left := Pt.X - FBubbleForm.Width;
      FBubbleForm.Top := Pt.Y - FBubbleForm.Height div 2;
    end;
    2: begin  // Right: left edge of bubble at right edge of form
      Pt := ClientToScreen(Point(ClientWidth, ClientHeight div 2));
      FBubbleForm.Left := Pt.X;
      FBubbleForm.Top := Pt.Y - FBubbleForm.Height div 2;
    end;
  end;
end;

procedure TFormMain.PaintTerminalFrame(ACanvas: TCanvas);
begin
  // Grey rounded terminal border
  ACanvas.Pen.Color := FThemeColor;
  ACanvas.Pen.Width := 2;
  ACanvas.Brush.Style := bsClear;
  ACanvas.RoundRect(1, 1, ClientWidth - 1, ClientHeight - 1,
                    CORNER_RADIUS, CORNER_RADIUS);
  ACanvas.Pen.Width := 1;
  ACanvas.Brush.Style := bsSolid;
end;

procedure TFormMain.PaintCompanion(ACanvas: TCanvas);
var
  Lines: TStringList;
  I, Y: Integer;
begin
  Lines := GetArtLines;
  try
    ACanvas.Font.Assign(FMonoFont);
    ACanvas.Font.Color := FThemeColor;
    ACanvas.Brush.Style := bsClear;

    for I := 0 to Lines.Count - 1 do
    begin
      Y := FArtTop + I * FCharH;
      ACanvas.TextOut(MARGIN + FCharW * ART_INDENT, Y, Lines[I]);
    end;

    ACanvas.Brush.Style := bsSolid;
  finally
    Lines.Free;
  end;
end;

procedure TFormMain.PaintName(ACanvas: TCanvas);
var
  NameText: string;
  NameW: Integer;
begin
  if FConfig.Shiny then
    NameText := '*' + FConfig.Name + '*'  // shiny sparkle
  else
    NameText := FConfig.Name;
  ACanvas.Font.Assign(FMonoFont);
  ACanvas.Font.Size := 12;
  ACanvas.Font.Style := [fsItalic];
  if FConfig.Shiny then
    ACanvas.Font.Color := $0008B3EA  // gold for shiny
  else
    ACanvas.Font.Color := DIM_COLOR;
  ACanvas.Brush.Style := bsClear;
  NameW := ACanvas.TextWidth(NameText);
  ACanvas.TextOut(MARGIN + (FCharW * 14 - NameW) div 2, FNameY, NameText);
  ACanvas.Font.Style := [];
  ACanvas.Brush.Style := bsSolid;
end;

procedure TFormMain.PaintBubble(Sender: TObject);
var
  F: TForm;
  C: TCanvas;
  I, Y, TextH, ConnY: Integer;
  BubbleRect: TRect;
begin
  if not (Sender is TForm) then Exit;
  F := TForm(Sender);
  C := F.Canvas;

  C.Brush.Color := FORM_BG;
  C.FillRect(F.ClientRect);

  C.Font.Assign(FBubbleFont);
  TextH := C.TextHeight('Mg');

  // Bubble box fills the form except the last line (connector)
  ConnY := F.ClientHeight - FCharH;

  BubbleRect.Left := 0;
  BubbleRect.Top := 0;
  BubbleRect.Right := F.ClientWidth;
  BubbleRect.Bottom := ConnY;

  C.Pen.Color := FThemeColor;
  C.Brush.Color := BUBBLE_BG;
  C.Rectangle(BubbleRect);

  // Paint text vertically centered inside the box
  if FBubbleLines.Count > 0 then
  begin
    C.Brush.Style := bsClear;
    C.Font.Color := FThemeColor;
    Y := (ConnY - FBubbleLines.Count * TextH) div 2;
    if Y < BUBBLE_PAD then Y := BUBBLE_PAD;
    for I := 0 to FBubbleLines.Count - 1 do
    begin
      C.TextOut(BUBBLE_PAD + 2, Y, FBubbleLines[I]);
      Inc(Y, TextH);
    end;
  end;

  // Connector flush at bottom
  C.Font.Assign(FMonoFont);
  C.Font.Color := FThemeColor;
  C.Brush.Style := bsClear;
  case FBubbleAnchor of
    0: C.TextOut(F.ClientWidth - FCharW * 2, ConnY, '|');
    1: C.TextOut(F.ClientWidth - FCharW, ConnY, '-');
    2: C.TextOut(2, ConnY, '-');
  end;

  C.Brush.Style := bsSolid;
end;

procedure TFormMain.PaintConnector(ACanvas: TCanvas);
begin
  // Connector is now drawn inside the bubble form's OnPaint
end;

procedure TFormMain.PaintPetHearts(ACanvas: TCanvas);
begin
  if (FPetFrame >= 0) and (FPetFrame <= High(PetFrames)) then
  begin
    ACanvas.Font.Assign(FMonoFont);
    ACanvas.Font.Color := HEART_COLOR;
    ACanvas.Brush.Style := bsClear;
    ACanvas.TextOut(MARGIN + FCharW * ART_INDENT, FArtTop, PetFrames[FPetFrame]);
    ACanvas.Brush.Style := bsSolid;
  end;
end;

procedure TFormMain.PaintReadingAnim(ACanvas: TCanvas);
begin
  if (FPetFrame >= 0) and (FPetFrame <= High(ReadFrames)) then
  begin
    ACanvas.Font.Assign(FMonoFont);
    ACanvas.Font.Color := FThemeColor;  // green binary digits
    ACanvas.Brush.Style := bsClear;
    ACanvas.TextOut(MARGIN + FCharW * ART_INDENT, FArtTop, ReadFrames[FPetFrame]);
    ACanvas.Brush.Style := bsSolid;
  end;
end;

function TFormMain.GetArtLines: TStringList;
var
  Frame: TArtFrame;
  Line, EyeChar: string;
  I, HatIdx: Integer;
  HasHat: Boolean;
begin
  Result := TStringList.Create;

  Frame := GetArtFrame(FSpeciesIdx, FFrameIdx);
  HatIdx := GetHatIndex(FConfig.Hat);
  HasHat := (HatIdx > 0) and (HatIdx < HAT_COUNT) and (HatArt[HatIdx] <> '');

  if FBlinking then
    EyeChar := '-'
  else
    EyeChar := FConfig.Eye;

  // Match Claude Code behavior exactly:
  // - If hat: replace blank line 0 with hat art
  // - If no hat and line 0 is blank: SKIP line 0 entirely (shift)
  if HasHat then
    Result.Add(HatArt[HatIdx])
  else if Trim(Frame[0]) <> '' then
    Result.Add(SubstituteEyes(Frame[0], EyeChar));
  // else: skip blank line 0 (no hat, blank first line → remove it)

  for I := 1 to 4 do
    Result.Add(SubstituteEyes(Frame[I], EyeChar));
end;

// ============================================================
//  Dragging
// ============================================================

procedure TFormMain.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
  begin
    FDragging := True;
    FDragX := X;
    FDragY := Y;
  end;
end;

procedure TFormMain.FormMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
begin
  if FDragging then
  begin
    Left := Left + X - FDragX;
    Top := Top + Y - FDragY;
    PositionBubble;
  end;
end;

procedure TFormMain.FormMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if FDragging then
  begin
    FDragging := False;
    // Save position on every drag end
    FConfig.WindowX := Left;
    FConfig.WindowY := Top;
    SaveConfig(GetConfigPath, FConfig);
  end;
end;

// ============================================================
//  Timers
// ============================================================

procedure TFormMain.OnAnimTimer(Sender: TObject);
var
  SeqVal: Integer;
begin
  FAnimTick := (FAnimTick + 1) mod ANIM_SEQ_LEN;
  SeqVal := AnimSequence[FAnimTick];
  if SeqVal = BLINK_FRAME then
  begin
    FFrameIdx := 0;
    FBlinking := True;
  end
  else
  begin
    FFrameIdx := SeqVal mod FRAME_COUNT;
    FBlinking := False;
  end;
  Invalidate;
end;

procedure TFormMain.OnBubbleTimer(Sender: TObject);
begin
  FBubbleText := '';
  FBubbleTimer.Enabled := False;
  if FBubbleForm <> nil then
    FBubbleForm.Hide;
  Invalidate;
end;

procedure TFormMain.OnPetTimer(Sender: TObject);
begin
  Inc(FPetFrame);
  if FIsPetting and (FPetFrame > High(PetFrames)) then
  begin
    FIsPetting := False;
    FPetTimer.Enabled := not FIsReading;
    FPetFrame := 0;
  end;
  if FIsReading and (FPetFrame > High(ReadFrames)) then
  begin
    FIsReading := False;
    FPetTimer.Enabled := FIsPetting;
    FPetFrame := 0;
  end;
  Invalidate;
end;

procedure TFormMain.OnClipTimer(Sender: TObject);
var
  ClipText: string;
begin
  if FChatting then Exit;
  if (not FConfig.ClipboardWatch) or (FConfig.PrivacyMode = 0) then Exit;
  try
    if Clipboard.HasFormat(CF_TEXT) then
    begin
      ClipText := Clipboard.AsText;
      if (ClipText <> FLastClipText) and (Length(ClipText) > 10) then
      begin
        FLastClipText := ClipText;
        if (Now - FLastApiCall) * 86400 > API_COOLDOWN then
          SendToApi(ClipText, 'turn', False);
      end;
    end;
  except
  end;
end;

procedure TFormMain.OnIdleTimer(Sender: TObject);
begin
  if FChatting then Exit;
  if (Now - FLastApiCall) * 86400 > API_COOLDOWN then
    SendToApi('User has been idle. Say something.', 'turn', False);
end;

function TFormMain.BuildAmbientContext: string;
var
  Hour, Min, Sec, MS: Word;
  Y, M, D: Word;
  SessionMins: Integer;
  DayName: string;
  Context: string;
  ProcOutput: string;
  Proc: TProcess;
  OutStream: TStringStream;
begin
  DecodeTime(Time, Hour, Min, Sec, MS);
  DecodeDate(Date, Y, M, D);
  SessionMins := Round((Now - FStartTime) * 24 * 60);

  case DayOfWeek(Date) of
    1: DayName := 'Sunday';
    2: DayName := 'Monday';
    3: DayName := 'Tuesday';
    4: DayName := 'Wednesday';
    5: DayName := 'Thursday';
    6: DayName := 'Friday';
    7: DayName := 'Saturday';
  end;

  Context := Format('Current time: %d:%2.2d %s. Day: %s. ', [Hour, Min,
    IfThen(Hour < 12, 'AM', 'PM'), DayName]);

  if Hour < 6 then
    Context := Context + 'It is very late at night. '
  else if Hour < 9 then
    Context := Context + 'It is early morning. '
  else if Hour < 12 then
    Context := Context + 'It is mid-morning. '
  else if Hour < 14 then
    Context := Context + 'It is around lunchtime. '
  else if Hour < 17 then
    Context := Context + 'It is afternoon. '
  else if Hour < 20 then
    Context := Context + 'It is evening. '
  else
    Context := Context + 'It is late evening. ';

  if SessionMins < 30 then
    Context := Context + 'User just started their session. '
  else if SessionMins < 120 then
    Context := Context + Format('User has been working for about %d minutes. ', [SessionMins])
  else
    Context := Context + Format('User has been working for %d hours %d minutes. Long session! ',
      [SessionMins div 60, SessionMins mod 60]);

  if DayName = 'Monday' then
    Context := Context + 'It''s Monday. '
  else if DayName = 'Friday' then
    Context := Context + 'It''s Friday! '
  else if (DayName = 'Saturday') or (DayName = 'Sunday') then
    Context := Context + 'User is working on the weekend. ';

  // Personalized mode (privacy=2): include system details
  if FConfig.PrivacyMode >= 2 then
  begin
    Context := Context + Format('Username: %s. ',
      [GetEnvironmentVariable({$IFDEF WINDOWS}'USERNAME'{$ELSE}'USER'{$ENDIF})]);

    // System context — all gathered silently (no console flash)
    try
      begin
        // Active window title
        Proc := TProcess.Create(nil);
        try
          {$IFDEF WINDOWS}
          Proc.Executable := 'cmd';
          Proc.Parameters.Add('/c');
          Proc.Parameters.Add('powershell -NoProfile -Command "(Get-Process | Where-Object {$_.MainWindowTitle -ne ''} | Select-Object -First 5 | ForEach-Object { $_.MainWindowTitle }) -join '', ''"');
          {$ELSE}
          Proc.Executable := '/bin/sh';
          Proc.Parameters.Add('-c');
          Proc.Parameters.Add('xdotool getactivewindow getwindowname 2>/dev/null || echo "unknown"');
          {$ENDIF}
          Proc.Options := [poUsePipes, poNoConsole, poStderrToOutput];
          Proc.ShowWindow := swoHIDE;
          Proc.Execute;

          OutStream := TStringStream.Create('');
          try
            OutStream.CopyFrom(Proc.Output, 0);
            ProcOutput := Trim(Copy(OutStream.DataString, 1, 300));
            if ProcOutput <> '' then
              Context := Context + 'Active windows: ' + ProcOutput + '. ';
          finally
            OutStream.Free;
          end;
        finally
          Proc.Free;
        end;

        // Top processes by memory
        Proc := TProcess.Create(nil);
        try
          {$IFDEF WINDOWS}
          Proc.Executable := 'cmd';
          Proc.Parameters.Add('/c');
          Proc.Parameters.Add('tasklist /FO CSV /NH');
          {$ELSE}
          Proc.Executable := '/bin/sh';
          Proc.Parameters.Add('-c');
          Proc.Parameters.Add('ps aux --sort=-%mem | head -6 | tail -5');
          {$ENDIF}
          Proc.Options := [poUsePipes, poNoConsole, poStderrToOutput];
          Proc.ShowWindow := swoHIDE;
          Proc.Execute;

          OutStream := TStringStream.Create('');
          try
            OutStream.CopyFrom(Proc.Output, 0);
            ProcOutput := Copy(OutStream.DataString, 1, 400);
            if ProcOutput <> '' then
              Context := Context + 'Running processes: ' + ProcOutput + '. ';
          finally
            OutStream.Free;
          end;
        finally
          Proc.Free;
        end;

        // System uptime
        Proc := TProcess.Create(nil);
        try
          {$IFDEF WINDOWS}
          Proc.Executable := 'cmd';
          Proc.Parameters.Add('/c');
          Proc.Parameters.Add('powershell -NoProfile -Command "[math]::Round((Get-Date) .Subtract((Get-CimInstance Win32_OperatingSystem).LastBootUpTime).TotalHours, 1)"');
          {$ELSE}
          Proc.Executable := '/bin/sh';
          Proc.Parameters.Add('-c');
          Proc.Parameters.Add('uptime -p 2>/dev/null || uptime');
          {$ENDIF}
          Proc.Options := [poUsePipes, poNoConsole, poStderrToOutput];
          Proc.ShowWindow := swoHIDE;
          Proc.Execute;

          OutStream := TStringStream.Create('');
          try
            OutStream.CopyFrom(Proc.Output, 0);
            ProcOutput := Trim(Copy(OutStream.DataString, 1, 100));
            if ProcOutput <> '' then
              Context := Context + 'System uptime: ' + ProcOutput + ' hours. ';
          finally
            OutStream.Free;
          end;
        finally
          Proc.Free;
        end;

        // Current working directory (where BonziClaude was launched from)
        Context := Context + 'CWD: ' + GetCurrentDir + '. ';
      end;
    except
    end;
  end;

  Context := Context + 'Make a brief, in-character ambient observation. Be gentle and natural. Do not repeat yourself.';
  Result := Context;
end;

procedure TFormMain.OnAmbientTimer(Sender: TObject);
begin
  if FChatting then Exit;  // don't interrupt chat
  if FConfig.PrivacyMode = 0 then Exit;
  if (Now - FLastApiCall) * 86400 < 120 then Exit;
  if not Visible then Exit;

  SendToApi(BuildAmbientContext, 'turn', False);
end;

procedure TFormMain.OnInitBubble(Sender: TObject);
begin
  FInitBubbleTimer.Enabled := False;

  if FInitBubbleTimer.Tag = 0 then
  begin
    FInitBubbleTimer.Tag := 1;
    if (FCreds.AccessToken = '') or (FConfig.OrgUuid = '') then
      ShowBubble('Right-click to configure.')
    else
    begin
      // Send a proper greeting via the API with context
      SendToApi(
        FConfig.Name + ' just appeared on the user''s desktop as a companion app called BonziClaude. ' +
        'This is the first moment of the session. Say hello and introduce yourself briefly, in character.',
        'hatch', True);
    end;
    // Reposition after showing
    FInitBubbleTimer.Interval := 300;
    FInitBubbleTimer.Enabled := True;
  end
  else
  begin
    PositionBubble;
    FInitBubbleTimer.Free;
    FInitBubbleTimer := nil;
  end;
end;

// ============================================================
//  User interaction
// ============================================================

procedure TFormMain.OnChatClick(Sender: TObject);
var
  ChatForm: TForm;
  Memo: TMemo;
  BtnSend, BtnCancel: TButton;
  BtnPanel: TPanel;
  InputText: string;
  Pt: TPoint;
begin
  // Create a chat input form positioned where the bubble would be
  ChatForm := TForm.CreateNew(Self);
  try
    ChatForm.BorderStyle := bsNone;
    ChatForm.FormStyle := fsStayOnTop;
    ChatForm.Color := $00101010;
    ChatForm.Width := Self.Width;
    ChatForm.Height := 120;
    ChatForm.DoubleBuffered := True;

    // Position above the companion (same as bubble)
    Pt := ClientToScreen(Point(ClientWidth, 0));
    ChatForm.Left := Pt.X - ChatForm.Width;
    ChatForm.Top := Pt.Y - ChatForm.Height;

    // Text input area
    Memo := TMemo.Create(ChatForm);
    Memo.Parent := ChatForm;
    Memo.Align := alClient;
    Memo.Font.Name := FBubbleFont.Name;
    Memo.Font.Size := 10;
    Memo.Font.Color := FThemeColor;
    Memo.Color := $00101010;
    Memo.ScrollBars := ssVertical;
    Memo.WordWrap := True;
    {$IFDEF WINDOWS}
    Memo.Font.Quality := fqClearType;
    {$ENDIF}

    // Button panel at bottom
    BtnPanel := TPanel.Create(ChatForm);
    BtnPanel.Parent := ChatForm;
    BtnPanel.Align := alBottom;
    BtnPanel.Height := 28;
    BtnPanel.BevelOuter := bvNone;
    BtnPanel.Color := $00101010;

    BtnSend := TButton.Create(ChatForm);
    BtnSend.Parent := BtnPanel;
    BtnSend.Align := alRight;
    BtnSend.Width := 60;
    BtnSend.Caption := 'Send';
    BtnSend.ModalResult := mrOK;
    BtnSend.Default := True;

    BtnCancel := TButton.Create(ChatForm);
    BtnCancel.Parent := BtnPanel;
    BtnCancel.Align := alLeft;
    BtnCancel.Width := 60;
    BtnCancel.Caption := 'Close';
    BtnCancel.ModalResult := mrCancel;
    BtnCancel.Cancel := True;

    FChatting := True;
    ChatForm.ActiveControl := Memo;

    if ChatForm.ShowModal = mrOK then
    begin
      InputText := Trim(Memo.Text);
      if InputText <> '' then
      begin
        // Built-in commands
        if (LowerCase(InputText) = 'exit') or (LowerCase(InputText) = 'quit') then
        begin
          SaveState;
          Application.Terminate;
          Exit;
        end;
        if LowerCase(InputText) = 'hide' then
        begin
          OnMenuMinimize(nil);
          Exit;
        end;
        if (LowerCase(InputText) = 'login') or (LowerCase(InputText) = 'config') then
        begin
          OnMenuConfig(nil);
          Exit;
        end;
        SendToApi(InputText, 'turn', True);
      end;
    end;
  finally
    FChatting := False;
    ChatForm.Free;
  end;
end;

procedure TFormMain.OnPetClick(Sender: TObject);
begin
  FIsPetting := True;
  FPetFrame := 0;
  FPetTimer.Enabled := True;
  Invalidate;
  SendToApi('User just petted ' + FConfig.Name + '. React warmly.', 'turn', True);
end;

procedure TFormMain.OnMenuConfig(Sender: TObject);
var
  ConfigForm: TFormConfig;
  I: Integer;
begin
  ConfigForm := TFormConfig.Create(Self);
  try
    ConfigForm.Config := FConfig;

    if ConfigForm.ShowConfigDialog then
    begin
      FConfig := ConfigForm.Config;
      FSpeciesIdx := GetSpeciesIndex(FConfig.Species);
      if FSpeciesIdx < 0 then FSpeciesIdx := 15;
      I := GetRarityIndex(FConfig.Rarity);
      if (I >= 0) and (I < RARITY_COUNT) then
        FThemeColor := RarityTColors[I]
      else
        FThemeColor := DEFAULT_TEXT;
      SaveConfig(GetConfigPath, FConfig);
      FChatButton.Hint := 'Chat with ' + FConfig.Name;
      ComputeLayout;
      FChatButton.Top := FInputY;
      FPetButton.Top := FInputY;
      FPetButton.Left := FChatButton.Left + FChatButton.Width + 8;
      Invalidate;
    end;

    // ALWAYS reload credentials after config dialog closes
    // (user might have logged in, whether they clicked OK or Cancel)
    FCreds := LoadCredentials(GetCredentialsPath);
    if FCreds.AccessToken = '' then
      ImportClaudeCodeCredentials(FCreds);
  finally
    ConfigForm.Free;
  end;
end;

procedure TFormMain.OnFileDrop(Sender: TObject; const FileNames: array of string);
var
  FS: TFileStream;
  Content, Clean: string;
  Buf: array[0..4095] of Byte;
  BytesRead, I: Integer;
  FileSize: Int64;
begin
  if Length(FileNames) = 0 then Exit;
  try
    FS := TFileStream.Create(FileNames[0], fmOpenRead or fmShareDenyNone);
    try
      FileSize := FS.Size;
      // Read last 4KB — leaves room for filename prefix + chat history in the 5K transcript
      if FileSize > 4000 then
        FS.Seek(-4000, soEnd)
      else
        FS.Seek(0, soBeginning);
      BytesRead := FS.Read(Buf, 4000);
      SetString(Content, PAnsiChar(@Buf[0]), BytesRead);
    finally
      FS.Free;
    end;

    // Aggressively sanitize for JSON safety:
    // Only keep printable ASCII + newline/tab. Strip everything else.
    Clean := '';
    for I := 1 to Length(Content) do
    begin
      case Content[I] of
        #9, #10, #13: Clean := Clean + Content[I];
        #32..#126: Clean := Clean + Content[I];
      else
        // skip non-ASCII / control chars entirely
      end;
    end;
    Content := Clean;

    // Start reading animation (binary digits)
    FIsReading := True;
    FPetFrame := 0;
    FPetTimer.Enabled := True;
    Invalidate;

    ShowBubble('Reading ' + ExtractFileName(FileNames[0]) + '...');
    Application.ProcessMessages;
    SendToApi('File "' + ExtractFileName(FileNames[0]) + '" (' +
      IntToStr(FileSize) + ' bytes, showing last ' + IntToStr(BytesRead) + '):'#10 +
      Content, 'turn', True);
  except
    on E: Exception do
      ShowBubble('Could not read file: ' + E.Message);
  end;
end;

procedure TFormMain.OnMenuReadFile(Sender: TObject);
var
  Dlg: TOpenDialog;
  Names: array of string;
begin
  Dlg := TOpenDialog.Create(Self);
  try
    Dlg.Title := 'Pick a file for ' + FConfig.Name + ' to read';
    Dlg.Filter := 'All files|*.*|Text files|*.txt;*.md;*.log;*.json;*.py;*.pas;*.js;*.ts';
    if Dlg.Execute then
    begin
      SetLength(Names, 1);
      Names[0] := Dlg.FileName;
      OnFileDrop(Self, Names);
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TFormMain.OnMenuBubbleAnchor(Sender: TObject);
begin
  FBubbleAnchor := TMenuItem(Sender).Tag;
  FBubbleTopItem.Checked := FBubbleAnchor = 0;
  FBubbleLeftItem.Checked := FBubbleAnchor = 1;
  FBubbleRightItem.Checked := FBubbleAnchor = 2;
  PositionBubble;
end;

procedure TFormMain.OnMenuHistory(Sender: TObject);
var
  Dlg: TForm;
  Memo: TMemo;
begin
  Dlg := TForm.CreateNew(Self);
  try
    Dlg.Caption := FConfig.Name + ' - History';
    Dlg.Width := 420;
    Dlg.Height := 400;
    Dlg.Position := poScreenCenter;
    Dlg.BorderStyle := bsSizeable;
    Dlg.Color := $00101010;

    Memo := TMemo.Create(Dlg);
    Memo.Parent := Dlg;
    Memo.Align := alClient;
    Memo.ReadOnly := True;
    Memo.ScrollBars := ssVertical;
    Memo.Font.Name := FBubbleFont.Name;
    Memo.Font.Size := 10;
    Memo.Font.Color := $0000DD00;
    Memo.Color := $00101010;
    Memo.Lines.Assign(FHistory);

    Dlg.ShowModal;
  finally
    Dlg.Free;
  end;
end;

procedure TFormMain.OnMenuAlwaysFront(Sender: TObject);
var
  OldLeft, OldTop: Integer;
begin
  FAlwaysFront := not FAlwaysFront;
  FAlwaysFrontItem.Checked := FAlwaysFront;

  OldLeft := Left;
  OldTop := Top;

  // On Win32, FormStyle change requires recreating the window.
  // Hide, change, show to force the WM to apply WS_EX_TOPMOST.
  Hide;
  if FAlwaysFront then
    FormStyle := fsStayOnTop
  else
    FormStyle := fsNormal;
  Application.ProcessMessages;
  Left := OldLeft;
  Top := OldTop;
  Show;
  if FAlwaysFront then
    BringToFront;
end;

procedure TFormMain.OnMenuMinimize(Sender: TObject);
begin
  // Hide to tray instead of taskbar minimize
  Hide;
  if (FBubbleForm <> nil) and FBubbleForm.Visible then
    FBubbleForm.Hide;
end;

procedure TFormMain.OnTrayClick(Sender: TObject);
begin
  if Visible then
  begin
    Hide;
    if (FBubbleForm <> nil) and FBubbleForm.Visible then
      FBubbleForm.Hide;
  end
  else
  begin
    Show;
    WindowState := wsNormal;
    BringToFront;
  end;
end;

procedure TFormMain.OnMenuQuit(Sender: TObject);
begin
  SaveState;
  Application.Terminate;
end;

// ============================================================
//  API
// ============================================================

function TFormMain.EnsureToken: string;
var
  FreshCreds: TCredentials;
begin
  // 1. Check BonziClaude's own credentials (from our login flow)
  FreshCreds := LoadCredentials(GetCredentialsPath);
  if (FreshCreds.AccessToken <> '') and (not IsTokenExpired(FreshCreds)) then
  begin
    FCreds := FreshCreds;
    Result := FCreds.AccessToken;
    Exit;
  end;

  // 2. Read from Claude Code's credentials (read-only, never write)
  if ImportClaudeCodeCredentials(FreshCreds) and (not IsTokenExpired(FreshCreds)) then
  begin
    FCreds := FreshCreds;
    Result := FCreds.AccessToken;
    Exit;
  end;

  // 3. Return whatever we have (might be expired — 401 handler will deal with it)
  Result := FCreds.AccessToken;
end;

function TFormMain.BuildStatsJSON: string;
begin
  Result := Format('{"DEBUGGING":%d,"PATIENCE":%d,"CHAOS":%d,"WISDOM":%d,"SNARK":%d}',
    [FConfig.Debugging, FConfig.Patience, FConfig.Chaos, FConfig.Wisdom, FConfig.Snark]);
end;

procedure TFormMain.AddRecent(const AText: string);
var
  Len, I: Integer;
begin
  Len := Length(FRecent);
  if Len >= MAX_RECENT_COUNT then
  begin
    for I := 0 to Len - 2 do
      FRecent[I] := FRecent[I + 1];
    FRecent[MAX_RECENT_COUNT - 1] := ValidateRecentEntry(AText);
  end
  else
  begin
    SetLength(FRecent, Len + 1);
    FRecent[Len] := ValidateRecentEntry(AText);
  end;
end;

procedure TFormMain.AddToChatLog(const ARole, AText: string);
var
  TotalLen, I: Integer;
begin
  FChatLog.Add(ARole + ': ' + AText);
  // Trim chat log to stay under ~3000 chars (leaving room for the new message in the 5k transcript)
  TotalLen := 0;
  for I := 0 to FChatLog.Count - 1 do
    TotalLen := TotalLen + Length(FChatLog[I]) + 1;
  while (TotalLen > 3000) and (FChatLog.Count > 2) do
  begin
    TotalLen := TotalLen - Length(FChatLog[0]) - 1;
    FChatLog.Delete(0);
  end;
end;

function TFormMain.BuildTranscriptWithHistory(const ANewMessage: string): string;
var
  I: Integer;
  History: string;
begin
  if FChatLog.Count > 0 then
  begin
    History := 'Recent conversation:' + #10;
    for I := 0 to FChatLog.Count - 1 do
      History := History + FChatLog[I] + #10;
    History := History + #10 + 'Current: ' + ANewMessage;
    Result := History;
  end
  else
    Result := ANewMessage;

  // Hard cap to transcript limit
  if Length(Result) > 5000 then
    Result := Copy(Result, Length(Result) - 4999, 5000);
end;

procedure TFormMain.SendToApi(const ATranscript, AReason: string; AAddressed: Boolean);
var
  Params: TBuddyReactParams;
  Token: string;
  I: Integer;
begin
  Token := EnsureToken;
  if (Token = '') or (FConfig.OrgUuid = '') then
  begin
    ShowBubble('Not logged in');
    Exit;
  end;

  // Log user message to chat history (for addressed/direct messages)
  if AAddressed then
    AddToChatLog('User', ATranscript);

  Params.Name := FConfig.Name;
  Params.Personality := FConfig.Personality;
  Params.Species := FConfig.Species;
  Params.Rarity := FConfig.Rarity;
  Params.Stats := BuildStatsJSON;
  // Include chat history for direct conversations
  if AAddressed then
    Params.Transcript := BuildTranscriptWithHistory(ATranscript)
  else
    Params.Transcript := ATranscript;
  Params.Reason := AReason;
  Params.Addressed := AAddressed;
  SetLength(Params.Recent, Length(FRecent));
  for I := 0 to High(FRecent) do
    Params.Recent[I] := FRecent[I];

  FLastApiCall := Now;
  FIdleTimer.Enabled := False;
  FIdleTimer.Enabled := FConfig.IdleReactMinutes > 0;

  // Fire async — callback handles the result on the main thread
  TBuddyReactThread.Create(Params, Token, FConfig.OrgUuid, @OnApiResult);
end;

procedure TFormMain.OnApiResult(const AResult: TBuddyReactResult);
var
  FreshCreds: TCredentials;
  NewToken: string;
begin
  // Silently drop responses while user is chatting
  if FChatting then Exit;

  if AResult.HttpStatus = 401 then
  begin
    // 1. Try refreshing the token
    if FCreds.RefreshToken <> '' then
    begin
      NewToken := RefreshAccessToken(FCreds.RefreshToken);
      if NewToken <> '' then
      begin
        FCreds.AccessToken := NewToken;
        FCreds.ExpiresAt := CurrentTimeMillis + 28800000;
        SaveCredentials(GetCredentialsPath, FCreds);
        ShowBubble('Token refreshed. Try again.');
        Exit;
      end;
    end;

    // 2. Re-read credentials from disk (Claude Code may have refreshed)
    FreshCreds := LoadCredentials(GetCredentialsPath);
    if (FreshCreds.AccessToken <> '') and (FreshCreds.AccessToken <> FCreds.AccessToken) then
    begin
      FCreds := FreshCreds;
      ShowBubble('Found updated credentials. Try again.');
      Exit;
    end;

    // 3. All failed — tell the user how to fix it
    ShowBubble('Auth expired. Type "login" or right-click > Configure.');
    Exit;
  end;

  if AResult.Success and (AResult.Reaction <> '') then
  begin
    ShowBubble(AResult.Reaction);
    AddRecent(AResult.Reaction);
    AddToChatLog(FConfig.Name, AResult.Reaction);
  end
  else if AResult.ErrorMsg <> '' then
    ShowBubble(AResult.ErrorMsg)
  else
    ShowBubble('(no response)');
end;

procedure TFormMain.ShowBubble(const AText: string);
var
  CleanText: string;
  Paragraphs: TStringList;
  Words: TStringList;
  CurLine, TestLine, Wrd: string;
  I, J, MaxW, TextH: Integer;
begin
  FBubbleText := AText;
  FBubbleTimer.Enabled := False;
  FBubbleTimer.Enabled := True;

  if (AText <> '...') and (AText <> '') then
    FHistory.Add(FormatDateTime('hh:nn:ss', Now) + '  ' + AText);

  if FBubbleForm = nil then
  begin
    // Create bubble form ONCE at a FIXED size that can hold max API output (~350 chars).
    // This eliminates all resize/reposition drift.
    FBubbleForm := TForm.CreateNew(Self);
    FBubbleForm.BorderStyle := bsNone;
    FBubbleForm.FormStyle := fsStayOnTop;
    FBubbleForm.Color := FORM_BG;
    FBubbleForm.DoubleBuffered := True;
    FBubbleForm.ShowInTaskBar := stNever;
    FBubbleForm.OnPaint := @PaintBubble;

    // Fixed size: same width as main form, tall enough for ~10 lines + connector
    FBubbleForm.Canvas.Font.Assign(FBubbleFont);
    TextH := FBubbleForm.Canvas.TextHeight('Mg');
    FBubbleForm.Width := Self.Width;
    FBubbleForm.Height := 12 * TextH + BUBBLE_PAD * 2 + 4 + FCharH;
  end;

  // Word-wrap text into the fixed bubble width
  FBubbleLines.Clear;
  FBubbleForm.Canvas.Font.Assign(FBubbleFont);
  MaxW := FBubbleForm.Width - BUBBLE_PAD * 2 - 8;
  if MaxW < 50 then MaxW := 50;

  CleanText := StringReplace(AText, #13#10, #10, [rfReplaceAll]);
  CleanText := StringReplace(CleanText, #13, #10, [rfReplaceAll]);
  Paragraphs := TStringList.Create;
  try
    Paragraphs.Delimiter := #10;
    Paragraphs.StrictDelimiter := True;
    Paragraphs.DelimitedText := CleanText;

    for J := 0 to Paragraphs.Count - 1 do
    begin
      if Trim(Paragraphs[J]) = '' then
      begin
        FBubbleLines.Add('');
        Continue;
      end;

      Words := TStringList.Create;
      try
        Words.Delimiter := ' ';
        Words.StrictDelimiter := True;
        Words.DelimitedText := Paragraphs[J];

        CurLine := '';
        for I := 0 to Words.Count - 1 do
        begin
          Wrd := Words[I];
          if CurLine = '' then
            TestLine := Wrd
          else
            TestLine := CurLine + ' ' + Wrd;

          if FBubbleForm.Canvas.TextWidth(TestLine) > MaxW then
          begin
            if CurLine <> '' then
              FBubbleLines.Add(CurLine);
            CurLine := Wrd;
          end
          else
            CurLine := TestLine;
        end;
        if CurLine <> '' then
          FBubbleLines.Add(CurLine);
      finally
        Words.Free;
      end;
    end;
  finally
    Paragraphs.Free;
  end;

  while FBubbleLines.Count > 12 do
    FBubbleLines.Delete(FBubbleLines.Count - 1);

  // Position and show — position every time to apply current anchor
  PositionBubble;
  if not FBubbleForm.Visible then
    FBubbleForm.Show;
  FBubbleForm.Invalidate;
end;

end.
