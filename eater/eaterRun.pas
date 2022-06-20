unit eaterRun;

interface

type
  TEaterRunner=class(TObject)
  private
    NewFeedEvent:THandle;
    StartRun,LastRun,LastDone:TDateTime;
    LastFeedCount,LastPostCount:integer;

    //configuration
    SaveData,FeedAll,FeedNew:boolean;
    RunContinuous,SpecificFeedID:integer;
    FeedLike:string;

    procedure FlagNewFeed(Sender:TObject);
    function CheckRunDone:boolean;
  public
    procedure RunFeedEater;
    constructor Create;
  end;

implementation

uses Windows, SysUtils, Classes, eaterSanitize, eaterFeeds, eaterUtils, LibPQ;

{ TEaterRunner }

constructor TEaterRunner.Create;
var
  s,t:string;
  i:integer;
begin
  inherited Create;

  //defaults
  SaveData:=false;
  RunContinuous:=0;
  SpecificFeedID:=0;
  FeedAll:=false;
  FeedNew:=false;
  FeedLike:='';
  NewFeedEvent:=0;

  StartRun:=UtcNow;//?
  LastFeedCount:=0;
  LastPostCount:=0;

  //process command line arguments
  for i:=1 to ParamCount do
   begin
    s:=ParamStr(i);
    if s='/s' then SaveData:=true
    else
    if s='/n' then FeedNew:=true
    else
    if s='/c' then RunContinuous:=15
    else
    if StartsWithX(s,'/c',t) then RunContinuous:=StrToInt(t)
    else
    if StartsWithX(s,'/f',t) then SpecificFeedID:=StrToInt(t)
    else
    if StartsWithX(s,'/g',t) then FeedLike:=t
    else
    if s='/x' then FeedAll:=true
    else
      raise Exception.Create('Unknown parameter #'+IntToStr(i));
   end;

  //other initialization

  SanitizeInit;

  s:=ExtractFilePath(ParamStr(0))+'blacklist.txt';
  if FileExists(s) then BlackList.LoadFromFile(s);

end;

procedure TEaterRunner.FlagNewFeed(Sender: TObject);
begin
  if NewFeedEvent<>0 then
    SetEvent(NewFeedEvent);
end;

procedure TEaterRunner.RunFeedEater;
var
  f:TFeedEater;
  r:TFeedEatResult;
  n:boolean;
begin
  repeat
    LastRun:=UtcNow;
    n:=FeedNew;
    f:=TFeedEater.Create;
    try
      IUnknown(f)._AddRef;//prevent destruction on first _Release

      f.DoCleanup;
      f.DoAutoUnread;

      if FeedNew then
       begin
        SpecificFeedID:=Specific_NewFeeds;
        FeedNew:=false;//only once
       end;

      f.SaveData:=SaveData;
      f.ForceLoadAll:=FeedAll;
      f.OnFeedURLUpdate:=FlagNewFeed;
      r:=f.DoUpdateFeeds(SpecificFeedID,FeedLike,(RunContinuous+5)/1440.0);

      LastDone:=UtcNow;
      LastFeedCount:=r.FeedCount;
      LastPostCount:=r.PostCount;

      if not(n) then f.RenderGraphs;

    finally
      IUnknown(f)._Release;//f.Free;
    end;

    //DoAnalyze;

  until CheckRunDone;
end;

function TEaterRunner.CheckRunDone: boolean;
var
  RunNext,d:TDateTime;
  i:integer;
  h:array[0..1] of THandle;
  b:TInputRecord;
  c:cardinal;
  checking:boolean;
begin
  if RunContinuous=0 then
    Result:=true
  else
   begin
    RunNext:=LastRun+RunContinuous/1440.0;
    SpecificFeedID:=0;//only once
    FeedAll:=false;//only once
    d:=UtcNow;
    while d<RunNext do
     begin
      i:=Round((RunNext-d)*86400.0);
      Write(Format(#13'Waiting %.2d:%.2d  ',[i div 60,i mod 60]));
      //TODO: check std-in?
      //Result:=Eof(Input);
      Sleep(1000);//?
      d:=UtcNow;

      if NewFeedEvent=0 then
        NewFeedEvent:=CreateEvent(nil,true,false,'Global\FeederEaterNewFeed');

      checking:=true;
      h[0]:=GetStdHandle(STD_INPUT_HANDLE);
      h[1]:=NewFeedEvent;
      while checking do
        case WaitForMultipleObjects(2,@h[0],false,0) of
          WAIT_OBJECT_0://STD_INPUT_HANDLE
           begin
            if not ReadConsoleInput(h[0],b,1,c) then
              RaiseLastOSError;
            if (c<>0) and (b.EventType=KEY_EVENT) and b.Event.KeyEvent.bKeyDown then
              case b.Event.KeyEvent.AsciiChar of
                's'://skip
                 begin
                  Writeln(#13'Manual skip    ');
                  d:=RunNext;
                  checking:=false;
                 end;
                'n'://skip + new
                 begin
                  Writeln(#13'Skip + new feeds   ');
                  d:=RunNext;
                  FeedNew:=true;
                  checking:=false;
                 end;
                'x'://skip + run all
                 begin
                  Writeln(#13'Skip + all feeds   ');
                  d:=RunNext;
                  FeedAll:=true;
                  checking:=false;
                 end;
{
                'a'://analyze on next
                  if NextAnalyze then
                   begin
                    NextAnalyze:=false;
                    Writeln(#13'Analyze after next load: disabled');
                   end
                  else
                   begin
                    NextAnalyze:=true;
                    Writeln(#13'Analyze after next load: enabled');
                   end;
}
                'd'://diagnostics
                 begin
                  Writeln(#13'Diagnostics:  ');
                  Writeln('  Running since (UTC) '+DateTimeToStr(StartRun));
                  Writeln('  Last load (UTC) '+DateTimeToStr(LastRun));
                  i:=Round((LastRun-LastRun)*86400.0);
                  Writeln(Format('  %d posts from %d feeds (%d''%d")',
                    [LastPostCount,LastFeedCount,i div 60,i mod 60]));
                  //TODO: more?
                 end;
                'v'://version
                 begin
                  Writeln(#13'Versions:    ');
                  //Writeln(SelfVersion);
                  i:=PQlibVersion;
                  Writeln(Format('PQlibVersion: %d.%d',[i div 10000,i mod 10000]));
                  if PGVersion<>'' then
                    Writeln('PostgreSQL version: '+PGVersion);
                 end;
                'q'://quit
                 begin
                  Writeln(#13'User abort    ');
                  raise Exception.Create('User abort');
                 end;
                else
                  Writeln(#13'Unknown code "'+b.Event.KeyEvent.AsciiChar+'"');
              end;

           end;

          WAIT_OBJECT_0+1://NewFeed event
           begin
            ResetEvent(h[1]);

            Writeln(#13'Signal from front-end:  new feeds   ');
            d:=RunNext;
            FeedNew:=true;
            checking:=false;
           end;

          else
            checking:=false;
        end;

     end;
    Writeln(#13'>>> '+FormatDateTime('yyyy-mm-dd hh:nn:ss',d));

    Result:=false;
   end;
end;

end.
