program eater;

uses
  SysUtils,
  Winapi.Windows,
  ActiveX,
  eater1 in 'eater1.pas',
  LibPQ in '..\LibPQ.pas',
  LibPQData in '..\LibPQData.pas',
  DataLank in '..\DataLank.pas',
  MSXML2_TLB in '..\MSXML2_TLB.pas',
  VBScript_RegExp_55_TLB in '..\VBScript_RegExp_55_TLB.pas',
  jsonDoc in 'jsonDoc.pas',
  eater2 in 'eater2.pas';

{$R *.res}
{$APPTYPE CONSOLE}

var
  h:THandle;
  n:boolean;
begin
  try
    h:=CreateMutex(nil,true,'Global\FeederEater');
    if h=0 then RaiseLastOSError;
    try
      if GetLastError=ERROR_ALREADY_EXISTS then
        raise Exception.Create('Another running instance of Eater detected.');
      CoInitialize(nil);
      DoProcessParams;
      repeat
        n:=FeedNew;

        DoUpdateFeeds;

        if not(n) then DoCharts;

        //DoAnalyze;

      until DoCheckRunDone;
    finally
      CloseHandle(h);
    end;
  except
    on e:Exception do
     begin
      ErrLn('['+e.ClassName+']'+e.Message);
      ExitCode:=1;
     end;
  end;
end.
