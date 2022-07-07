object webInstagram: TwebInstagram
  Left = 0
  Top = 0
  Caption = 'Eater: Instagram'
  ClientHeight = 299
  ClientWidth = 635
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 635
    Height = 25
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblURL: TLabel
      Left = 215
      Top = 6
      Width = 12
      Height = 13
      Caption = '...'
    end
    object btnLoginDone: TButton
      Left = 0
      Top = 0
      Width = 153
      Height = 25
      Caption = 'Login here, then click here.'
      TabOrder = 0
      OnClick = btnLoginDoneClick
    end
    object btnSkip: TButton
      Left = 159
      Top = 0
      Width = 50
      Height = 25
      Caption = 'Skip'
      TabOrder = 1
      OnClick = btnSkipClick
    end
  end
  object EdgeBrowser1: TEdgeBrowser
    Left = 0
    Top = 25
    Width = 635
    Height = 274
    Align = alClient
    TabOrder = 1
    OnExecuteScript = EdgeBrowser1ExecuteScript
    OnNavigationCompleted = EdgeBrowser1NavigationCompleted
  end
end
