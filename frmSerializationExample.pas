unit frmSerializationExample;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, SynCommons, mORMot, system.rtti;

type
  TDecimal2 = type Currency;
  TDecimal3 = type Currency;

  TTestClass = class
  public
    str: string;
    dateTime: TDateTime;
    decimal2: TDecimal2;
    decimal3: TDecimal3;
  end;

  TTestClass2 = class
  public
    int: integer;
    str: string;
    date: TDate;
    decimal2: TDecimal2;
    curr: Currency;
  end;

  TCrazySerializer = class
  private
    class procedure CrazyDecimalWriter(const aSerializer: TJSONSerializer; aValue: TValue; aOptions: TTextWriterWriteObjectOptions; precision: byte);
  public
    class function CrazyDecimalReader(const aValue: TObject; aFrom: PUTF8Char; var aValid: Boolean; aOptions: TJSONToObjectOptions): PUTF8Char;
    class procedure CrazyDecimal2Writer(const aSerializer: TJSONSerializer; aValue: TValue; aOptions: TTextWriterWriteObjectOptions);
    class procedure CrazyDecimal3Writer(const aSerializer: TJSONSerializer; aValue: TValue; aOptions: TTextWriterWriteObjectOptions);
  end;

  TForm8 = class(TForm)
    Memo1: TMemo;
    Button1: TButton;
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form8: TForm8;

implementation

{$R *.dfm}

uses
  serialization;

procedure TForm8.Button1Click(Sender: TObject);
var
  dummy: TTestClass;
  dummy2: TTestClass2;
  s: string;
begin
  memo1.clear;

  TSerializer.RegisterCustomType(TypeInfo(TDecimal2), TCrazySerializer.CrazyDecimalReader, TCrazySerializer.CrazyDecimal2Writer);
  TSerializer.RegisterCustomType(TypeInfo(TDecimal3), TCrazySerializer.CrazyDecimalReader, TCrazySerializer.CrazyDecimal3Writer);

  dummy := TTestClass.Create;
  dummy.decimal2 := 123.45;
  dummy.decimal3 := 876.1234;
  dummy.str := 'test1';
  dummy.dateTime := now;

  dummy2 := TTestClass2.Create;
  dummy2.decimal2 := 234.5;
  dummy2.curr := 876.12;
  dummy2.str := 'test2';
  dummy2.date := now;
  dummy2.int := 123;

  try
    memo1.lines.add('TTestClass object:');
    memo1.lines.add(TSerializer.ObjectToJSON(dummy));

    memo1.lines.add('');
    memo1.lines.add('TTestClass2 object:');
    memo1.lines.add(TSerializer.ObjectToJSON(dummy2));
  finally
    dummy.Free;
    dummy2.Free;
  end;
end;

{ TCrazySerializer }

class function TCrazySerializer.CrazyDecimalReader(const aValue: TObject; aFrom: PUTF8Char; var aValid: Boolean; aOptions: TJSONToObjectOptions): PUTF8Char;
begin
//
end;

class procedure TCrazySerializer.CrazyDecimalWriter(const aSerializer: TJSONSerializer; aValue: TValue;
  aOptions: TTextWriterWriteObjectOptions; precision: byte);
const
  powers: array[0..4] of integer = (1, 10, 100, 1000, 10000);
var
  lVal: string;
begin
  if precision > 4 then
    precision := 4;

  // we write value as integer (without decimal part) and as first digit we add precision
  lVal := IntToStr(precision) + IntToStr(trunc(powers[precision] * aValue.asCurrency));
  aSerializer.Add('"');
  aSerializer.AddString(lval);
  aSerializer.Add('"');
end;

class procedure TCrazySerializer.CrazyDecimal2Writer(const aSerializer: TJSONSerializer; aValue: TValue; aOptions: TTextWriterWriteObjectOptions);
begin
  CrazyDecimalWriter(aSerializer, aValue, aOptions, 2);
end;

class procedure TCrazySerializer.CrazyDecimal3Writer(const aSerializer: TJSONSerializer; aValue: TValue; aOptions: TTextWriterWriteObjectOptions);
begin
  CrazyDecimalWriter(aSerializer, aValue, aOptions, 3);
end;

end.
