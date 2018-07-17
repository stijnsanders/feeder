program eater;

uses
  SysUtils,
  ActiveX,
  eater1 in 'eater1.pas',
  SQLite in '..\SQLite.pas',
  SQLiteData in '..\SQLiteData.pas',
  DataLank in '..\DataLank.pas',
  MSXML2_TLB in '..\MSXML2_TLB.pas',
  VBScript_RegExp_55_TLB in '..\VBScript_RegExp_55_TLB.pas';

{$R *.res}
{$APPTYPE CONSOLE}

begin
  try
    CoInitialize(nil);
    DoUpdateFeeds;
  except
    on e:Exception do
     begin
      Writeln(ErrOutput,'['+e.ClassName+']'+e.Message);
      ExitCode:=1;
     end;
  end;
end.
