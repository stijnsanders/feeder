program express;

uses
  SysUtils,
  ActiveX,
  WinHttp_TLB in 'WinHttp_TLB.pas',
  LibPQ in '..\LibPQ.pas',
  LibPQData in '..\LibPQData.pas',
  DataLank in '..\DataLank.pas',
  express1 in 'express1.pas',
  VBScript_RegExp_55_TLB in '..\VBScript_RegExp_55_TLB.pas',
  fCommon in '..\fCommon.pas';

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
