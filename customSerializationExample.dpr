program customSerializationExample;

uses
  Vcl.Forms,
  frmSerializationExample in 'frmSerializationExample.pas' {Form8},
  serialization in 'serialization.pas',
  reflections in 'reflections.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm8, Form8);
  Application.Run;
end.
