program eater;

uses
  SysUtils,
  Winapi.Windows,
  ActiveX,
  LibPQ in '..\LibPQ.pas',
  LibPQData in '..\LibPQData.pas',
  DataLank in '..\DataLank.pas',
  MSXML2_TLB in '..\MSXML2_TLB.pas',
  VBScript_RegExp_55_TLB in '..\VBScript_RegExp_55_TLB.pas',
  jsonDoc in 'jsonDoc.pas',
  eaterReg in 'eaterReg.pas',
  eaterFeeds in 'eaterFeeds.pas',
  eaterGraphs in 'eaterGraphs.pas',
  eaterUtils in 'eaterUtils.pas',
  eaterSanitize in 'eaterSanitize.pas',
  feedAtom in 'feedAtom.pas',
  feedRSS in 'feedRSS.pas',
  feedRDF in 'feedRDF.pas',
  feedSPARQL in 'feedSPARQL.pas',
  feedInstagram in 'feedInstagram.pas',
  feedSoundCloud in 'feedSoundCloud.pas',
  feedRSSinJSON in 'feedRSSinJSON.pas',
  feedWPv2 in 'feedWPv2.pas',
  feedJSON in 'feedJSON.pas',
  feedTitanium in 'feedTitanium.pas',
  feedFusion in 'feedFusion.pas',
  feedNextData in 'feedNextData.pas',
  eaterRun in 'eaterRun.pas',
  feedHTML in 'feedHTML.pas',
  feedNatGeo in 'feedNatGeo.pas',
  feedRemix in 'feedRemix.pas';

{$R *.res}
{$APPTYPE CONSOLE}

var
  h:THandle;
  r:TEaterRunner;
begin
  try
    h:=CreateMutex(nil,true,'Global\FeederEater');
    if h=0 then RaiseLastOSError;
    try
      if GetLastError=ERROR_ALREADY_EXISTS then
        raise Exception.Create('Another running instance of Eater detected.');
      CoInitialize(nil);

      r:=TEaterRunner.Create;
      try
        r.RunFeedEater;
      finally
        r.Free;
      end;

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
