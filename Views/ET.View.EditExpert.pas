unit ET.View.EditExpert;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.Buttons, Vcl.ExtCtrls, System.Actions, Vcl.ActnList;

type
  TEditExpertView = class(TForm)
    ExpertFilePanel: TPanel;
    SelectOutputFileButton: TSpeedButton;
    ExpertFileLabel: TLabel;
    ExpertFileEdit: TEdit;
    ExpertNamePanel: TPanel;
    ExpertNameLabel: TLabel;
    ExpertNameEdit: TEdit;
    ButtonsPanel: TPanel;
    CancelButton: TButton;
    OKButton: TButton;
    FakeFileCheckBox: TCheckBox;
    OpenDialog: TFileOpenDialog;
    ActionList: TActionList;
    OKAction: TAction;
    SelectFileAction: TAction;
    procedure OKActionUpdate(Sender: TObject);
    procedure OKActionExecute(Sender: TObject);
    procedure SelectFileActionExecute(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  EditExpertView: TEditExpertView;

implementation

{$R *.dfm}

uses
  System.IOUtils;

procedure TEditExpertView.OKActionExecute(Sender: TObject);
begin
  ModalResult := mrOK;
end;

procedure TEditExpertView.OKActionUpdate(Sender: TObject);
begin
  OKAction.Enabled := not string(ExpertNameEdit.Text).IsEmpty and (FakeFileCheckBox.Checked or TFile.Exists(ExpertFileEdit.Text));
end;

procedure TEditExpertView.SelectFileActionExecute(Sender: TObject);
begin
  if OpenDialog.Execute then
    ExpertFileEdit.Text := OpenDialog.FileName;
end;

end.
