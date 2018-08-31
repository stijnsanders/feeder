program ptrans;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  LibPQ in '..\LibPQ.pas',
  LibPQData in '..\LibPQData.pas',
  SQLite in '..\..\TSQLite\SQLite.pas',
  SQLiteData in '..\..\TSQLite\SQLiteData.pas',
  ptrans1 in 'ptrans1.pas';

begin
  try
    DoTrans;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
