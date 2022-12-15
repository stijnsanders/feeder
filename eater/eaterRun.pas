unit eaterRun;

interface

type
  TEaterRunner=class(TObject)
  private
    NewFeedEvent:THandle;
    StartRun,LastRun,LastDone:TDateTime;
    LastFeedCount,LastPostCount:integer;

    //configuration
    SaveData:boolean;
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
    if s='/n' then SpecificFeedID:=Specific_NewFeeds
    else
    if s='/c' then RunContinuous:=15
    else
    if StartsWithX(s,'/c',t) then RunContinuous:=StrToInt(t)
    else
    if StartsWithX(s,'/f',t) then SpecificFeedID:=StrToInt(t)
    else
    if StartsWithX(s,'/g',t) then FeedLike:=t
    else
    if s='/x' then SpecificFeedID:=Specific_AllFeeds
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
    n:=SpecificFeedID=0;
    f:=TFeedEater.Create;
    try
      IUnknown(f)._AddRef;//prevent destruction on first _Release

      f.DoCleanup;
      f.DoAutoUnread;
      f.SaveData:=SaveData;
      f.ForceLoadAll:=SpecificFeedID=Specific_AllFeeds;
      f.OnFeedURLUpdate:=FlagNewFeed;
      r:=f.DoUpdateFeeds(SpecificFeedID,FeedLike,(RunContinuous+5)/1440.0);

      LastDone:=UtcNow;
      LastFeedCount:=r.FeedCount;
      LastPostCount:=r.PostCount;

      if n then f.RenderGraphs;

    finally
      IUnknown(f)._Release;//f.Free;
    end;

    //DoAnalyze;

  until CheckRunDone;
end;

function TEaterRunner.CheckRunDone: boolean;
var
  RunNext,d:TDateTime;
  i,id:integer;
  h:array[0..1] of THandle;
  b:TInputRecord;
  c:cardinal;
  checking:boolean;
  c0,c1:AnsiChar;
begin
  if RunContinuous=0 then
    Result:=true
  else
   begin
    RunNext:=LastRun+RunContinuous/1440.0;
    SpecificFeedID:=0;//only once
    id:=0;
    d:=UtcNow;
    while d<RunNext do
     begin
      i:=Round((RunNext-d)*86400.0);
      if id=0 then
        Write(Format(#13'Waiting %.2d:%.2d  ',[i div 60,i mod 60]))
      else
        Write(Format(#13'Waiting %.2d:%.2d ? %d   ',[i div 60,i mod 60,id]));
      //TODO: check std-in?
      //Result:=Eof(Input);
      Sleep(1000);//?
      d:=UtcNow;

      if NewFeedEvent=0 then
        NewFeedEvent:=CreateEvent(nil,true,false,'Global\FeederEaterNewFeed');

      checking:=true;
      c1:=#0;
      h[0]:=GetStdHandle(STD_INPUT_HANDLE);
      h[1]:=NewFeedEvent;
      while checking do
        case WaitForMultipleObjects(2,@h[0],false,0) of
          WAIT_OBJECT_0://STD_INPUT_HANDLE
           begin
            if not ReadConsoleInput(h[0],b,1,c) then
              RaiseLastOSError;
            if (c<>0) and (b.EventType=KEY_EVENT) and b.Event.KeyEvent.bKeyDown then
             begin
              c0:=c1;
              c1:=b.Event.KeyEvent.AsciiChar;
              case c1 of
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
                  SpecificFeedID:=Specific_NewFeeds;
                  checking:=false;
                 end;
                'x'://skip + run all
                 begin
                  Writeln(#13'Skip + all feeds   ');
                  d:=RunNext;
                  SpecificFeedID:=Specific_AllFeeds;
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
                'i'://reset instagram
                  if c0='i' then
                   begin
                    Writeln(#13'Reset Instagram timers');
                    InstagramLastTC:=GetTickCount-InstagramIntervalMS;
                    InstagramFailed:=0.0;
                   end
                  else
                   begin
                    Writeln(#13'Instagram timers: (press "i" again to reset)');
                    Writeln('  Instagram last (UTC) '+DateTimeToStr(UtcNow-
                      cardinal(GetTickCount-InstagramLastTC)/MSecsPerDay));
                    if InstagramFailed<>0.0 then
                      Writeln('  Instagram failed (UTC) '+DateTimeToStr(InstagramFailed));
                   end;

                '0'..'9':
                  id:=id*10+(byte(c1) and $F);
                'c'://clear
                  id:=0;
                #8:
                  id:=id div 10;
                'f'://feed
                  if id=0 then
                   begin
                    Writeln(#13'No feed id entered  ');
                   end
                  else
                   begin
                    Writeln(#13'Skip + feed #'+IntToStr(id)+'   ');
                    d:=RunNext;
                    SpecificFeedID:=id;
                    checking:=false;
                   end;

                'd'://diagnostics
                 begin
                  Writeln(#13'Diagnostics:  ');
                  Writeln('  Running since (UTC) '+DateTimeToStr(StartRun));
                  Writeln('  Last load (UTC) '+DateTimeToStr(LastRun));
                  i:=Round((LastDone-LastRun)*86400.0);
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
                  Writeln(#13'Unknown code "'+c1+'"');
              end;
             end;
           end;

          WAIT_OBJECT_0+1://NewFeed event
           begin
            ResetEvent(h[1]);

            Writeln(#13'Signal from front-end:  new feeds   ');
            d:=RunNext;
            SpecificFeedID:=Specific_NewFeeds;
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
