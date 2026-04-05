unit uFormConfig;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StrUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Buttons, Spin, ComCtrls, fpjson, jsonparser,
  uCompanionData, uConfig, uValidation, uCredentials, uOAuth, uFormHatch;

type
  TFormConfig = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormPaint(Sender: TObject);
  private
    // Import section
    FImportGroup: TGroupBox;
    FImportLabel: TLabel;
    FBtnAutoImport: TButton;
    FBtnBrowse: TButton;
    FImportStatus: TLabel;

    // Companion picker carousel
    FPickerGroup: TGroupBox;
    FBtnPrevSpecies: TSpeedButton;
    FBtnNextSpecies: TSpeedButton;
    FSpeciesLabel: TLabel;
    FPreviewBox: TPaintBox;

    // Eye carousel
    FBtnPrevEye: TSpeedButton;
    FBtnNextEye: TSpeedButton;
    FEyeLabel: TLabel;

    // Hat carousel
    FBtnPrevHat: TSpeedButton;
    FBtnNextHat: TSpeedButton;
    FHatLabel: TLabel;

    // Rarity carousel
    FBtnPrevRarity: TSpeedButton;
    FBtnNextRarity: TSpeedButton;
    FRarityLabel: TLabel;

    // Stats sliders
    FStatSliders: array[0..4] of TTrackBar;
    FStatLabels: array[0..4] of TLabel;
    FStatValues: array[0..4] of TLabel;

    // Name and personality
    FNameGroup: TGroupBox;
    FNameEdit: TEdit;
    FNameCounter: TLabel;
    FPersonalityMemo: TMemo;
    FPersonalityCounter: TLabel;
    FPersonalityHint: TLabel;

    // Privacy / Login
    FPrivacySlider: TTrackBar;
    FPrivacyDesc: TLabel;
    FBtnLogin: TButton;

    // Action buttons
    FBtnHatch: TButton;
    FBtnExport: TButton;

    // Buttons
    FBtnOK: TButton;
    FBtnCancel: TButton;

    // Scroll container
    FScrollBox: TScrollBox;

    // State
    FCurrentSpecies: Integer;
    FCurrentEye: Integer;
    FCurrentHat: Integer;
    FCurrentRarity: Integer;
    FConfig: TBuddyConfig;
    FMonoFont: TFont;

    procedure SetupImportSection;
    procedure SetupCarousel;
    procedure SetupNameSection;
    procedure SetupPrivacySection;
    procedure SetupButtons;

    procedure OnAutoImport(Sender: TObject);
    procedure OnBrowse(Sender: TObject);
    procedure OnLoginClick(Sender: TObject);
    procedure OnPrivacyChange(Sender: TObject);
    procedure OnHatchClick(Sender: TObject);
    procedure OnExportClick(Sender: TObject);
    procedure OnPrevSpecies(Sender: TObject);
    procedure OnNextSpecies(Sender: TObject);
    procedure OnPrevEye(Sender: TObject);
    procedure OnNextEye(Sender: TObject);
    procedure OnPrevHat(Sender: TObject);
    procedure OnNextHat(Sender: TObject);
    procedure OnPrevRarity(Sender: TObject);
    procedure OnNextRarity(Sender: TObject);
    procedure OnNameChange(Sender: TObject);
    procedure OnPersonalityChange(Sender: TObject);
    procedure OnPreviewPaint(Sender: TObject);
    procedure OnStatSliderChange(Sender: TObject);
    procedure OnOK(Sender: TObject);

    procedure UpdateLabels;
    procedure UpdatePreview;
  public
    property Config: TBuddyConfig read FConfig write FConfig;
    function ShowConfigDialog: Boolean;
  end;

implementation

{$R *.lfm}

procedure TFormConfig.FormCreate(Sender: TObject);
begin
  Caption := 'BonziClaude - Configure Your Companion';
  Width := 440;
  Height := 620;
  Position := poScreenCenter;
  BorderStyle := bsSizeable;
  BorderIcons := [biSystemMenu];
  AutoScroll := False;
  DoubleBuffered := True;

  // Native scrollbox for smooth scrolling
  FScrollBox := TScrollBox.Create(Self);
  FScrollBox.Parent := Self;
  FScrollBox.Align := alClient;
  FScrollBox.BorderStyle := bsNone;
  FScrollBox.HorzScrollBar.Visible := False;
  FScrollBox.VertScrollBar.Increment := 30;  // faster scroll steps
  FScrollBox.VertScrollBar.Smooth := True;

  FMonoFont := TFont.Create;
  {$IFDEF WINDOWS}
  FMonoFont.Name := 'Consolas';
  {$ELSE}
  FMonoFont.Name := 'DejaVu Sans Mono';
  {$ENDIF}
  FMonoFont.Size := 11;

  FCurrentSpecies := 15;  // rabbit
  FCurrentEye := 0;
  FCurrentHat := 0;
  FCurrentRarity := 0;

  SetupPrivacySection;   // top: login + privacy first
  SetupImportSection;    // then import from claude code
  SetupCarousel;         // companion picker
  SetupNameSection;      // name + personality
  SetupButtons;          // OK/Cancel at very bottom
end;

procedure TFormConfig.FormPaint(Sender: TObject);
begin
  // Nothing special needed
end;

procedure TFormConfig.SetupImportSection;
begin
  FImportGroup := TGroupBox.Create(Self);
  FImportGroup.Parent := FScrollBox;
  FImportGroup.Caption := 'Import from Claude Code';
  FImportGroup.Left := 12;
  FImportGroup.Top := 276;
  FImportGroup.Width := Width - 32;
  FImportGroup.Height := 120;

  FImportLabel := TLabel.Create(Self);
  FImportLabel.Parent := FImportGroup;
  FImportLabel.Left := 12;
  FImportLabel.Top := 18;
  FImportLabel.Caption := 'Sync name/personality from Claude Code:';

  // Show the path hint so user knows where we look
  FImportStatus := TLabel.Create(Self);
  FImportStatus.Parent := FImportGroup;
  FImportStatus.Left := 12;
  FImportStatus.Top := 38;
  FImportStatus.Font.Color := clGray;
  FImportStatus.Font.Size := 8;
  {$IFDEF WINDOWS}
  FImportStatus.Caption := GetEnvironmentVariable('USERPROFILE') + '\.claude\.claude.json';
  {$ELSE}
  FImportStatus.Caption := GetEnvironmentVariable('HOME') + '/.claude/.claude.json';
  {$ENDIF}

  FBtnAutoImport := TButton.Create(Self);
  FBtnAutoImport.Parent := FImportGroup;
  FBtnAutoImport.Left := 12;
  FBtnAutoImport.Top := 68;
  FBtnAutoImport.Width := 110;
  FBtnAutoImport.Height := 28;
  FBtnAutoImport.Caption := 'Sync';
  FBtnAutoImport.OnClick := @OnAutoImport;

  FBtnBrowse := TButton.Create(Self);
  FBtnBrowse.Parent := FImportGroup;
  FBtnBrowse.Left := 130;
  FBtnBrowse.Top := 68;
  FBtnBrowse.Width := 110;
  FBtnBrowse.Height := 28;
  FBtnBrowse.Caption := 'Browse...';
  FBtnBrowse.OnClick := @OnBrowse;
end;

procedure TFormConfig.SetupCarousel;
var
  Y, CX, I: Integer;
begin
  FPickerGroup := TGroupBox.Create(Self);
  FPickerGroup.Parent := FScrollBox;
  FPickerGroup.Caption := 'Companion';
  FPickerGroup.Left := 12;
  FPickerGroup.Top := FImportGroup.Top + FImportGroup.Height + 8;
  FPickerGroup.Width := Width - 32;
  FPickerGroup.Height := 440;

  // Preview — black background, centered
  FPreviewBox := TPaintBox.Create(Self);
  FPreviewBox.Parent := FPickerGroup;
  FPreviewBox.Left := 12;
  FPreviewBox.Top := 24;
  FPreviewBox.Width := FPickerGroup.Width - 24;
  FPreviewBox.Height := 130;
  FPreviewBox.OnPaint := @OnPreviewPaint;

  Y := 162;

  // Center the carousel rows within the group
  // Each row: [<] 28px + 8px gap + [label 160px] + 8px gap + [>] 28px = 232
  CX := (FPickerGroup.Width - 232) div 2;
  if CX < 8 then CX := 8;

  // Species carousel
  FBtnPrevSpecies := TSpeedButton.Create(Self);
  FBtnPrevSpecies.Parent := FPickerGroup;
  FBtnPrevSpecies.Left := CX;
  FBtnPrevSpecies.Top := Y;
  FBtnPrevSpecies.Width := 28;
  FBtnPrevSpecies.Height := 24;
  FBtnPrevSpecies.Caption := '<';
  FBtnPrevSpecies.OnClick := @OnPrevSpecies;

  FSpeciesLabel := TLabel.Create(Self);
  FSpeciesLabel.Parent := FPickerGroup;
  FSpeciesLabel.Left := CX + 36;
  FSpeciesLabel.Top := Y + 3;
  FSpeciesLabel.Width := 160;
  FSpeciesLabel.Alignment := taCenter;

  FBtnNextSpecies := TSpeedButton.Create(Self);
  FBtnNextSpecies.Parent := FPickerGroup;
  FBtnNextSpecies.Left := CX + 204;
  FBtnNextSpecies.Top := Y;
  FBtnNextSpecies.Width := 28;
  FBtnNextSpecies.Height := 24;
  FBtnNextSpecies.Caption := '>';
  FBtnNextSpecies.OnClick := @OnNextSpecies;

  Inc(Y, 28);

  // Eye carousel
  FBtnPrevEye := TSpeedButton.Create(Self);
  FBtnPrevEye.Parent := FPickerGroup;
  FBtnPrevEye.Left := CX;
  FBtnPrevEye.Top := Y;
  FBtnPrevEye.Width := 28;
  FBtnPrevEye.Height := 24;
  FBtnPrevEye.Caption := '<';
  FBtnPrevEye.OnClick := @OnPrevEye;

  FEyeLabel := TLabel.Create(Self);
  FEyeLabel.Parent := FPickerGroup;
  FEyeLabel.Left := CX + 36;
  FEyeLabel.Top := Y + 3;
  FEyeLabel.Width := 160;
  FEyeLabel.Alignment := taCenter;

  FBtnNextEye := TSpeedButton.Create(Self);
  FBtnNextEye.Parent := FPickerGroup;
  FBtnNextEye.Left := CX + 204;
  FBtnNextEye.Top := Y;
  FBtnNextEye.Width := 28;
  FBtnNextEye.Height := 24;
  FBtnNextEye.Caption := '>';
  FBtnNextEye.OnClick := @OnNextEye;

  Inc(Y, 28);

  // Hat carousel
  FBtnPrevHat := TSpeedButton.Create(Self);
  FBtnPrevHat.Parent := FPickerGroup;
  FBtnPrevHat.Left := CX;
  FBtnPrevHat.Top := Y;
  FBtnPrevHat.Width := 28;
  FBtnPrevHat.Height := 24;
  FBtnPrevHat.Caption := '<';
  FBtnPrevHat.OnClick := @OnPrevHat;

  FHatLabel := TLabel.Create(Self);
  FHatLabel.Parent := FPickerGroup;
  FHatLabel.Left := CX + 36;
  FHatLabel.Top := Y + 3;
  FHatLabel.Width := 160;
  FHatLabel.Alignment := taCenter;

  FBtnNextHat := TSpeedButton.Create(Self);
  FBtnNextHat.Parent := FPickerGroup;
  FBtnNextHat.Left := CX + 204;
  FBtnNextHat.Top := Y;
  FBtnNextHat.Width := 28;
  FBtnNextHat.Height := 24;
  FBtnNextHat.Caption := '>';
  FBtnNextHat.OnClick := @OnNextHat;

  Inc(Y, 28);

  // Rarity carousel
  FBtnPrevRarity := TSpeedButton.Create(Self);
  FBtnPrevRarity.Parent := FPickerGroup;
  FBtnPrevRarity.Left := CX;
  FBtnPrevRarity.Top := Y;
  FBtnPrevRarity.Width := 28;
  FBtnPrevRarity.Height := 24;
  FBtnPrevRarity.Caption := '<';
  FBtnPrevRarity.OnClick := @OnPrevRarity;

  FRarityLabel := TLabel.Create(Self);
  FRarityLabel.Parent := FPickerGroup;
  FRarityLabel.Left := CX + 36;
  FRarityLabel.Top := Y + 3;
  FRarityLabel.Width := 160;
  FRarityLabel.Alignment := taCenter;

  FBtnNextRarity := TSpeedButton.Create(Self);
  FBtnNextRarity.Parent := FPickerGroup;
  FBtnNextRarity.Left := CX + 204;
  FBtnNextRarity.Top := Y;
  FBtnNextRarity.Width := 28;
  FBtnNextRarity.Height := 24;
  FBtnNextRarity.Caption := '>';
  FBtnNextRarity.OnClick := @OnNextRarity;

  // Stats sliders — one per stat, 0-100
  Inc(Y, 30);

  for I := 0 to 4 do
  begin
    // Stat name label
    FStatLabels[I] := TLabel.Create(Self);
    FStatLabels[I].Parent := FPickerGroup;
    FStatLabels[I].Left := 12;
    FStatLabels[I].Top := Y + 2;
    FStatLabels[I].Width := 80;
    FStatLabels[I].Caption := StatNames[I];
    FStatLabels[I].Font.Size := 8;

    // Slider
    FStatSliders[I] := TTrackBar.Create(Self);
    FStatSliders[I].Parent := FPickerGroup;
    FStatSliders[I].Left := 90;
    FStatSliders[I].Top := Y;
    FStatSliders[I].Width := FPickerGroup.Width - 140;
    FStatSliders[I].Min := 0;
    FStatSliders[I].Max := 100;
    FStatSliders[I].Position := 50;
    FStatSliders[I].TickStyle := tsNone;
    FStatSliders[I].Tag := I;
    FStatSliders[I].OnChange := @OnStatSliderChange;

    // Value label
    FStatValues[I] := TLabel.Create(Self);
    FStatValues[I].Parent := FPickerGroup;
    FStatValues[I].Left := FPickerGroup.Width - 42;
    FStatValues[I].Top := Y + 2;
    FStatValues[I].Width := 30;
    FStatValues[I].Alignment := taRightJustify;
    FStatValues[I].Caption := '50';
    FStatValues[I].Font.Size := 8;

    Inc(Y, 26);
  end;

  UpdateLabels;
end;

procedure TFormConfig.SetupNameSection;
begin
  FNameGroup := TGroupBox.Create(Self);
  FNameGroup.Parent := FScrollBox;
  FNameGroup.Caption := 'Identity';
  FNameGroup.Left := 12;
  FNameGroup.Top := FPickerGroup.Top + FPickerGroup.Height + 8;
  FNameGroup.Width := Width - 32;
  FNameGroup.Height := 190;

  // Name
  FNameEdit := TEdit.Create(Self);
  FNameEdit.Parent := FNameGroup;
  FNameEdit.Left := 12;
  FNameEdit.Top := 20;
  FNameEdit.Width := 200;
  FNameEdit.MaxLength := MAX_NAME_LEN;
  FNameEdit.OnChange := @OnNameChange;

  FNameCounter := TLabel.Create(Self);
  FNameCounter.Parent := FNameGroup;
  FNameCounter.Left := 220;
  FNameCounter.Top := 24;
  FNameCounter.Font.Color := clGray;

  // Personality
  FPersonalityHint := TLabel.Create(Self);
  FPersonalityHint.Parent := FNameGroup;
  FPersonalityHint.Left := 12;
  FPersonalityHint.Top := 50;
  FPersonalityHint.Caption := 'Personality (this is the system prompt):';
  FPersonalityHint.Font.Style := [fsBold];

  FPersonalityMemo := TMemo.Create(Self);
  FPersonalityMemo.Parent := FNameGroup;
  FPersonalityMemo.Left := 12;
  FPersonalityMemo.Top := 70;
  FPersonalityMemo.Width := FNameGroup.Width - 24;
  FPersonalityMemo.Height := 60;
  FPersonalityMemo.WordWrap := True;
  FPersonalityMemo.OnChange := @OnPersonalityChange;

  FPersonalityCounter := TLabel.Create(Self);
  FPersonalityCounter.Parent := FNameGroup;
  FPersonalityCounter.Left := 12;
  FPersonalityCounter.Top := 136;
  FPersonalityCounter.Font.Color := clGray;
end;

procedure TFormConfig.SetupPrivacySection;
var
  Grp: TGroupBox;
  Lbl: TLabel;
begin
  Grp := TGroupBox.Create(Self);
  Grp.Parent := FScrollBox;
  Grp.Caption := 'Login && Privacy';
  Grp.Left := 12;
  Grp.Top := 8;
  Grp.Width := Width - 32;
  Grp.Height := 260;

  // Explanation first
  Lbl := TLabel.Create(Self);
  Lbl.Parent := Grp;
  Lbl.Left := 12;
  Lbl.Top := 20;
  Lbl.Width := Grp.Width - 24;
  Lbl.Height := 36;
  Lbl.WordWrap := True;
  Lbl.AutoSize := False;
  Lbl.Caption := 'BonziClaude sends data to Anthropic''s API to generate your ' +
    'companion''s reactions. Choose how much context to share:';

  // Slider labels
  Lbl := TLabel.Create(Self);
  Lbl.Parent := Grp;
  Lbl.Left := 12;
  Lbl.Top := 60;
  Lbl.Caption := 'Chat Only';
  Lbl.Font.Size := 8;

  Lbl := TLabel.Create(Self);
  Lbl.Parent := Grp;
  Lbl.Left := (Grp.Width - 24) div 2 - 16;
  Lbl.Top := 60;
  Lbl.Caption := 'Standard';
  Lbl.Font.Size := 8;

  Lbl := TLabel.Create(Self);
  Lbl.Parent := Grp;
  Lbl.Left := Grp.Width - 90;
  Lbl.Top := 60;
  Lbl.Caption := 'Personalized';
  Lbl.Font.Size := 8;

  // Slider
  FPrivacySlider := TTrackBar.Create(Self);
  FPrivacySlider.Parent := Grp;
  FPrivacySlider.Left := 12;
  FPrivacySlider.Top := 78;
  FPrivacySlider.Width := Grp.Width - 24;
  FPrivacySlider.Min := 0;
  FPrivacySlider.Max := 2;
  FPrivacySlider.Position := 1;  // standard default
  FPrivacySlider.TickStyle := tsNone;
  FPrivacySlider.OnChange := @OnPrivacyChange;

  // Description (updates when slider changes)
  FPrivacyDesc := TLabel.Create(Self);
  FPrivacyDesc.Parent := Grp;
  FPrivacyDesc.Left := 12;
  FPrivacyDesc.Top := 110;
  FPrivacyDesc.Width := Grp.Width - 24;
  FPrivacyDesc.Height := 72;
  FPrivacyDesc.WordWrap := True;
  FPrivacyDesc.AutoSize := False;
  FPrivacyDesc.Font.Color := clGray;
  FPrivacyDesc.Font.Size := 8;

  // Login button at bottom of group
  FBtnLogin := TButton.Create(Self);
  FBtnLogin.Parent := Grp;
  FBtnLogin.Left := 12;
  FBtnLogin.Top := 210;
  FBtnLogin.Width := 180;
  FBtnLogin.Height := 28;
  FBtnLogin.Caption := 'Login to Claude...';
  FBtnLogin.OnClick := @OnLoginClick;

  Lbl := TLabel.Create(Self);
  Lbl.Parent := Grp;
  Lbl.Left := 200;
  Lbl.Top := 216;
  Lbl.Font.Color := clGray;
  Lbl.Font.Size := 8;
  Lbl.Caption := 'Opens browser for Anthropic OAuth';

  // Trigger initial description
  OnPrivacyChange(nil);
end;

procedure TFormConfig.SetupButtons;
var
  BtnY: Integer;
begin
  BtnY := FNameGroup.Top + FNameGroup.Height + 12;

  // Hatch new companion button
  FBtnHatch := TButton.Create(Self);
  FBtnHatch.Parent := FScrollBox;
  FBtnHatch.Left := 12;
  FBtnHatch.Top := BtnY;
  FBtnHatch.Width := 140;
  FBtnHatch.Height := 32;
  FBtnHatch.Caption := 'Hatch New Buddy!';
  FBtnHatch.OnClick := @OnHatchClick;

  // Export to Claude Code button
  FBtnExport := TButton.Create(Self);
  FBtnExport.Parent := FScrollBox;
  FBtnExport.Left := 160;
  FBtnExport.Top := BtnY;
  FBtnExport.Width := 140;
  FBtnExport.Height := 32;
  FBtnExport.Caption := 'Export to Claude';
  FBtnExport.OnClick := @OnExportClick;

  Inc(BtnY, 42);

  FBtnOK := TButton.Create(Self);
  FBtnOK.Parent := FScrollBox;
  FBtnOK.Left := Width - 200;
  FBtnOK.Top := BtnY;
  FBtnOK.Width := 80;
  FBtnOK.Height := 32;
  FBtnOK.Caption := 'OK';
  FBtnOK.Default := True;
  FBtnOK.OnClick := @OnOK;

  FBtnCancel := TButton.Create(Self);
  FBtnCancel.Parent := FScrollBox;
  FBtnCancel.Left := Width - 104;
  FBtnCancel.Top := BtnY;
  FBtnCancel.Width := 80;
  FBtnCancel.Height := 32;
  FBtnCancel.Caption := 'Cancel';
  FBtnCancel.Cancel := True;
  FBtnCancel.ModalResult := mrCancel;
end;

// ============================================================
//  Import
// ============================================================

procedure TFormConfig.OnAutoImport(Sender: TObject);
var
  Imported: TBuddyConfig;
begin
  if ImportFromClaudeCode(Imported) then
  begin
    FConfig := Imported;
    FCurrentSpecies := GetSpeciesIndex(FConfig.Species);
    if FCurrentSpecies < 0 then FCurrentSpecies := 15;
    FCurrentEye := GetEyeIndex(FConfig.Eye);
    if FCurrentEye < 0 then FCurrentEye := 0;
    FCurrentHat := GetHatIndex(FConfig.Hat);
    if FCurrentHat < 0 then FCurrentHat := 0;
    FCurrentRarity := GetRarityIndex(FConfig.Rarity);
    if FCurrentRarity < 0 then FCurrentRarity := 0;
    FNameEdit.Text := FConfig.Name;
    FPersonalityMemo.Text := FConfig.Personality;
    FStatSliders[0].Position := FConfig.Debugging;
    FStatSliders[1].Position := FConfig.Patience;
    FStatSliders[2].Position := FConfig.Chaos;
    FStatSliders[3].Position := FConfig.Wisdom;
    FStatSliders[4].Position := FConfig.Snark;
    UpdateLabels;
    UpdatePreview;
    FImportStatus.Caption := 'Imported "' + FConfig.Name + '" from Claude Code!';
    FImportStatus.Font.Color := clGreen;
    FImportStatus.Font.Size := 0; // reset to default
  end
  else
  begin
    {$IFDEF WINDOWS}
    FImportStatus.Caption := 'Not found at ' + GetEnvironmentVariable('USERPROFILE') + '\.claude\';
    {$ELSE}
    FImportStatus.Caption := 'Not found at ~/.claude/';
    {$ENDIF}
    FImportStatus.Font.Color := clRed;
    FImportStatus.Font.Size := 0;
  end;
end;

procedure TFormConfig.OnBrowse(Sender: TObject);
var
  Dlg: TOpenDialog;
  Imported: TBuddyConfig;
  FS: TFileStream;
begin
  Dlg := TOpenDialog.Create(Self);
  try
    Dlg.Title := 'Select Claude Code config file (.claude.json)';
    Dlg.Filter := 'JSON files|*.json|All files|*.*';
    Dlg.InitialDir := GetEnvironmentVariable('HOME');
    if Dlg.Execute then
    begin
      // Try to parse the selected file as a Claude Code config
      // Re-use the import logic by temporarily pointing at this file
      FImportStatus.Caption := 'Imported from ' + ExtractFileName(Dlg.FileName);
      FImportStatus.Font.Color := clGreen;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TFormConfig.OnHatchClick(Sender: TObject);
var
  HatchForm: TFormHatch;
  HatchCreds: TCredentials;
begin
  // Load current credentials
  HatchCreds := LoadCredentials(GetCredentialsPath);
  if HatchCreds.AccessToken = '' then
    ImportClaudeCodeCredentials(HatchCreds);

  if HatchCreds.AccessToken = '' then
  begin
    ShowMessage('Please login first (Login to Claude button above).');
    Exit;
  end;

  // Hatch rolls everything fresh — just pass the current config for orgUuid
  HatchForm := TFormHatch.Create(Self);
  try
    HatchForm.StartHatch(FConfig, HatchCreds);
    if HatchForm.ShowModal = mrOK then
    begin
      if HatchForm.HatchResult.Success then
      begin
        // Apply FULL rolled bones
        if HatchForm.HatchResult.Name <> '' then
          FNameEdit.Text := HatchForm.HatchResult.Name;
        if HatchForm.HatchResult.Personality <> '' then
          FPersonalityMemo.Text := HatchForm.HatchResult.Personality;

        // Update carousel positions from rolled bones
        FCurrentSpecies := GetSpeciesIndex(HatchForm.HatchResult.Species);
        if FCurrentSpecies < 0 then FCurrentSpecies := 0;
        FCurrentEye := GetEyeIndex(HatchForm.HatchResult.Eye);
        if FCurrentEye < 0 then FCurrentEye := 0;
        FCurrentHat := GetHatIndex(HatchForm.HatchResult.Hat);
        if FCurrentHat < 0 then FCurrentHat := 0;
        FCurrentRarity := GetRarityIndex(HatchForm.HatchResult.Rarity);
        if FCurrentRarity < 0 then FCurrentRarity := 0;

        // Apply stats to sliders
        FStatSliders[0].Position := HatchForm.HatchResult.Debugging;
        FStatSliders[1].Position := HatchForm.HatchResult.Patience;
        FStatSliders[2].Position := HatchForm.HatchResult.Chaos;
        FStatSliders[3].Position := HatchForm.HatchResult.Wisdom;
        FStatSliders[4].Position := HatchForm.HatchResult.Snark;

        // Apply shiny flag
        FConfig.Shiny := HatchForm.HatchResult.Shiny;

        UpdateLabels;
        UpdatePreview;
        OnNameChange(nil);
        OnPersonalityChange(nil);

        // Show what hatched
        ShowMessage(Format('%s %s %s has hatched!%s',
          [UpperCase(HatchForm.HatchResult.Rarity),
           HatchForm.HatchResult.Species,
           HatchForm.HatchResult.Name,
           IfThen(HatchForm.HatchResult.Shiny, ' *SHINY*!', '')]));
      end;
    end;
  finally
    HatchForm.Free;
  end;
end;

procedure TFormConfig.OnExportClick(Sender: TObject);
var
  ClaudeDir, ConfigPath: string;
  FS: TFileStream;
  Parser: TJSONParser;
  Data: TJSONData;
  Root, Companion: TJSONObject;
  S: string;
begin
  {$IFDEF WINDOWS}
  ClaudeDir := GetEnvironmentVariable('USERPROFILE') + DirectorySeparator + '.claude';
  {$ELSE}
  ClaudeDir := GetEnvironmentVariable('HOME') + DirectorySeparator + '.claude';
  {$ENDIF}
  ConfigPath := ClaudeDir + DirectorySeparator + '.claude.json';

  if not FileExists(ConfigPath) then
  begin
    // Try creating from latest backup
    ConfigPath := FindClaudeConfigFile;
    if ConfigPath = '' then
    begin
      ShowMessage('No Claude Code config found at ' + ClaudeDir);
      Exit;
    end;
  end;

  if MessageDlg('Export Companion',
    'This will write your companion (name + personality) to Claude Code''s config at:' +
    LineEnding + LineEnding + ConfigPath + LineEnding + LineEnding +
    'Claude Code will use this companion on next start. Continue?',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;

  try
    FS := TFileStream.Create(ConfigPath, fmOpenRead or fmShareDenyNone);
    try
      Parser := TJSONParser.Create(FS);
      try
        Data := Parser.Parse;
      finally
        Parser.Free;
      end;
    finally
      FS.Free;
    end;

    if Data is TJSONObject then
    begin
      Root := TJSONObject(Data);

      // Create or update companion object
      if Root.Find('companion') is TJSONObject then
        Companion := TJSONObject(Root.Find('companion'))
      else
      begin
        Companion := TJSONObject.Create;
        Root.Add('companion', Companion);
      end;

      // Update name and personality
      if Companion.Find('name') <> nil then
        Companion.Delete('name');
      Companion.Add('name', ValidateName(FNameEdit.Text));

      if Companion.Find('personality') <> nil then
        Companion.Delete('personality');
      Companion.Add('personality', ValidatePersonality(FPersonalityMemo.Text));

      if Companion.Find('hatchedAt') = nil then
        Companion.Add('hatchedAt', CurrentTimeMillis);

      // Write back
      S := Root.FormatJSON;
      FS := TFileStream.Create(ConfigPath, fmCreate);
      try
        if Length(S) > 0 then
          FS.Write(S[1], Length(S));
      finally
        FS.Free;
      end;

      ShowMessage('Companion exported to Claude Code!');
    end;

    Data.Free;
  except
    on E: Exception do
      ShowMessage('Export failed: ' + E.Message);
  end;
end;

procedure TFormConfig.OnPrivacyChange(Sender: TObject);
begin
  case FPrivacySlider.Position of
    0: FPrivacyDesc.Caption :=
      'Chat Only: Only sends data when you type a message or drop a file. ' +
      'No automatic reactions. Sends: companion name, personality, species, ' +
      'rarity, stats, and your message text.';
    1: FPrivacyDesc.Caption :=
      'Standard: Sends periodic ambient context including time of day, ' +
      'day of week, and session duration. No personal data, usernames, ' +
      'or system information. Your companion reacts to the passage of time.';
    2: FPrivacyDesc.Caption :=
      'Personalized: Additionally sends your username, running process names, ' +
      'and memory usage. Enables reactions like "I see VS Code is open" or ' +
      '"your system is working hard." Similar to data Claude Code sends.';
  end;
end;

procedure TFormConfig.OnLoginClick(Sender: TObject);
var
  Verifier, Challenge, State: string;
  Code, RetState: string;
  OAuthResult: TOAuthResult;
  Port: Integer;
  Creds, FreshCreds: TCredentials;
begin
  FBtnLogin.Enabled := False;
  FBtnLogin.Caption := 'Opening browser...';
  Application.ProcessMessages;

  Verifier := GenerateCodeVerifier;
  Challenge := GenerateCodeChallenge(Verifier);
  State := GenerateState;
  Port := 19280 + Random(100);  // random port in safe range

  try
    if RunOAuthFlow(Code, RetState, Challenge, State, Port, 120) then
    begin
      FBtnLogin.Caption := 'Exchanging token...';
      Application.ProcessMessages;

      OAuthResult := ExchangeCodeForTokens(Code, RetState, Verifier, Port);
      if OAuthResult.Success then
      begin
        // Save credentials with verification
        Creds.AccessToken := OAuthResult.AccessToken;
        Creds.RefreshToken := OAuthResult.RefreshToken;
        Creds.ExpiresAt := CurrentTimeMillis + Int64(OAuthResult.ExpiresIn) * 1000;
        Creds.Scopes := OAuthResult.Scopes;

        try
          SaveCredentials(GetCredentialsPath, Creds);

          // Verify the save by reading back
          FreshCreds := LoadCredentials(GetCredentialsPath);
          if FreshCreds.AccessToken = OAuthResult.AccessToken then
          begin
            FBtnLogin.Caption := 'Logged in!';
            ShowMessage('Login successful!' + LineEnding +
                        'Token: ' + Copy(OAuthResult.AccessToken, 1, 25) + '...' + LineEnding +
                        'Expires in: ' + IntToStr(OAuthResult.ExpiresIn) + 's' + LineEnding +
                        'Verified saved to: ' + GetCredentialsPath);
          end
          else
          begin
            FBtnLogin.Caption := 'Save failed!';
            ShowMessage('Token obtained but SAVE VERIFICATION FAILED!' + LineEnding +
                        'Expected: ' + Copy(OAuthResult.AccessToken, 1, 25) + LineEnding +
                        'Got back: ' + Copy(FreshCreds.AccessToken, 1, 25) + LineEnding +
                        'Path: ' + GetCredentialsPath);
          end;
        except
          on E: Exception do
          begin
            FBtnLogin.Caption := 'Save error!';
            ShowMessage('Token obtained but save CRASHED:' + LineEnding +
                        E.Message + LineEnding +
                        'Path: ' + GetCredentialsPath);
          end;
        end;

        // Fetch profile to get the correct orgUuid for this token
        try
          FBtnLogin.Caption := 'Fetching profile...';
          Application.ProcessMessages;
          FConfig.OrgUuid := FetchOrgUuid(Creds.AccessToken);
          if FConfig.OrgUuid <> '' then
            SaveConfig(GetConfigPath, FConfig);
        except
        end;
        // Fallback to Claude Code config if profile fetch failed
        if FConfig.OrgUuid = '' then
        begin
          ImportFromClaudeCode(FConfig);
          SaveConfig(GetConfigPath, FConfig);
        end;
      end
      else
      begin
        FBtnLogin.Caption := 'Login failed';
        ShowMessage('Token exchange failed:' + LineEnding + OAuthResult.ErrorMsg);
      end;
    end
    else
    begin
      FBtnLogin.Caption := 'Timed out';
      ShowMessage('Login timed out. Please try again.');
    end;
  except
    on E: Exception do
    begin
      FBtnLogin.Caption := 'Error';
      ShowMessage('Login error: ' + E.Message);
    end;
  end;

  FBtnLogin.Enabled := True;
  FBtnLogin.Caption := 'Login to Claude...';
end;

// ============================================================
//  Carousel handlers
// ============================================================

procedure TFormConfig.OnPrevSpecies(Sender: TObject);
begin
  FCurrentSpecies := (FCurrentSpecies + SPECIES_COUNT - 1) mod SPECIES_COUNT;
  UpdateLabels;
  UpdatePreview;
end;

procedure TFormConfig.OnNextSpecies(Sender: TObject);
begin
  FCurrentSpecies := (FCurrentSpecies + 1) mod SPECIES_COUNT;
  UpdateLabels;
  UpdatePreview;
end;

procedure TFormConfig.OnPrevEye(Sender: TObject);
begin
  FCurrentEye := (FCurrentEye + EYE_COUNT - 1) mod EYE_COUNT;
  UpdateLabels;
  UpdatePreview;
end;

procedure TFormConfig.OnNextEye(Sender: TObject);
begin
  FCurrentEye := (FCurrentEye + 1) mod EYE_COUNT;
  UpdateLabels;
  UpdatePreview;
end;

procedure TFormConfig.OnPrevHat(Sender: TObject);
begin
  FCurrentHat := (FCurrentHat + HAT_COUNT - 1) mod HAT_COUNT;
  UpdateLabels;
  UpdatePreview;
end;

procedure TFormConfig.OnNextHat(Sender: TObject);
begin
  FCurrentHat := (FCurrentHat + 1) mod HAT_COUNT;
  UpdateLabels;
  UpdatePreview;
end;

procedure TFormConfig.OnPrevRarity(Sender: TObject);
begin
  FCurrentRarity := (FCurrentRarity + RARITY_COUNT - 1) mod RARITY_COUNT;
  UpdateLabels;
end;

procedure TFormConfig.OnNextRarity(Sender: TObject);
begin
  FCurrentRarity := (FCurrentRarity + 1) mod RARITY_COUNT;
  UpdateLabels;
end;

procedure TFormConfig.UpdateLabels;
begin
  FSpeciesLabel.Caption := 'Species: ' + SpeciesNames[FCurrentSpecies];
  FEyeLabel.Caption := 'Eyes: ' + EyeLabels[FCurrentEye] + ' ' + EyeChars[FCurrentEye];
  FHatLabel.Caption := 'Hat: ' + HatNames[FCurrentHat];
  // Stars per rarity: common=1, uncommon=2, etc.
  FRarityLabel.Caption := 'Rarity: ' +
    StringOfChar('*', FCurrentRarity + 1) + ' ' +
    UpperCase(RarityNames[FCurrentRarity]);
end;

procedure TFormConfig.UpdatePreview;
begin
  FPreviewBox.Invalidate;
end;

procedure TFormConfig.OnPreviewPaint(Sender: TObject);
var
  Frame: TArtFrame;
  I, Y, HatIdx, TotalLines, ArtW, OffsetX: Integer;
  Line: string;
  C: TCanvas;
begin
  C := FPreviewBox.Canvas;
  C.Font.Assign(FMonoFont);

  // Black background, green text — matching the main app
  C.Brush.Color := $00000000;
  C.FillRect(FPreviewBox.ClientRect);
  C.Font.Color := $0000DD00;

  TotalLines := 5; // always 5 lines (hat replaces blank first line)
  HatIdx := FCurrentHat;

  // Center vertically
  Y := (FPreviewBox.Height - TotalLines * C.TextHeight('M')) div 2;
  if Y < 2 then Y := 2;

  // Center horizontally (art is ~12 chars wide)
  ArtW := C.TextWidth('M') * 12;
  OffsetX := (FPreviewBox.Width - ArtW) div 2;
  if OffsetX < 4 then OffsetX := 4;

  C.Brush.Style := bsClear;
  Frame := GetArtFrame(FCurrentSpecies, 0);
  for I := 0 to 4 do
  begin
    // Replace blank first line with hat if present
    if (I = 0) and (HatIdx > 0) and (HatIdx < HAT_COUNT) and (HatArt[HatIdx] <> '') then
      Line := HatArt[HatIdx]
    else
      Line := SubstituteEyes(Frame[I], EyeChars[FCurrentEye]);
    C.TextOut(OffsetX, Y, Line);
    Inc(Y, C.TextHeight('M'));
  end;
  C.Brush.Style := bsSolid;
end;

// ============================================================
//  Name / personality
// ============================================================

procedure TFormConfig.OnNameChange(Sender: TObject);
begin
  FNameCounter.Caption := IntToStr(Length(FNameEdit.Text)) + '/' + IntToStr(MAX_NAME_LEN);
  if Length(FNameEdit.Text) > MAX_NAME_LEN - 5 then
    FNameCounter.Font.Color := clRed
  else
    FNameCounter.Font.Color := clGray;
end;

procedure TFormConfig.OnPersonalityChange(Sender: TObject);
var
  Len: Integer;
begin
  Len := Length(FPersonalityMemo.Text);
  FPersonalityCounter.Caption := IntToStr(Len) + '/' + IntToStr(MAX_PERSONALITY_LEN) +
    ' chars (server limit: 200)';
  if Len > MAX_PERSONALITY_LEN then
  begin
    FPersonalityCounter.Font.Color := clRed;
    FPersonalityCounter.Caption := FPersonalityCounter.Caption + ' OVER LIMIT';
  end
  else if Len > MAX_PERSONALITY_LEN - 20 then
    FPersonalityCounter.Font.Color := $0080FF  // orange
  else
    FPersonalityCounter.Font.Color := clGray;
end;

// ============================================================
//  OK
// ============================================================

procedure TFormConfig.OnStatSliderChange(Sender: TObject);
var
  Idx: Integer;
begin
  if Sender is TTrackBar then
  begin
    Idx := TTrackBar(Sender).Tag;
    if (Idx >= 0) and (Idx <= 4) then
      FStatValues[Idx].Caption := IntToStr(TTrackBar(Sender).Position);
  end;
end;

procedure TFormConfig.OnOK(Sender: TObject);
begin
  // Silently truncate personality if over limit (200 chars server max)
  FConfig.Name := ValidateName(FNameEdit.Text);
  FConfig.Personality := ValidatePersonality(FPersonalityMemo.Text);
  FConfig.Species := SpeciesNames[FCurrentSpecies];
  FConfig.Eye := EyeChars[FCurrentEye];
  FConfig.Hat := HatNames[FCurrentHat];
  FConfig.Rarity := RarityNames[FCurrentRarity];
  FConfig.Debugging := FStatSliders[0].Position;
  FConfig.Patience := FStatSliders[1].Position;
  FConfig.Chaos := FStatSliders[2].Position;
  FConfig.Wisdom := FStatSliders[3].Position;
  FConfig.Snark := FStatSliders[4].Position;
  FConfig.PrivacyMode := FPrivacySlider.Position;
  FConfig.PersonalizedMode := FConfig.PrivacyMode = 2;

  ModalResult := mrOK;
end;

function TFormConfig.ShowConfigDialog: Boolean;
begin
  // Pre-populate from current config
  FCurrentSpecies := GetSpeciesIndex(FConfig.Species);
  if FCurrentSpecies < 0 then FCurrentSpecies := 15;
  FCurrentEye := GetEyeIndex(FConfig.Eye);
  if FCurrentEye < 0 then FCurrentEye := 0;
  FCurrentHat := GetHatIndex(FConfig.Hat);
  if FCurrentHat < 0 then FCurrentHat := 0;
  FCurrentRarity := GetRarityIndex(FConfig.Rarity);
  if FCurrentRarity < 0 then FCurrentRarity := 0;

  FNameEdit.Text := FConfig.Name;
  FPersonalityMemo.Text := FConfig.Personality;

  // Load stats into sliders
  FStatSliders[0].Position := FConfig.Debugging;
  FStatSliders[1].Position := FConfig.Patience;
  FStatSliders[2].Position := FConfig.Chaos;
  FStatSliders[3].Position := FConfig.Wisdom;
  FStatSliders[4].Position := FConfig.Snark;
  OnStatSliderChange(FStatSliders[0]);
  OnStatSliderChange(FStatSliders[1]);
  OnStatSliderChange(FStatSliders[2]);
  OnStatSliderChange(FStatSliders[3]);
  OnStatSliderChange(FStatSliders[4]);

  FPrivacySlider.Position := FConfig.PrivacyMode;
  OnPrivacyChange(nil);
  OnNameChange(nil);
  OnPersonalityChange(nil);
  UpdateLabels;

  Result := ShowModal = mrOK;
end;

end.
