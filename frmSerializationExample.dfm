object Form8: TForm8
  Left = 0
  Top = 0
  Caption = 'Form8'
  ClientHeight = 500
  ClientWidth = 749
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object Memo1: TMemo
    Left = 24
    Top = 72
    Width = 665
    Height = 345
    Lines.Strings = (
      'Memo1')
    ScrollBars = ssBoth
    TabOrder = 0
  end
  object Button1: TButton
    Left = 24
    Top = 22
    Width = 75
    Height = 25
    Caption = 'serialize'
    TabOrder = 1
    OnClick = Button1Click
  end
end
