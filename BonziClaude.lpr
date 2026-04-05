program BonziClaude;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces, // LCL widgetset
  Forms,
  uFormMain,
  uFormConfig,
  uFormHatch,
  uCompanionData,
  uConfig,
  uCredentials,
  uApiClient,
  uValidation,
  uOAuth;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Title := 'BonziClaude';
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
