program express;

uses
  SysUtils,
  ActiveX,
  LibPQ in '..\LibPQ.pas',
  LibPQData in '..\LibPQData.pas',
  DataLank in '..\DataLank.pas',
  express1 in 'express1.pas',
  VBScript_RegExp_55_TLB in '..\VBScript_RegExp_55_TLB.pas',
  fCommon in '..\fCommon.pas',
  MSXML2_TLB in '..\MSXML2_TLB.pas';

{$R *.res}
{$APPTYPE CONSOLE}

begin
  try
    CoInitialize(nil);

    BuildExpress;

  except
    on e:Exception do
     begin
      ExitCode:=9;
      Writeln(ErrOutput,'['+e.ClassName+']'+e.Message);
     end;
  end;
end.
