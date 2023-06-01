unit ET.View.Main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, System.ImageList, Vcl.ImgList, System.Actions, Vcl.ActnList, Vcl.Menus, Vcl.ComCtrls, Vcl.ToolWin,
  Vcl.StdCtrls, Vcl.ExtCtrls,
  DW.Environment.BDS;

type
  TProcessModule = record
    Handle: HMODULE;
    FileName: string;
  end;

  TProcessModules = TArray<TProcessModule>;

  TBDSProcessInfo = record
    BDSPath: string;
    IsLoaded: Boolean;
    IsRunning: Boolean;
    Modules: TProcessModules;
    ProcessID: DWORD;
    function Update(const ABDSPath: string): Boolean;
  end;

  TMainView = class(TForm)
    StatusBar: TStatusBar;
    ExpertsListView: TListView;
    ToolBar: TToolBar;
    ExpertEnableToolButton: TToolButton;
    ExpertDisableToolButton: TToolButton;
    Sep1ToolButton: TToolButton;
    ExpertAddToolButton: TToolButton;
    ExpertRemoveToolButton: TToolButton;
    ExpertsPopupMenu: TPopupMenu;
    ExpertEnableMenuItem: TMenuItem;
    ExpertDisableMenuItem: TMenuItem;
    Sep1MenuItem: TMenuItem;
    ExpertRemoveMenuItem: TMenuItem;
    ActionList: TActionList;
    ExpertEnableAction: TAction;
    ExpertDisableAction: TAction;
    ExpertAddAction: TAction;
    ExpertRemoveAction: TAction;
    StateImageList: TImageList;
    VersionComboBox: TComboBox;
    Sep3ToolButton: TToolButton;
    ActionsImageList: TImageList;
    OpenDialog: TFileOpenDialog;
    ExpertEditAction: TAction;
    ExpertEditToolButton: TToolButton;
    Sep2ToolButton: TToolButton;
    ExpertsEditMenuItem: TMenuItem;
    CheckProcessTimer: TTimer;
    ExpertSafeModeAction: TAction;
    ExpertSafeModeButton: TToolButton;
    ExpertNormalModeButton: TToolButton;
    ExpertNormalModeAction: TAction;
    Sep4ToolButton: TToolButton;
    procedure VersionComboBoxChange(Sender: TObject);
    procedure ExpertDisableActionExecute(Sender: TObject);
    procedure ExpertEnableActionExecute(Sender: TObject);
    procedure ExpertEnableActionUpdate(Sender: TObject);
    procedure ExpertDisableActionUpdate(Sender: TObject);
    procedure ExpertRemoveActionExecute(Sender: TObject);
    procedure ExpertRemoveActionUpdate(Sender: TObject);
    procedure ExpertAddActionExecute(Sender: TObject);
    procedure ExpertAddActionUpdate(Sender: TObject);
    procedure ExpertEditActionExecute(Sender: TObject);
    procedure ExpertEditActionUpdate(Sender: TObject);
    procedure ExpertsListViewInfoTip(Sender: TObject; Item: TListItem; var InfoTip: string);
    procedure CheckProcessTimerTimer(Sender: TObject);
    procedure ExpertSafeModeActionExecute(Sender: TObject);
    procedure ExpertSafeModeActionUpdate(Sender: TObject);
    procedure ExpertNormalModeActionExecute(Sender: TObject);
    procedure ExpertNormalModeActionUpdate(Sender: TObject);
  private
    FBDS: TBDSEnvironment;
    FExperts: TStrings;
    FProcessInfo: TBDSProcessInfo;
    procedure AddExpert(const AFileName: string);
    procedure CopyExperts;
    function FixPath(const AIndex: Integer; const APath: string): string;
    function IsPendingEnable(const AIndex: Integer; const AExpertName: string): Boolean;
    procedure ReselectListItem(const ASelectedName: string);
    function SelectedState: Integer;
    procedure UpdateExpertsExisting;
    procedure UpdateExpertsListView(const ASelectedName: string = '');
    procedure UpdateExpertsPending;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  MainView: TMainView;

implementation

{$R *.dfm}

uses
  System.IOUtils, System.JSON,
  Winapi.TlHelp32,
  Winapi.PsAPI,
  DW.OSLog,
  DW.Winapi.Helpers, DW.IOUtils.Helpers,
  DW.Vcl.DialogService,
  ET.View.EditExpert;

const
  cBDSRegKeyExperts = 'Experts';
  cBDSRegKeyDWDisabledExperts = 'DelphiWorlds\DisabledExperts';
  cExpertFlagPendingLoad = '_';
  cExpertFlagSafeMode = '~';

  cStateIndexExpertNotLoaded = 0;
  cStateIndexExpertLoaded = 1;
  cStateIndexExpertFailedToLoad = 2;
  cStateIndexExpertPendingDisable = 3;
  cStateIndexExpertPendingEnable = 4;
  cStateIndexExpertDisabled = 5;
  cStateIndexExpertNoExist = 6;
  cStateIndexExpertPendingSafeMode = 7;
  cStateIndexExpertSafeMode = 8;

  cStateHints: array[cStateIndexExpertNotLoaded..cStateIndexExpertSafeMode] of string = (
    'Expert is registered, but not loaded',
    'Expert is loaded',
    'Expert is registered, but failed to load',
    'Expert is pending being unloaded',
    'Expert is pending being loaded',
    'Expert is disabled',
    'Expert file does not exist',
    'Expert is pending safe mode',
    'Expert is in safe mode'
  );

type
  TProcessModulesHelper = record helper for TProcessModules
  public
    function Exists(const AFileName: string): Boolean;
  end;

  TBDSMainWindowFinder = class(TObject)
  private
    class var FIsVisible: Boolean;
    class function EnumWindowsProc(AWnd: HWND; AProcessId: DWORD): Bool; stdcall; static;
    class function IsMainWindowVisible(const AProcessId: DWORD): Boolean;
  end;

function IsValidExpert(const AFileName: string): Boolean;
var
  LHandle: THandle;
begin
  Result := False;
  LHandle := LoadLibraryEx(PChar(AFileName), 0, DONT_RESOLVE_DLL_REFERENCES);
  if LHandle <> 0 then
  try
    Result := GetProcAddress(LHandle, 'INITWIZARD0001') <> nil;
  finally
    FreeLibrary(LHandle);
  end;
end;

function GetProcessFullPath(const AProcessID: DWORD): string;
var
  LHandle: THandle;
  LPath: array[0..MAX_PATH - 1] of Char;
begin
  Result := '';
  LHandle := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False, AProcessID);
  if LHandle <> 0 then
  try
    if GetModuleFileNameEx(LHandle, 0, LPath, MAX_PATH) <> 0 then
      Result := LPath;
  finally
    CloseHandle(LHandle)
  end;
end;

function GetProcessID(const AFileName: string): DWORD;
var
  LContinue: Boolean;
  LSnapshotHandle: THandle;
  LProcessEntry32: TProcessEntry32;
  LFileName: string;
begin
  Result := 0;
  LProcessEntry32.dwSize := SizeOf(LProcessEntry32);
  LSnapshotHandle := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if LSnapshotHandle <> INVALID_HANDLE_VALUE then
  try
    LContinue := Process32First(LSnapshotHandle, LProcessEntry32);
    while (Result = 0) and LContinue do
    begin
      LFileName := GetProcessFullPath(LProcessEntry32.th32ProcessID);
      if AnsiSameText(LFileName, AFileName) then
        Result := LProcessEntry32.th32ProcessID;
      LContinue := Process32Next(LSnapshotHandle, LProcessEntry32);
    end;
  finally
    CloseHandle(LSnapshotHandle);
  end;
end;

function GetProcessModules(const AProcessID: DWORD): TProcessModules;
var
  LSnapshotHandle: THandle;
  LModule: TModuleEntry32;
  LContinue: Boolean;
  LProcessModule: TProcessModule;
begin
  LSnapshotHandle := CreateToolhelp32Snapshot(TH32CS_SNAPMODULE, AProcessID);
  if LSnapshotHandle <> INVALID_HANDLE_VALUE then
  try
    LModule.dwSize := SizeOf(LModule);
    LContinue := Module32First(LSnapshotHandle, LModule);
    while LContinue do
    begin
      LProcessModule.Handle := LModule.hModule;
      LProcessModule.FileName := LModule.szExePath;
      Result := Result + [LProcessModule];
      LContinue := Module32Next(LSnapshotHandle, LModule);
    end;
  finally
    CloseHandle(LSnapshotHandle);
  end;
end;

class function TBDSMainWindowFinder.EnumWindowsProc(AWnd: HWND; AProcessId: DWORD): Bool;
var
  LProcessID: DWORD;
  LWndClass: string;
begin
  Result := True;
  SetLength(LWndClass, 80);
  GetWindowThreadProcessId(AWnd, @LProcessID);
  if AProcessID = LProcessID then
  begin
    SetLength(LWndClass, GetClassName(AWnd, PChar(LWndClass), Length(LWndClass)));
    if SameText(LWndClass, 'TAppBuilder') then
    begin
      FIsVisible := IsWindowVisible(AWnd);
      Result := False;
    end;
  end;
end;

class function TBDSMainWindowFinder.IsMainWindowVisible(const AProcessId: DWORD): Boolean;
begin
  FIsVisible := False;
  EnumWindows(@TBDSMainWindowFinder.EnumWindowsProc, LPARAM(AProcessID));
  Result := FIsVisible;
end;

{ TBDSProcessInfo }

function TBDSProcessInfo.Update(const ABDSPath: string): Boolean;
var
  LIsVisible: Boolean;
begin
  BDSPath := ABDSPath;
  LIsVisible := False;
  ProcessID := GetProcessID(BDSPath);
  Modules := [];
  if ProcessID > 0 then
  begin
    IsRunning := True;
    Modules := GetProcessModules(ProcessID);
    LIsVisible := TBDSMainWindowFinder.IsMainWindowVisible(ProcessID);
  end
  else
    IsRunning := False;
  Result := IsLoaded <> LIsVisible;
  IsLoaded := LIsVisible;
end;

{ TProcessModulesHelper }

function TProcessModulesHelper.Exists(const AFileName: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to Length(Self) - 1 do
  begin
    if AnsiSameText(Self[I].FileName, AFileName) then
      Exit(True);
  end;
end;

{ TMainView }

constructor TMainView.Create(AOwner: TComponent);
var
  I: Integer;
begin
  inherited;
  FBDS := TBDSEnvironment.Create(True);
  FExperts := TStringList.Create;
  for I := 0 to FBDS.RootKeyCount - 1 do
    VersionComboBox.Items.Add(FBDS.GetVersionName(I));
  if VersionComboBox.Items.Count > 0 then
  begin
    VersionComboBox.ItemIndex := VersionComboBox.Items.Count - 1;
    FProcessInfo.Update(FBDS.GetBDSEXEPath(VersionComboBox.ItemIndex));
    UpdateExpertsListView;
    CheckProcessTimer.Enabled := True;
  end;
end;

destructor TMainView.Destroy;
begin
  FBDS.Free;
  FExperts.Free;
  inherited;
end;

procedure TMainView.CheckProcessTimerTimer(Sender: TObject);
var
  LIndex: Integer;
  LWasRunning: Boolean;
  LBDSPath: string;
begin
  LIndex := VersionComboBox.ItemIndex;
  if LIndex > -1 then
  begin
    LWasRunning := False;
    LBDSPath := FBDS.GetBDSEXEPath(LIndex);
    if LBDSPath.Equals(FProcessInfo.BDSPath) then
      LWasRunning := FProcessInfo.IsRunning;
    if FProcessInfo.Update(LBDSPath) then
      UpdateExpertsListView;
    if LWasRunning and not FProcessInfo.IsRunning then
      // Delphi was terminated - Check copying of experts
      CopyExperts;
  end;
end;

procedure TMainView.CopyExperts;
var
  LCopyConfigFileName, LSourceFileName, LDestFileName: string;
  LJSON, LElement: TJSONValue;
begin
  LCopyConfigFileName := TPathHelper.GetAppDocumentsFile('copyexperts.json');
  if TFile.Exists(LCopyConfigFileName) then
  begin
    LJSON := TJSONObject.ParseJSONValue(TFile.ReadAllText(LCopyConfigFileName));
    if LJSON <> nil then
    try
      for LElement in TJSONArray(LJSON) do
      begin
        if LElement.TryGetValue('Source', LSourceFileName) and LElement.TryGetValue('Dest', LDestFileName) then
        begin
          if TFile.Exists(LSourceFileName) and TDirectoryHelper.Exists(TPath.GetDirectoryName(LDestFileName)) then
          try
            if TFileHelper.CopyIfNewer(LSourceFileName, LDestFileName, True) then
              TOSLog.d('Copied %s to %s', [LSourceFileName, LDestFileName]);
          except
            // Eat it, if cannot overwrite
          end;
        end;
      end;
    finally
      LJSON.Free;
    end;
  end;
end;

procedure TMainView.AddExpert(const AFileName: string);
var
  I, LIndex: Integer;
  LExpertName: string;
begin
  LIndex := VersionComboBox.ItemIndex;
  FBDS.GetBDSValues(LIndex, cBDSRegKeyExperts, FExperts);
  for I := 0 to FExperts.Count - 1 do
  begin
    if AnsiSameText(FExperts.ValueFromIndex[I], AFileName) then
    begin
      TDialog.Warning(Format('An expert called %s already exists with the same file as %s', [FExperts.Names[I], AFileName]));
      Exit;
    end;
  end;
  if not IsValidExpert(AFileName) then
  begin
    TDialog.Warning(Format('The file %s is not a valid expert', [AFileName]));
    Exit;
  end;
  LExpertName := TPath.GetFileNameWithoutExtension(AFileName);
  // Add expert entry
  if FBDS.OpenKey(LIndex, cBDSRegKeyExperts) then
  try
    FBDS.Registry.WriteString(LExpertName, AFileName);
  finally
    FBDS.CloseKey;
  end;
  // Pending enable
  if FBDS.OpenKey(LIndex, cBDSRegKeyDWDisabledExperts, True) then
  try
    FBDS.Registry.WriteString(LExpertName, cExpertFlagPendingLoad + AFileName);
  finally
    FBDS.CloseKey;
  end;
end;

function TMainView.FixPath(const AIndex: Integer; const APath: string): string;
begin
  if APath.ToUpper.Contains('$(BDS)') then
    Result := StringReplace(APath, '$(BDS)\', FBDS.GetBDSPath(AIndex), [rfIgnoreCase])
  else
    Result := APath;
end;

function TMainView.IsPendingEnable(const AIndex: Integer; const AExpertName: string): Boolean;
begin
  Result := False;
  if FBDS.OpenKey(AIndex, cBDSRegKeyDWDisabledExperts) then
  try
    Result := FBDS.Registry.ReadString(AExpertName).StartsWith(cExpertFlagPendingLoad);
  finally
    FBDS.CloseKey;
  end;
end;

function TMainView.SelectedState: Integer;
begin
  Result := -1;
  if ExpertsListView.Selected <> nil then
    Result := ExpertsListView.Selected.StateIndex;
end;

procedure TMainView.ExpertAddActionExecute(Sender: TObject);
var
  I: Integer;
begin
  if OpenDialog.Execute then
  begin
    for I := 0 to OpenDialog.Files.Count - 1 do
      AddExpert(OpenDialog.Files[I]);
    UpdateExpertsListView;
  end;
end;

procedure TMainView.ExpertAddActionUpdate(Sender: TObject);
begin
  ExpertAddAction.Enabled := VersionComboBox.ItemIndex > -1;
end;

procedure TMainView.ExpertDisableActionExecute(Sender: TObject);
var
  LWrotePending: Boolean;
  LExpertName, LFileName: string;
  LIndex: Integer;
begin
  if TDialog.Confirm('Disable the selected expert?', True) then
  begin
    LIndex := VersionComboBox.ItemIndex;
    LExpertName := ExpertsListView.Selected.Caption;
    LFileName := ExpertsListView.Selected.SubItems[0];
    LWrotePending := False;
    if FBDS.OpenKey(LIndex, cBDSRegKeyDWDisabledExperts, True) then
    try
      FBDS.Registry.WriteString(LExpertName, LFileName);
      LWrotePending := True;
    finally
      FBDS.CloseKey;
    end;
    if LWrotePending and FBDS.OpenKey(LIndex, cBDSRegKeyExperts) then
    try
      FBDS.Registry.DeleteValue(LExpertName);
    finally
      FBDS.CloseKey;
    end;
    UpdateExpertsListView;
  end;
end;

procedure TMainView.ExpertEnableActionExecute(Sender: TObject);
var
  LExpertName, LFileName: string;
  LIndex: Integer;
begin
  LIndex := VersionComboBox.ItemIndex;
  LExpertName := ExpertsListView.Selected.Caption;
  LFileName := '';
  if FBDS.OpenKey(LIndex, cBDSRegKeyDWDisabledExperts) then
  try
    LFileName := FBDS.Registry.ReadString(LExpertName);
  finally
    FBDS.CloseKey;
  end;
  if not LFileName.IsEmpty and FBDS.OpenKey(LIndex, cBDSRegKeyExperts) then
  try
    FBDS.Registry.WriteString(LExpertName, LFileName);
  finally
    FBDS.CloseKey;
  end;
  if not LFileName.IsEmpty and FBDS.OpenKey(LIndex, cBDSRegKeyDWDisabledExperts) then
  try
    if GetProcessID(FBDS.GetBDSEXEPath(LIndex)) > 0 then
      FBDS.Registry.WriteString(LExpertName, cExpertFlagPendingLoad + LFileName)
    else
      FBDS.Registry.DeleteValue(LExpertName);
  finally
    FBDS.CloseKey;
  end;
  UpdateExpertsListView;
end;

procedure TMainView.ExpertEnableActionUpdate(Sender: TObject);
begin
  ExpertEnableAction.Enabled := SelectedState in [cStateIndexExpertPendingDisable, cStateIndexExpertDisabled];
end;

procedure TMainView.ExpertNormalModeActionExecute(Sender: TObject);
var
  LExpertName, LFileName: string;
  LIndex, I: Integer;
begin
  if TDialog.Confirm('Deactivating safe mode will re-enable all experts disabled under safemode. Do you wish to continue?', True) then
  begin
    LIndex := VersionComboBox.ItemIndex;
    FBDS.GetBDSValues(LIndex, cBDSRegKeyDWDisabledExperts, FExperts);
    for I := 0 to FExperts.Count - 1 do
    begin
      LExpertName := FExperts.Names[I];
      LFileName := FExperts.ValueFromIndex[I];
      if LFileName.StartsWith(cExpertFlagSafeMode) then
      begin
        LFileName := LFileName.Substring(1);
        // Write value into Experts key if it does not exist
        if FBDS.OpenKey(LIndex, cBDSRegKeyExperts) then
        try
          if not FBDS.Registry.ValueExists(LExpertName) then
            FBDS.Registry.WriteString(LExpertName, LFileName);
         finally
          FBDS.CloseKey;
        end;
        // Delete DisabledExperts value if loaded already, or update to flag pending load
        if FBDS.OpenKey(LIndex, cBDSRegKeyDWDisabledExperts) then
        try
          if FProcessInfo.Modules.Exists(FixPath(LIndex, LFileName)) then
            FBDS.Registry.DeleteValue(LExpertName)
          else
            FBDS.Registry.WriteString(LExpertName, cExpertFlagPendingLoad + LFileName);
        finally
          FBDS.CloseKey;
        end;
      end;
    end;
    UpdateExpertsListView;
  end;
end;

procedure TMainView.ExpertSafeModeActionExecute(Sender: TObject);
var
  LWrotePending: Boolean;
  LExpertName, LFileName: string;
  LIndex, I: Integer;
begin
  if TDialog.Confirm('Activating safe mode will disable all active experts. This can be reversed when finished. Do you wish to continue?', True) then
  begin
    LIndex := VersionComboBox.ItemIndex;
    FBDS.GetBDSValues(LIndex, cBDSRegKeyExperts, FExperts);
    for I := 0 to FExperts.Count - 1 do
    begin
      LWrotePending := False;
      LExpertName := FExperts.Names[I];
      LFileName := FExperts.ValueFromIndex[I];
      // Add safe mode value
      if FBDS.OpenKey(LIndex, cBDSRegKeyDWDisabledExperts, True) then
      try
        FBDS.Registry.WriteString(LExpertName, cExpertFlagSafeMode + LFileName);
        LWrotePending := True;
      finally
        FBDS.CloseKey;
      end;
      // Delete from existing
      if LWrotePending and FBDS.OpenKey(LIndex, cBDSRegKeyExperts, True) then
      try
        FBDS.Registry.DeleteValue(LExpertName);
      finally
        FBDS.CloseKey;
      end;
    end;
    UpdateExpertsListView;
  end;
end;

procedure TMainView.ExpertNormalModeActionUpdate(Sender: TObject);
var
  LExperts: TStrings;
  LIndex, I: Integer;
  LEnabled: Boolean;
begin
  LEnabled := False;
  LIndex := VersionComboBox.ItemIndex;
  if LIndex > -1 then
  begin
    LExperts := TStringList.Create;
    try
      FBDS.GetBDSValues(LIndex, cBDSRegKeyDWDisabledExperts, LExperts);
      for I := 0 to LExperts.Count - 1 do
      begin
        if LExperts.ValueFromIndex[I].StartsWith(cExpertFlagSafeMode) then
        begin
          LEnabled := True;
          Break;
        end;
      end;
    finally
      LExperts.Free;
    end;
  end;
  ExpertNormalModeAction.Enabled := LEnabled;
end;

procedure TMainView.ExpertSafeModeActionUpdate(Sender: TObject);
var
  LExperts: TStrings;
  LIndex: Integer;
  LEnabled: Boolean;
begin
  LEnabled := False;
  LIndex := VersionComboBox.ItemIndex;
  if LIndex > -1 then
  begin
    LExperts := TStringList.Create;
    try
      FBDS.GetBDSValues(LIndex, cBDSRegKeyExperts, LExperts);
      LEnabled := LExperts.Count > 0;
    finally
      LExperts.Free;
    end;
  end;
  ExpertSafeModeAction.Enabled := LEnabled;
end;

procedure TMainView.ExpertRemoveActionExecute(Sender: TObject);
var
  LIndex: Integer;
  LExpertName, LFileName: string;
begin
  if TDialog.Confirm('Remove the selected expert?', True) then
  begin
    LIndex := VersionComboBox.ItemIndex;
    LExpertName := ExpertsListView.Selected.Caption;
    LFileName := ExpertsListView.Selected.SubItems[0];
    if FBDS.OpenKey(LIndex, cBDSRegKeyExperts) then
    try
      FBDS.Registry.DeleteValue(LExpertName);
    finally
      FBDS.CloseKey;
    end;
    if SelectedState = cStateIndexExpertLoaded then
    begin
      if FBDS.OpenKey(LIndex, cBDSRegKeyDWDisabledExperts) then
      try
        FBDS.Registry.WriteString(LExpertName, cExpertFlagPendingLoad + LFileName);
      finally
        FBDS.CloseKey;
      end;
    end
    else if SelectedState = cStateIndexExpertPendingEnable then
    begin
      if FBDS.OpenKey(LIndex, cBDSRegKeyDWDisabledExperts) then
      try
        FBDS.Registry.DeleteValue(LExpertName);
      finally
        FBDS.CloseKey;
      end;
    end;
    UpdateExpertsListView;
  end;
end;

procedure TMainView.ExpertRemoveActionUpdate(Sender: TObject);
begin
  ExpertRemoveAction.Enabled := SelectedState > -1;
end;

procedure TMainView.ExpertsListViewInfoTip(Sender: TObject; Item: TListItem; var InfoTip: string);
begin
  InfoTip := cStateHints[Item.StateIndex];
end;

procedure TMainView.ExpertDisableActionUpdate(Sender: TObject);
begin
  ExpertDisableAction.Enabled :=
    SelectedState in [cStateIndexExpertPendingEnable, cStateIndexExpertNotLoaded, cStateIndexExpertLoaded, cStateIndexExpertFailedToLoad];
end;

procedure TMainView.ExpertEditActionExecute(Sender: TObject);
var
  LForm: TEditExpertView;
  LFileName, LExpertName: string;
begin
  LForm := TEditExpertView.Create(nil);
  try
    LExpertName := ExpertsListView.Selected.Caption;
    LFileName := ExpertsListView.Selected.SubItems[0];
    LForm.ExpertNameEdit.Text := ExpertsListView.Selected.Caption;
    LForm.ExpertFileEdit.Text := LFileName;
    if LForm.ShowModal = mrOK then
    begin
      if FBDS.OpenKey(VersionComboBox.ItemIndex, cBDSRegKeyExperts) then
      try
        if LExpertName <> LForm.ExpertNameEdit.Text then
          FBDS.Registry.DeleteValue(LExpertName);
        FBDS.Registry.WriteString(LForm.ExpertNameEdit.Text, LForm.ExpertFileEdit.Text);
      finally
        FBDS.CloseKey;
      end;
      UpdateExpertsListView(LForm.ExpertNameEdit.Text);
    end;
  finally
    LForm.Free;
  end;
end;

procedure TMainView.ExpertEditActionUpdate(Sender: TObject);
begin
  ExpertEditAction.Enabled :=
    SelectedState in [cStateIndexExpertNotLoaded, cStateIndexExpertLoaded, cStateIndexExpertFailedToLoad, cStateIndexExpertNoExist];
end;

procedure TMainView.VersionComboBoxChange(Sender: TObject);
begin
  UpdateExpertsListView;
end;

procedure TMainView.UpdateExpertsListView(const ASelectedName: string = '');
var
  LSelectedName: string;
begin
  if not ASelectedName.IsEmpty then
    LSelectedName := ASelectedName
  else if ExpertsListView.Selected <> nil then
    LSelectedName := ExpertsListView.Selected.Caption
  else
    LSelectedName := '';
  ExpertsListView.Items.BeginUpdate;
  try
    ExpertsListView.Items.Clear;
    UpdateExpertsExisting;
    UpdateExpertsPending;
  finally
    ExpertsListView.Items.EndUpdate;
  end;
  ReselectListItem(LSelectedName);
end;

procedure TMainView.UpdateExpertsExisting;
var
  I, LIndex: Integer;
  LFileName: string;
  LItem: TListItem;
begin
  LIndex := VersionComboBox.ItemIndex;
  FBDS.GetBDSValues(LIndex, cBDSRegKeyExperts, FExperts);
  for I := 0 to FExperts.Count - 1 do
  begin
    LFileName := FExperts.ValueFromIndex[I];
    LItem := ExpertsListView.Items.Add;
    LItem.Caption := FExperts.Names[I];
    LItem.SubItems.Add(LFileName);
    if not TFile.Exists(FixPath(LIndex, LFileName)) then
      LItem.StateIndex := cStateIndexExpertNoExist
    else if FProcessInfo.IsLoaded then // BDS is running
    begin
      if not FProcessInfo.Modules.Exists(FixPath(LIndex, LFileName)) then
      begin
        // Check if pending enable
        if IsPendingEnable(LIndex, FExperts.Names[I]) then
          LItem.Delete
        else
          LItem.StateIndex := cStateIndexExpertFailedToLoad;
      end
      else
        LItem.StateIndex := cStateIndexExpertLoaded
    end
    else if not IsPendingEnable(LIndex, FExperts.Names[I]) then
      LItem.StateIndex := cStateIndexExpertNotLoaded
    else
      LItem.Delete;
  end;
end;

procedure TMainView.UpdateExpertsPending;
var
  I, LIndex: Integer;
  LFileName: string;
  LItem: TListItem;
begin
  LIndex := VersionComboBox.ItemIndex;
  FBDS.GetBDSValues(LIndex, cBDSRegKeyDWDisabledExperts, FExperts);
  for I := 0 to FExperts.Count - 1 do
  begin
    LFileName := FExperts.ValueFromIndex[I];
    LItem := ExpertsListView.Items.Add;
    LItem.Caption := FExperts.Names[I];
    // BDS is running
    if FProcessInfo.IsLoaded then
    begin
      if LFileName.StartsWith(cExpertFlagPendingLoad) then
      begin
        // Expert is pending load
        LFileName := LFileName.Substring(1);
        if FProcessInfo.Modules.Exists(FixPath(LIndex, LFileName)) then
        begin
          // Loaded successfully, so delete from pending
          if FBDS.OpenKey(LIndex, cBDSRegKeyDWDisabledExperts) then
          try
            FBDS.Registry.DeleteValue(FExperts.Names[I]);
          finally
            FBDS.CloseKey;
          end;
          LItem.Delete;
        end
        else
          LItem.StateIndex := cStateIndexExpertPendingEnable;
      end
      else if LFileName.StartsWith(cExpertFlagSafeMode) then
      begin
        // Expert is marked for safe mode
        LFileName := LFileName.Substring(1);
        // ..but is still loaded
        if FProcessInfo.Modules.Exists(FixPath(LIndex, LFileName)) then
          LItem.StateIndex := cStateIndexExpertPendingSafeMode
        else
          LItem.StateIndex := cStateIndexExpertSafeMode
      end
      else if FProcessInfo.Modules.Exists(FixPath(LIndex, LFileName)) then
        LItem.StateIndex := cStateIndexExpertPendingDisable
      else
        LItem.StateIndex := cStateIndexExpertDisabled;
    end
    else
    begin
      if LFileName.StartsWith(cExpertFlagPendingLoad) or LFileName.StartsWith(cExpertFlagSafeMode) then
      begin
        LFileName := LFileName.Substring(1);
        if FBDS.OpenKey(LIndex, cBDSRegKeyExperts) then
        try
          if FBDS.Registry.ValueExists(FExperts.Names[I]) then
            LItem.StateIndex := cStateIndexExpertPendingEnable;
        finally
          FBDS.CloseKey;
        end;
      end
      else
        LItem.StateIndex := cStateIndexExpertDisabled;
    end;
    LItem.SubItems.Add(LFileName);
  end;
end;

procedure TMainView.ReselectListItem(const ASelectedName: string);
var
  I: Integer;
begin
  ExpertsListView.Selected := nil;
  if ExpertsListView.Items.Count > 0 then
  begin
    if not ASelectedName.IsEmpty then
    begin
      for I := 0 to ExpertsListView.Items.Count - 1 do
      begin
        if ExpertsListView.Items[I].Caption.Equals(ASelectedName) then
        begin
          ExpertsListView.Selected := ExpertsListView.Items[I];
          Break;
        end;
      end;
    end;
    if ExpertsListView.Selected = nil then
      ExpertsListView.Selected := ExpertsListView.Items[0];
  end;
end;

end.
