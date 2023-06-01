program ExpertTool;

uses
  Vcl.Forms,
  ET.View.EditExpert in 'Views\ET.View.EditExpert.pas' {EditExpertView},
  ET.View.Main in 'Views\ET.View.Main.pas' {MainView};

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainView, MainView);
  Application.Run;
end.
