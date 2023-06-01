object EditExpertView: TEditExpertView
  Left = 0
  Top = 0
  Caption = 'Edit Expert'
  ClientHeight = 141
  ClientWidth = 486
  Color = clBtnFace
  Constraints.MaxHeight = 180
  Constraints.MinHeight = 180
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poOwnerFormCenter
  PixelsPerInch = 96
  TextHeight = 13
  object ExpertFilePanel: TPanel
    AlignWithMargins = True
    Left = 4
    Top = 58
    Width = 478
    Height = 50
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 0
    Align = alTop
    BevelOuter = bvNone
    Padding.Bottom = 1
    TabOrder = 0
    object SelectOutputFileButton: TSpeedButton
      AlignWithMargins = True
      Left = 451
      Top = 22
      Width = 23
      Height = 24
      Margins.Left = 0
      Margins.Right = 4
      Action = SelectFileAction
      Align = alRight
      ExplicitLeft = 658
      ExplicitTop = 19
      ExplicitHeight = 25
    end
    object ExpertFileLabel: TLabel
      AlignWithMargins = True
      Left = 3
      Top = 3
      Width = 472
      Height = 13
      Align = alTop
      Caption = 'Expert File:'
      ExplicitWidth = 55
    end
    object ExpertFileEdit: TEdit
      AlignWithMargins = True
      Left = 4
      Top = 23
      Width = 447
      Height = 22
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 0
      Margins.Bottom = 4
      Align = alClient
      ParentShowHint = False
      ShowHint = True
      TabOrder = 0
      ExplicitHeight = 21
    end
  end
  object ExpertNamePanel: TPanel
    AlignWithMargins = True
    Left = 4
    Top = 4
    Width = 478
    Height = 50
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 0
    Align = alTop
    BevelOuter = bvNone
    Padding.Bottom = 1
    TabOrder = 1
    object ExpertNameLabel: TLabel
      AlignWithMargins = True
      Left = 3
      Top = 3
      Width = 472
      Height = 13
      Align = alTop
      Caption = 'Expert Name:'
      ExplicitWidth = 66
    end
    object ExpertNameEdit: TEdit
      AlignWithMargins = True
      Left = 4
      Top = 23
      Width = 474
      Height = 22
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 0
      Margins.Bottom = 4
      Align = alClient
      ParentShowHint = False
      ShowHint = True
      TabOrder = 0
      ExplicitHeight = 21
    end
  end
  object ButtonsPanel: TPanel
    Left = 0
    Top = 109
    Width = 486
    Height = 32
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    object CancelButton: TButton
      AlignWithMargins = True
      Left = 407
      Top = 3
      Width = 75
      Height = 26
      Margins.Right = 4
      Align = alRight
      Cancel = True
      Caption = 'Cancel'
      DoubleBuffered = True
      ModalResult = 2
      ParentDoubleBuffered = False
      TabOrder = 0
    end
    object OKButton: TButton
      AlignWithMargins = True
      Left = 325
      Top = 3
      Width = 75
      Height = 26
      Margins.Right = 4
      Action = OKAction
      Align = alRight
      Default = True
      DoubleBuffered = True
      ModalResult = 1
      ParentDoubleBuffered = False
      TabOrder = 1
    end
    object FakeFileCheckBox: TCheckBox
      AlignWithMargins = True
      Left = 8
      Top = 3
      Width = 201
      Height = 26
      Margins.Left = 8
      Align = alLeft
      Caption = 'Fake FileName'
      TabOrder = 2
    end
  end
  object OpenDialog: TFileOpenDialog
    DefaultExtension = 'DLL'
    FavoriteLinks = <>
    FileTypes = <
      item
        DisplayName = 'Experts (*.dll)'
        FileMask = '*.dll'
      end>
    Options = [fdoStrictFileTypes, fdoFileMustExist]
    Title = 'Select Experts'
    Left = 372
    Top = 16
  end
  object ActionList: TActionList
    Left = 252
    Top = 20
    object OKAction: TAction
      Caption = 'OK'
      OnExecute = OKActionExecute
      OnUpdate = OKActionUpdate
    end
    object SelectFileAction: TAction
      Caption = '...'
      OnExecute = SelectFileActionExecute
    end
  end
end
