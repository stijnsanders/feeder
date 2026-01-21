unit eaterFeeds;

interface

uses Classes, DataLank, eaterReg, jsonDoc;

type
  TFeedEatResult=record
    FeedCount,PostCount:integer;
  end;

  TFeedEater=class(TInterfacedObject, IFeedStore, IFeedHandler)
  private
    FDB,FDBStats:TDataConnection;
    FReport:TStringList;
    FPostID:string;
    FPostURL:WideString;
    FPostPubDate:TDateTime;
    FPostTags:Variant;
    FPostTagPrefix:string;
    FFeed:record
      id,group_id:integer;
      URL,URL0,URLSkip,Name,Name0,LastMod,LastMod0,Result,Result0:string;
      Regime,TotalCount:integer;
      LoadStart,LoadLast:TDateTime;
      NotModified:boolean;
    end;
    FPostsTotal,FPostsNew:integer;
    FHasReplaces:boolean;
    FCookies:TStringList;
    FConfig:IJSONDocument;
    OldPostsCutOff:TDateTime;
    function LoadExternal(const URL,FilePath,LastMod,Accept:string):WideString;
    function ParseExternalHeader(var content:WideString):WideString;
    function FeedSkipDisplay(d:TDateTime):string;
    procedure PerformReplaces(var title,content:WideString);
    procedure PerformGlobalReplaces(var data:WideString);
    procedure FeedCombineURL(const url,lbl:string);
    function FindFeedURL(const data:WideString):boolean;
    procedure CheckCookie(const url:string;var s1,s2:string);
    procedure SetCookie(const s1,s2:string);
    //IFeedStore
    function CheckLastLoadResultPrefix(const Prefix:string):boolean;
    //IFeedHandler
    function CheckNewPost(const PostID:string;const PostURL:WideString;
      PostPubDate:TDateTime):boolean;
    procedure UpdateFeedName(const NewName:string);
    function GetConfig(const Key:string):string;
    procedure PostTags(const TagPrefix:string;const Tags:Variant);
    procedure RegisterPost(const PostTitle,PostContent:WideString);
    procedure ReportSuccess(const Lbl:string);
    procedure ReportFailure(const Msg:string);
  public
    ForceLoadAll,SaveData:boolean;
    OnFeedURLUpdate:TNotifyEvent;
    constructor Create;
    destructor Destroy; override;
    procedure DoCleanup;
    procedure DoAutoUnread;
    function DoUpdateFeeds(SpecificFeedID:integer;const FeedLike:string;
      PubDateMargin:double):TFeedEatResult;
    procedure RenderGraphs;
  end;

const
  Specific_NewFeeds=-111;
  Specific_AllFeeds=-113;
  Specific_GroupID=-199;

var
  PGVersion:string;
  BlackList:TStringList;
  InstagramLastTC:cardinal;
  InstagramFailed:TDateTime;

const
  InstagramIntervalMS=30000;
  InstagramCoolDown=2.1;//48h +margin

implementation

uses Windows, SysUtils, Variants, ComObj, eaterUtils, eaterSanitize, MSXML2_TLB,
  VBScript_RegExp_55_TLB, eaterGraphs;

const
  FeederIniPath='..\..\feeder.ini';
  EaterIniPath='..\..\feeder_eater.ini';
  //TODO: from ini?
  FeedLoadReport='..\Load.html';
  AvgPostsDays=500;
  OldPostsDays=3660;

  regimesteps=12;
  regimestep:array[0..regimesteps-1] of integer=(1,2,3,7,14,30,60,90,120,150,200,360);

function qrDate(qr:TQueryResult;const Idx:Variant):TDateTime;
var
  v:Variant;
begin
  v:=qr[Idx];
  if VarIsNull(v) then
    Result:=0
  else
    Result:=double(v);
end;

{ TFeedEater }

constructor TFeedEater.Create;
var
  sl:TStringList;
  constr:string;
  qr:TQueryResult;
begin
  inherited Create;

  OutLn('Opening databases...');

  sl:=TStringList.Create;
  try
    sl.LoadFromFile(FeederIniPath);
    constr:=sl.Text;
  finally
    sl.Free;
  end;
  FDB:=TDataConnection.Create(constr);
  FDBStats:=TDataConnection.Create(constr);

  if PGVersion='' then //?
   begin
    qr:=TQueryResult.Create(FDB,'select version()',[]);
    try
      if qr.Read then PGVersion:=qr.GetStr(0);
    finally
      qr.Free;
    end;
   end;

  FReport:=TStringList.Create;
  FReport.DefaultEncoding:=TEncoding.UTF8;
  OldPostsCutOff:=UtcNow-OldPostsDays;
  ForceLoadAll:=false;//default
  SaveData:=false;//default
  OnFeedURLUpdate:=nil;
  FCookies:=TStringList.Create;//TODO: LoadFromFile?
end;

destructor TFeedEater.Destroy;
begin
  FDB.Free;
  FDBStats.Free;
  FCookies.Free;//TODO: SaveToFile?
  inherited;
end;

procedure TFeedEater.DoCleanup;
var
  qr:TQueryResult;
  i,j:integer;
begin
  Out0('Clean-up old...');
  qr:=TQueryResult.Create(FDBStats,'select id from "Post" where pubdate<$1',[double(OldPostsCutOff)]);
  try

    j:=0;
    while qr.Read do
     begin
      i:=qr.GetInt('id');
      FDB.BeginTrans;
      try
        FDB.Execute('delete from "UserPost" where post_id=$1',[i]);
        FDB.Execute('delete from "Opinion" where post_id=$1',[i]);
        FDB.Execute('delete from "Post" where id=$1',[i]);
        FDB.CommitTrans;
      except
        FDB.RollbackTrans;
        raise;
      end;
      inc(j);
     end;
    Writeln(' '+IntToStr(j)+' posts cleaned      ');

  finally
    qr.Free;
  end;

  Out0('Clean-up unused...');
  qr:=TQueryResult.Create(FDBStats,'select id from "Feed" where id>0'+
    ' and not exists (select S.id from "Subscription" S where S.feed_id="Feed".id)',[]);
  try
    j:=0;
    while qr.Read do
     begin
      i:=qr.GetInt('id');
      Write(#13'... #'+IntToStr(i)+'   ');
      FDB.BeginTrans;
      try
        FDB.Execute('delete from "UserPost" where post_id in (select P.id from "Post" P where P.feed_id=$1)',[i]);
        FDB.Execute('delete from "Opinion" where post_id in (select P.id from "Post" P where P.feed_id=$1)',[i]);
        FDB.Execute('delete from "Post" where feed_id=$1',[i]);
        FDB.Execute('delete from "Feed" where id=$1',[i]);
        FDB.CommitTrans;
      except
        FDB.RollbackTrans;
        raise;
      end;
      inc(j);
     end;
    Writeln(' '+IntToStr(j)+' feeds cleaned      ');

  finally
   qr.Free;
  end;
end;

procedure TFeedEater.DoAutoUnread;
var
  qr:TQueryResult;
  i:integer;
begin
  Out0('Auto-unread after...');
  qr:=TQueryResult.Create(FDBStats,'select X.id from "Subscription" S'
    +' inner join "UserPost" X on X.subscription_id=S.id'
    +' where S.autounread is not null'
    +' and X.pubdate<$1-S.autounread/24.0 limit 1',[double(UtcNow)]);
  try
    if qr.EOF then i:=0 else i:=1;
  finally
    qr.Free;
  end;
  if i=0 then
    Writeln(' none')
  else
   begin
    FDB.BeginTrans;
    try
      i:=FDB.Execute('delete from "UserPost" where id in (select X.id'
        +' from "Subscription" S'
        +' inner join "UserPost" X on X.subscription_id=S.id'
        +' where S.autounread is not null'
        +' and X.pubdate<$1-S.autounread/24.0)',[double(UtcNow)]);
      FDB.CommitTrans;
    except
      FDB.RollbackTrans;
      raise;
    end;
    Writeln(' '+IntToStr(i)+' items marked read');
   end;
end;

function TFeedEater.DoUpdateFeeds(SpecificFeedID:integer;const FeedLike:string;
  PubDateMargin:double):TFeedEatResult;
var
  qr:TQueryResult;
  ids:array of integer;
  ids_i,ids_l:integer;
  d,oldPostDate:TDateTime;
  sql1,sql2,ss,html1,html2,s1,s2:string;

  postlast,postavg,f:double;
  newfeed,doreq,loadext,xres:boolean;
  r:ServerXMLHTTP60;
  redirCount,sCount,i,j:integer;
  handler_i:cardinal;
  doc:DOMDocument60;

  FeedData,FeedDataType:WideString;

begin
  FReport.Clear;
  //TODO: from embedded resource
  FReport.Add('<style>');
  FReport.Add('P{font-family:"PT Sans","Yu Gothic",Calibri,sans-serif;font-size:0.7em;}');
  FReport.Add('TH{font-family:"PT Sans","Yu Gothic",Calibri,sans-serif;font-size:0.7em;white-space:nowrap;border:1px solid #333333;}');
  FReport.Add('TD{font-family:"PT Sans","Yu Gothic",Calibri,sans-serif;font-size:0.7em;white-space:nowrap;border:1px solid #CCCCCC;}');
  FReport.Add('TD.n{max-width:20em;overflow:hidden;text-overflow:ellipsis;}');
  FReport.Add('TD.empty{background-color:#CCCCCC;}');
  FReport.Add('DIV.flag{display:inline;padding:2pt;color:#FFCC00;border-radius:4pt;white-space:nowrap;}');
  FReport.Add('</style>');
  FReport.Add('<table cellspacing="0" cellpadding="4" border="1">');
  FReport.Add('<tr><th>&nbsp;</th><th>name</th><th title="subscriptions">#</th>');
  FReport.Add('<th>post:avg</th><th>regime</th><th>since</th>');
  FReport.Add('<th>load result</th><th>new</th><th>items</th><th>total</th></tr>');

  try
    OutLn('List feeds for loading...');
    Result.FeedCount:=0;
    Result.PostCount:=0;

    if SpecificFeedID>0 then
     begin
      ids_l:=1;
      SetLength(ids,1);
      ids[0]:=SpecificFeedID;
     end
    else
     begin
      if SpecificFeedID=Specific_NewFeeds then
        qr:=TQueryResult.Create(FDB,'select F.id from "Feed" F where F.id>0'+
          ' and F.created>$1 order by F.id',[UtcNow-1.0])
      else
      if SpecificFeedID<=Specific_GroupID then
        qr:=TQueryResult.Create(FDB,'select F.id from "Feed" F where F.id>0'+
          ' and F.group_id=$1 order by F.id',[Specific_GroupID-SpecificFeedID])
      else if FeedLike<>'' then
        qr:=TQueryResult.Create(FDB,'select F.id from "Feed" F where F.id>0'+
          ' and F.url like $1'+
          ' order by F.id',['%'+FeedLike+'%'])
      else
        qr:=TQueryResult.Create(FDB,'select F.id from "Feed" F where F.id>0'+
          ' order by F.id',[]);
      try
        ids_l:=0;
        ids_i:=0;
        while qr.Read do
         begin
          if ids_i=ids_l then
           begin
            inc(ids_l,$400);//grow step
            SetLength(ids,ids_l);
           end;
          ids[ids_i]:=qr.GetInt('id');
          inc(ids_i);
         end;
        ids_l:=ids_i;
      finally
        qr.Free;
      end;
     end;

    oldPostDate:=UtcNow-AvgPostsDays;
    ids_i:=0;
    while ids_i<ids_l do
     begin
      FFeed.id:=ids[ids_i];
      qr:=TQueryResult.Create(FDB,'select *'
         +' ,(select count(*) from "Subscription" S where S.feed_id=F.id) as scount'
         +' from "Feed" F where F.id=$1',[FFeed.id]);
      try
        if qr.EOF then raise Exception.Create('No feed found for this id.');

        FFeed.group_id:=qr.GetInt('group_id');
        FFeed.URL0:=qr.GetStr('url');
        FFeed.URLSkip:=qr.GetStr('urlskip');
        FFeed.Name0:=qr.GetStr('name');
        FFeed.LastMod0:=qr.GetStr('lastmod');
        FFeed.Result0:=qr.GetStr('result');
        FFeed.Regime:=qr.GetInt('regime');
        FFeed.TotalCount:=qr.GetInt('totalcount');
        FFeed.LoadStart:=UtcNow;
        FFeed.LoadLast:=qrDate(qr,'loadlast');

        FFeed.URL:=FFeed.URL0;
        FFeed.Name:=FFeed.Name0;
        FFeed.LastMod:=FFeed.LastMod0;
        FFeed.Result:='';
        FFeed.NotModified:=false;

        FPostsTotal:=qr.GetInt('itemcount');
        FPostsNew:=qr.GetInt('loadcount');

        newfeed:=qr.IsNull('itemcount');

        Out0('#'+IntToStr(FFeed.id)+' '+DisplayShortURL(FFeed.URL));

        //flags
        //i:=qr0.GetInt('flags');
        //feedglobal:=(i and 1)<>0;
        //TODO: more?

        html1:='<td class="n" title="created: '
          +FormatDateTime('yyyy-mm-dd hh:nn',qrDate(qr,'created'))
          +#13#10'check: '
          +FormatDateTime('yyyy-mm-dd hh:nn:ss',FFeed.LoadStart)
          +'">';
        if FFeed.group_id<>0 then
          html1:=html1+'<div class="flag" style="background-color:red;">'+IntToStr(FFeed.group_id)+'</div>&nbsp;';
        html2:='<td style="text-align:right;">'+VarToStr(qr['scount'])+'</td>';

      finally
        qr.Free;
      end;

      //check feed timing and regime
      qr:=TQueryResult.Create(FDB,
        'select id from "Post" where feed_id=$1 order by 1 desc limit 1 offset 200',[FFeed.id]);
      try
        if qr.EOF then
         begin
          sql1:='';
          sql2:='';
         end
        else
         begin
          sql1:=' and P1.id>'+IntToStr(qr.GetInt('id'));
          sql2:=' and P2.id>'+IntToStr(qr.GetInt('id'));
         end;
      finally
        qr.Free;
      end;
      qr:=TQueryResult.Create(FDB,(//UTF8Encode(
         'select max(X.pubdate) as postlast, avg(X.pd) as postavg'
        +', min(X.pm) as postmedian'
        +' from('
        +'  select'
        +'  P2.pubdate, min(P2.pubdate-P1.pubdate) as pd'
        +'  ,case when cume_dist()over(order by min(P2.pubdate-P1.pubdate))<0.5 then null else min(P2.pubdate-P1.pubdate) end as pm'
        +'  from "Post" P1'
        +'  inner join "Post" P2 on P2.feed_id=P1.feed_id'+sql2+' and P2.pubdate>P1.pubdate+1.0/1440.0'
        +'  where P1.feed_id=$1'+sql1+' and P1.pubdate>$2'
        +'  group by P2.pubdate'
        +' ) X')
      ,[FFeed.id,double(oldPostDate)]);
      try
        if qr.EOF then
         begin
          postlast:=0.0;
          postavg:=0.0;
         end
        else
         begin
          postlast:=qrDate(qr,'postlast');
          postavg:=qrDate(qr,'postmedian');
          if postavg=0.0 then postavg:=qrDate(qr,'postavg');
         end;
      finally
        qr.Free;
      end;

      if postlast=0.0 then
       begin
        if FFeed.LoadLast=0.0 then
          d:=FFeed.LoadStart-PubDateMargin
        else
          d:=FFeed.LoadLast+FFeed.Regime;
       end
      else
       begin
        d:=postlast+postavg-PubDateMargin;
        if (FFeed.LoadLast<>0.0) and (d<FFeed.LoadLast) then
          d:=FFeed.LoadLast+FFeed.Regime-PubDateMargin;
       end;

      //proceed with this feed?
      if (d<FFeed.LoadStart) or ForceLoadAll or (SpecificFeedID>0) then
       begin

        //load feed data
        loadext:=FileExists('feeds\'+Format('%.4d',[FFeed.id])+'.txt');
        try

          //TODO: move these into specific feed handlers

          if (FFeed.Result0<>'') and (FFeed.Result0[1]='[') then
            FFeed.Result0:='';

          if (FFeed.Result0='') and StartsWith(FFeed.URL,'https://www.youtube.com') then
            SanitizeYoutubeURL(FFeed.URL);

          //TODO: move this to feedInstagram.pas
          if StartsWithX(FFeed.URL,'http://www.instagram.com/',ss) then
            FFeed.URL:='https://instagram.com'+ss;
          if StartsWithX(FFeed.URL,'http://instagram.com/',ss) then
            FFeed.URL:='https://instagram.com'+ss;
          if (StartsWith(FFeed.URL,'https://www.instagram.com/') or
            StartsWith(FFeed.URL,'https://instagram.com/')) then
           begin
            if (InstagramFailed<>0.0) and (UtcNow>InstagramFailed) then InstagramFailed:=0.0;
            if InstagramFailed=0.0 then
             begin
              r:=CoServerXMLHTTP60.Create;
              if not(FFeed.URL[Length(FFeed.URL)]='/') then FFeed.URL:=FFeed.URL+'/';
              if not StartsWithX(FFeed.Name,'instagram:',ss) then
               begin
                Write('?');
                r.open('GET',FFeed.URL,false,EmptyParam,EmptyParam);
                r.send(EmptyParam);
                if r.status<>200 then
                  raise Exception.Create('[HTTP:'+IntToStr(r.status)+']'+r.statusText);
                FeedData:=r.responseText;
                i:=Pos(WideString('"profile_id":"'),FeedData);
                if i=0 then
                  raise Exception.Create('Instagram: no profile_id found')
                else
                 begin
                  inc(i,14);
                  j:=i;
                  while (j<=Length(FeedData)) and (FeedData[j]<>'"') do inc(j); //and FeedData[j] in ['0'..'9']?
                  ss:=Copy(FeedData,i,j-i);
                  FFeed.Name:='instagram:'+ss;
                  InstagramLastTC:=GetTickCount-(InstagramLastTC div 2);
                 end;
               end;

              //space requests
              while cardinal(GetTickCount-InstagramLastTC)<InstagramIntervalMS do
               begin
                Write(Format(' %.2d"',[(InstagramIntervalMS-
                  cardinal(GetTickCount-InstagramLastTC)+500) div 1000])+#8#8#8#8);
                Sleep(1000);
               end;

              Write('.   '#8#8#8);
              if newfeed then i:=32 else i:=8;//new?
              r.open('GET','https://www.instagram.com/graphql/query/?doc_id=7950326061742207'
                +'&variables=%7B%22id%22%3A%22'+ss+'%22%2C%22first%22%3A'+IntToStr(i)+'%7D'
                ,false,EmptyParam,EmptyParam);
              r.setRequestHeader('Accept','application/json');
              r.setRequestHeader('Cookie','csrftoken=r0E0o6p76cxSWJma3DcrEt1EyS40wwdA');
              r.setRequestHeader('X-CSRFToken','r0E0o6p76cxSWJma3DcrEt1EyS40wwdA');
              //'x-ig-app-id'?
              r.send(EmptyParam);
              if r.status=200 then
               begin
                Write(':');
                FeedData:=r.responseText;
                //FeedDataType:='application/json';
                FeedDataType:=r.getResponseHeader('Content-Type');
                if SaveData then
                  SaveUTF16('xmls\'+Format('%.4d',[FFeed.id])+'.json',FeedData);
               end
              else
              if r.status=401 then
               begin
                InstagramFailed:=UtcNow+InstagramCoolDown;
                //SaveUTF16('xmls\'+Format('%.4d',[FFeed.id])+'.txt',r.getAllResponseHeaders+#13#10#13#10+r.responseText);
                FFeed.Result:='(Instagram '+IntToStr(Round((InstagramFailed-UtcNow)*1440.0))+'''.)';
               end
              else
               begin
                FFeed.Result:='[HTTP:'+IntToStr(r.status)+']'+r.statusText;
               end;
              r:=nil;
              InstagramLastTC:=GetTickCount;
             end
            else
              FFeed.Result:='(Instagram '+IntToStr(Round((InstagramFailed-UtcNow)*1440.0))+''')';
           end
          else

          if loadext then
           begin
            FeedData:=LoadExternal(FFeed.URL,
              'xmls\'+Format('%.4d',[FFeed.id])+'.xml',
              FFeed.LastMod,
              'application/rss+xml, application/atom+xml, application/xml, application/json, text/xml');
            FeedDataType:=ParseExternalHeader(FeedData);
           end
          else
           begin
            redirCount:=0;
            doreq:=true;
            while doreq do
             begin
              Write(':');
              r:=CoServerXMLHTTP60.Create;

              handler_i:=0;
              while (handler_i<RequestProcessorsIndex) and doreq do
                if RequestProcessors[handler_i].AlternateOpen(FFeed.URL,FFeed.LastMod,r) then
                  doreq:=false
                else
                  inc(handler_i);
              if doreq then //if (handler_i=RequestProcessors) then
               begin
                doreq:=false;
                r.open('GET',FFeed.URL,false,EmptyParam,EmptyParam);
                r.setRequestHeader('User-Agent','FeedEater/1.1');
                CheckCookie(FFeed.URL,s1,s2);
                if s2='' then
                 begin
                  r.setRequestHeader('Accept','application/rss+xml, application/atom+xml, application/xml, application/json, text/xml');
                  r.setRequestHeader('Cache-Control','no-cache, no-store, max-age=0');
                  if Pos('/microsoft/o365/custom-blog-rss',FFeed.URL)<>0 then //?
                    r.setRequestHeader('Accept-Language','en,en-US');
                 end
                else
                 begin
                  r.setRequestHeader('Cookie',s2);
                 end;
               end;

              //TODO: ...'/wp/v2/posts' param 'after' last load time?
              if (FFeed.LastMod<>'') and not(ForceLoadAll) then
                r.setRequestHeader('If-Modified-Since',FFeed.LastMod);
              r.send(EmptyParam);

              //moved permanently?
              if (r.status=301) or (r.status=302) or (r.status=308) then
               begin
                FFeed.URL:=r.getResponseHeader('Location');
                doreq:=true;
                inc(redirCount);
                if redirCount=8 then
                  raise Exception.Create('Maximum number of redirects reached');
               end;

              //datadome support
              if (r.status=401) and (r.getResponseHeader('x-datadome')='protected') then
               begin
                SetCookie(s1,r.getResponseHeader('Set-Cookie'));
                doreq:=true;
                inc(redirCount);
                if redirCount=24 then
                  raise Exception.Create('Maximum number of attempts reached');
               end;

             end;
            if r.status=200 then
             begin

              Write(':');
              FeedData:=r.responseText;
              //:=r.getAllResponseHeaders;
              FeedDataType:=r.getResponseHeader('Content-Type');
              FFeed.LastMod:=r.getResponseHeader('Last-Modified');

              s2:=r.getResponseHeader('Set-Cookie');
              if copy(s2,1,4)='__cf' then SetCookie(s1,s2);

              r:=nil;

              if SaveData then
                SaveUTF16('xmls\'+Format('%.4d',[FFeed.id])+'.xml',FeedData);

             end
            else
            if r.status=304 then
              FFeed.NotModified:=true
            else
              FFeed.Result:='[HTTP:'+IntToStr(r.status)+']'+r.statusText;
           end;
        except
          on e:Exception do
           begin
            if e is EAlternateProcessFeed then
             begin
              FeedData:=e.Message;//see AlternateOpen
              FeedDataType:='text/plain';
             end
            else
              FFeed.Result:='['+e.ClassName+']'+e.Message;
            if not(loadext) and (e is EOleException)
              and ((e.Message='A security error occurred')
              or (e.Message='A connection with the server could not be established'))
              then //TODO: e.ErrorCode=?
              SaveUTF16('feeds\'+Format('%.4d',[FFeed.id])+'.txt','');
           end;
        end;

        //global replaces
        FConfig:=nil;
        if FileExists('feeds\'+Format('%.4d',[FFeed.id])+'g.json') then
          PerformGlobalReplaces(FeedData);

        //content type missing? (really simple) auto-detect
        if (FeedDataType='') and (Length(FeedData)>8) then
         begin
          i:=1;
          while (i<=Length(FeedData)) and (FeedData[i]<=' ') do inc(i);
          if (FeedData<>'') and ((FeedData[i]='{') or (FeedData[i]='[')) then
            FeedDataType:='application/json'
          else
          if StartsWith(FeedData,'<?xml ') then
            FeedDataType:='application/xml' //parse? xmlns? application/atom+xml? application/rss+xml?
          else
            FeedDataType:='text/html';//enables search for <link>s below
         end;

        //any new data?
        if FFeed.NotModified then
         begin
          if (FFeed.Result0<>'') and (FFeed.Result0[1]='[') then
           begin
            i:=1;
            while (i<=Length(FFeed.Result0)) and (FFeed.Result0[i]<>'(') do inc(i);
            inc(i);//skip '('
            j:=i;
            while (j<=Length(FFeed.Result0)) and (FFeed.Result0[j]<>')') do inc(j);
           end
          else
           begin
            i:=1;
            j:=1;
            while (j<=Length(FFeed.Result0)) and (FFeed.Result0[j]<>' ') do inc(j);
           end;
          FFeed.Result:=FFeed.Result+' [HTTP 304]('+Copy(FFeed.Result0,i,j-i)+')';
          Writeln(' HTTP 304');
         end
        else
         begin

          if (FFeed.Result='') and (FeedData='') then FFeed.Result:='[NoData]';

          //process feed data
          if FFeed.Result='' then
            try
              FPostsTotal:=0;//see CheckNewPost
              FPostsNew:=0;//see RegisterPost

              SanitizeContentType(FeedDataType);
              SanitizeUnicode(FeedData);

              //TODO: "Feed".flags?
              if FileExists('feeds\'+Format('%.4d',[FFeed.id])+'ws.txt') then
               begin
                i:=1;
                while (i<=Length(FeedData)) and (word(FeedData[i])<=32) do inc(i);
                if i<>1 then FeedData:=Copy(FeedData,i,Length(FeedData)-i+1);
               end;

              FHasReplaces:=FileExists('feeds\'+Format('%.4d',[FFeed.id])+'r.json');

              handler_i:=0;
              while handler_i<FeedProcessorsIndex do
                if FeedProcessors[handler_i].Determine(
                  Self,FFeed.URL,FeedData,FeedDataType) then
                 begin
                  FeedProcessors[handler_i].ProcessFeed(Self,FeedData);
                  //assert FFeed.Result set by ReportSuccess or ReportFailure
                  handler_i:=FeedProcessorsIndex;
                 end
                else
                  inc(handler_i);

              //nothing yet? process as XML
              if FFeed.Result='' then
               begin
                doc:=CoDOMDocument60.Create;
                doc.async:=false;
                doc.validateOnParse:=false;
                doc.resolveExternals:=false;
                doc.preserveWhiteSpace:=true;
                doc.setProperty('ProhibitDTD',false);
                xres:=doc.loadXML(FeedData);

                //fix Mashable (grr!)
                if not(xres) then
                  xres:=FixUndeclNSPrefix(doc,FeedData);

                //fix floating nbsp's
                if not(xres) and (Pos('''nbsp''',string(doc.parseError.reason))<>0) then
                  FixNBSP(doc,FeedData);

                if xres then
                 begin

                  handler_i:=0;
                  while handler_i<FeedProcessorsXMLIndex do
                    if FeedProcessorsXML[handler_i].Determine(doc) then
                     begin
                      FeedProcessorsXML[handler_i].ProcessFeed(Self,doc);
                      //assert FFeed.Result set by ReportSuccess or ReportFailure
                      handler_i:=FeedProcessorsXMLIndex;
                     end
                    else
                      inc(handler_i);

                  //still nothing?
                  if FFeed.Result='' then
                    if not((FeedDataType='text/html') and FindFeedURL(FeedData)) then
                      FFeed.Result:='Unkown "'+doc.documentElement.tagName+'" ('
                        +FeedDataType+')';
                 end
                else
                 begin
                  if FeedData='' then
                    FFeed.Result:='[No Data]'
                  else

                  //XML parse failed
                  if not((FeedDataType='text/html') and FindFeedURL(FeedData)) then
                    FFeed.Result:='[XML'+IntToStr(doc.parseError.line)+':'+
                      IntToStr(doc.parseError.linepos)+']'+doc.parseError.Reason;
                 end;

                //
               end;

              inc(Result.FeedCount);
              inc(Result.PostCount,FPostsNew);
              inc(FFeed.TotalCount,FPostsNew);
            except
              on e:Exception do
                FFeed.Result:='['+e.ClassName+']'+e.Message;
            end;

          //update feed data if any changes
          if (FFeed.Result<>'') and ((FFeed.Result[1]='[') or (FFeed.Result[1]='(')) then
           begin
            ErrLn('!!! '+FFeed.Result);
           end
          else
           begin
            //stale? update regime
            if (FPostsNew=0) and (FPostsTotal>FFeed.Regime*2+5) then
             begin
              i:=0;
              if FFeed.Regime>=0 then
               begin
                while (i<regimesteps) and (FFeed.Regime>=regimestep[i]) do inc(i);
                if (i<regimesteps) and ((postlast=0.0)
                  or (postlast+regimestep[i]*2<FFeed.LoadStart)) then
                 begin
                  FFeed.Result:=FFeed.Result+' (stale? r:'+IntToStr(FFeed.Regime)+
                    '->'+IntToStr(regimestep[i])+')';
                  FFeed.Regime:=regimestep[i];
                 end;
               end;
             end
            else
             begin
              //not stale: update regime to apparent post average period
              if FFeed.Regime<>0 then
               begin
                i:=regimesteps;
                while (i<>0) and (postavg<regimestep[i-1]) do dec(i);
                if i=0 then FFeed.Regime:=0 else FFeed.Regime:=regimestep[i-1];
               end;
             end;

            Writeln(' '+FFeed.Result);
           end;

          FDB.BeginTrans;
          try

            if FFeed.Name='' then
             begin
              i:=5;
              while (i<=Length(FFeed.URL)) and (FFeed.URL[i]<>':') do inc(i);
              inc(i);
              if (i<=Length(FFeed.URL)) and (FFeed.URL[i]='/') then inc(i);
              if (i<=Length(FFeed.URL)) and (FFeed.URL[i]='/') then inc(i);
              FFeed.Name:='['+Copy(FFeed.URL,i,Length(FFeed.URL)-i+1);
              i:=2;
              while (i<=Length(FFeed.Name)) and (FFeed.Name[i]<>'/') do inc(i);
              SetLength(FFeed.Name,i);
              FFeed.Name[i]:=']';
             end;

            if newfeed or
              (FFeed.URL<>FFeed.URL0) or (FFeed.Name<>FFeed.Name0) then
             begin
              FDB.Update('Feed',
                ['id',FFeed.id
                ,'name',Copy(FFeed.Name,1,200)
                ,'url',FFeed.URL
                ,'loadlast',double(FFeed.LoadStart)
                ,'result',FFeed.Result
                ,'loadcount',FPostsNew
                ,'itemcount',FPostsTotal
                ,'totalcount',FFeed.TotalCount
                ,'regime',FFeed.Regime
                ]);

              if (@OnFeedURLUpdate<>nil) and (FFeed.URL<>FFeed.URL0) then
                OnFeedURLUpdate(Self);
             end
            else
              FDB.Update('Feed',
                ['id',FFeed.id
                ,'loadlast',double(FFeed.LoadStart)
                ,'result',FFeed.Result
                ,'loadcount',FPostsNew
                ,'itemcount',FPostsTotal
                ,'totalcount',FFeed.TotalCount
                ,'regime',FFeed.Regime
                ]);

            if FFeed.LastMod<>FFeed.LastMod0 then
              FDB.Update('Feed',
                ['id',FFeed.id
                ,'lastmod',FFeed.LastMod
                ]);

            FDB.CommitTrans;
          except
            FDB.RollbackTrans;
            raise;
          end;

         end;
       end
      else
       begin
        //feed not loaded now
        Writeln(' Skip '+FeedSkipDisplay(d));
        FFeed.Result:=FFeed.Result0;
        //postsTotal,postsNew see above
        FFeed.LoadStart:=FFeed.LoadLast;
       end;

      FReport.Add('<tr><th>'+IntToStr(FFeed.id)+'</th>');
      FReport.Add(html1+'<a href="'+HTMLEncode(FFeed.URL)+'">'+HTMLEncode(FFeed.Name)+'</a></td>');
      FReport.Add(html2);

      ss:='<td title="';
      if FFeed.LastMod0<>'' then ss:=ss+'last mod: '+HTMLEncode(FFeed.LastMod0)+#13#10;
      if postlast<>0.0 then
        ss:=ss+'post last: '+FormatDateTime('yyyy-mm-dd hh:nn',postlast);
      ss:=ss+'"';
      if postavg=0.0 then
        FReport.Add(ss+' class="empty">&nbsp;</td>')
      else
      if postavg>1.0 then
        FReport.Add(ss+' style="text-align:right;background-color:#FFFFCC;">'+IntToStr(Round(postavg))+' days</td>')
      else
        FReport.Add(ss+' style="text-align:right;">'+IntToStr(Round(postavg*1440.0))+' mins</td>');

      if FFeed.Regime=0 then
        FReport.Add('<td class="empty">&nbsp;</td>')
      else
        FReport.Add('<td style="text-align:right;">'+IntToStr(FFeed.Regime)+'</td>');

      if FFeed.LoadLast=0.0 then
        FReport.Add('<td class="empty">&nbsp;</td>')
      else
       begin
        ss:='<td title="load last: '+FormatDateTime('yyyy-mm-dd hh:nn',FFeed.LoadLast)
          +'" style="text-align:right;';
        f:=UtcNow-FFeed.LoadLast;
        if f>1.0 then
          FReport.Add(ss+'background-color:#FFFFCC;">'+IntToStr(Round(f))+' days</td>')
        else
          FReport.Add(ss+'">'+IntToStr(Round(f*1440.0))+' mins</td>');
       end;

      if (FFeed.Result<>'') and (FFeed.Result[1]='[') then
        FReport.Add('<td style="color:#CC0000;">'+HTMLEncode(FFeed.Result)+'</td>')
      else
        FReport.Add('<td>'+HTMLEncode(FFeed.Result)+'</td>');
      FReport.Add('<td style="text-align:right;" title="last mod:'
        +HTMLEncode(FFeed.LastMod)+'">'+IntToStr(FPostsNew)+'</td>');
      if FPostsTotal=0 then
        FReport.Add('<td class="empty">&nbsp;</td>')
      else
        FReport.Add('<td style="text-align:right;">'+IntToStr(FPostsTotal)+'</td>');
      FReport.Add('<td style="text-align:right;">'+IntToStr(FFeed.TotalCount)+'</td>');
      FReport.Add('</tr>');

      inc(ids_i);
     end;

    OutLn(Format('Loaded: %d posts from %d feeds (%d)',
      [Result.PostCount,Result.FeedCount,ids_l]));

    FReport.Add('</table>');

    qr:=TQueryResult.Create(FDBStats,
      'select ((select count(*) from "Post")+500)/1000||''K posts, '''
      +'||((select count(*) from "UserPost")+500)/1000||''K unread, '''
      +'||pg_database_size(''feeder'')/1024000||''MB, '''
      +'||version()',[]);
    try
      while qr.Read do
        FReport.Add('<p>'+HTMLEncode(qr.GetStr(0))+'</p>');
    finally
      qr.Free;
    end;

    FReport.SaveToFile(FeedLoadReport);

  except
    on e:Exception do
     begin
      ErrLn('['+e.ClassName+']'+e.Message);
      ExitCode:=1;
     end;
  end;
end;

function TFeedEater.CheckLastLoadResultPrefix(const Prefix: string): boolean;
begin
  Result:=(FFeed.Result0='') or StartsWith(FFeed.Result0,Prefix);
end;

function TFeedEater.CheckNewPost(const PostID: string; const PostURL: WideString;
  PostPubDate: TDateTime): boolean;
var
  qr:TQueryResult;
  i:integer;
  s:string;
begin
  FPostID:=PostID;
  FPostURL:=PostURL;
  FPostPubDate:=PostPubDate;
  FPostTags:=Null;
  FPostTagPrefix:='';
  if FPostURL='' then FPostURL:=FPostID;
  if FPostID='' then FPostID:=FPostURL;

  if StartsWithX(FPostID,'http://',s) then
    FPostID:=s
  else
  if StartsWithX(FPostID,'https://',s) then
    FPostID:=s;

  SanitizePostID(FPostID);

  if FFeed.URLSkip<>'' then
   begin
    i:=Pos(FFeed.URLSkip,FPostID);
    if i<>0 then FPostID:=Copy(FPostID,1,i-1);
   end;

  //TODO: if feed_flag_trim in feed_flags?
  FPostURL:=SanitizeTrim(FPostURL);

  //relative url
  if (FPostURL<>'') and not(StartsWith(FPostURL,'http')) then
    if FPostURL[1]='/' then
     begin
      i:=5;
      while (i<=Length(FFeed.URL)) and (FFeed.URL[i]<>':') do inc(i);
      inc(i);
      if (i<=Length(FFeed.URL)) and (FFeed.URL[i]='/') then inc(i);
      if (i<=Length(FFeed.URL)) and (FFeed.URL[i]='/') then inc(i);
      while (i<=Length(FFeed.URL)) and (FFeed.URL[i]<>'/') do inc(i);
      FPostURL:=Copy(FFeed.URL,1,i-1)+FPostURL;
     end
    else
     begin
      i:=Length(FFeed.URL);
      while (i<>0) and (FFeed.URL[i]<>'/') do dec(i);
      FPostURL:=Copy(FFeed.URL,1,i)+FPostURL;
     end;

  //TODO: switch: allow future posts?
  if FPostPubDate>FFeed.LoadStart+2.0/24.0 then
    FPostPubDate:=FFeed.LoadStart;

  inc(FPostsTotal);

  //check age, blacklist, already listed
  Result:=FPostPubDate>=OldPostsCutOff;
  i:=0;
  while Result and (i<BlackList.Count) do
    if (BlackList[i]<>'') and (blacklist[i]=Copy(FPostURL,1,Length(BlackList[i]))) then
      Result:=false
    else
      inc(i);
  if Result then
   begin
    if FFeed.group_id<>0 then
      qr:=TQueryResult.Create(FDB,
        'select P.id from "Post" P'
        +' inner join "Feed" F on F.id=P.feed_id'
        +' and F.group_id=$1'
        +' where P.guid=$2'
        ,[FFeed.group_id,FPostID])
    else
      qr:=TQueryResult.Create(FDB,
        'select id from "Post" where feed_id=$1 and guid=$2'
        ,[FFeed.id,FPostID]);
    try
      Result:=qr.EOF;

      //TODO: if FFeed.group_id<>0 and P.feed_id>FFeed.id then update?

    finally
      qr.Free;
    end;
   end;
end;

procedure TFeedEater.UpdateFeedName(const NewName:string);
begin
  if NewName<>'' then
    FFeed.Name:=NewName;
end;

procedure TFeedEater.PostTags(const TagPrefix:string;const Tags: Variant);
begin
  //assert varArray of varString
  FPostTags:=Tags;
  FPostTagPrefix:=TagPrefix;
  //see also RegisterPost
end;

procedure TFeedEater.RegisterPost(const PostTitle, PostContent: WideString);
var
  title,content:WideString;
  ti,postid:integer;
  tsql:string;
begin
  title:=PostTitle;
  content:=PostContent;
  inc(FPostsNew);
  if IsSomethingEmpty(title) then
   begin
    title:=StripHTML(content,200);
    if Length(title)<=8 then title:=#$2039+FPostID+#$203A;
   end;

  //content starts with <img>? inject a <br />
  SanitizeStartImg(content);

  if FHasReplaces then
    PerformReplaces(title,content);

  //if feedtagprefix<>'' then
  tsql:='';
  if VarIsArray(FPostTags) then //varArray of varStrSomething?
    for ti:=VarArrayLowBound(FPostTags,1) to VarArrayHighBound(FPostTags,1) do
      tsql:=tsql+' or B.url='''+StringReplace(FPostTagPrefix+':'+
        VarToStr(FPostTags[ti]),'''','''''',[rfReplaceAll])+'''';

  //list the post
  FDB.BeginTrans;
  try
    postid:=FDB.Insert('Post',
      ['feed_id',FFeed.id
      ,'guid',FPostID
      ,'title',SanitizeTitle(title)
      ,'content',content
      ,'url',FPostURL
      ,'pubdate',double(FPostPubDate)
      ,'created',double(UtcNow)
      ],'id');
    FDB.Execute('insert into "UserPost" (user_id,post_id,subscription_id,pubdate)'+
      ' select S.user_id,$1,S.id,$2 from "Subscription" S'+
      ' left outer join "UserBlock" B on B.user_id=S.user_id'+
      ' and (B.url=left($3,length(B.url))'+tsql+')'+
      ' where S.feed_id=$4 and B.id is null',[postid,double(FPostPubDate),
        FPostURL,FFeed.id]);
    FDB.CommitTrans;
  except
    FDB.RollbackTrans;
    raise;
  end;
end;

procedure TFeedEater.ReportSuccess(const Lbl: string);
begin
  FFeed.Result:=Format('%s %d/%d',[Lbl,FPostsNew,FPostsTotal]);
end;

procedure TFeedEater.ReportFailure(const Msg: string);
begin
  FFeed.LastMod:='';
  FFeed.Result:=Msg;
end;

const
  GatsbyPageDataSuffix='/page-data.json';

function TFeedEater.LoadExternal(const URL, FilePath, LastMod,
  Accept: string): WideString;
var
  si:TStartupInfo;
  pi:TProcessInformation;
  f:TFileStream;
  s:UTF8String;
  i:integer;
  w:word;
  r,mr:cardinal;
  cl,ua:string;
begin
  Write(':[');
  DeleteFile(PChar(FilePath));//remove any previous file
  ua:='FeedEater/1.0';
  mr:=8;

  if StartsWith(URL,'https://www.instagram.com/') then
   begin
    mr:=0;
    //ua:=
   end;

  cl:='curl.exe -Lki --max-redirs '+IntToStr(mr)+
    ' --no-progress-meter --no-keepalive --compressed'+
    ' --fail-with-body --connect-timeout 300';
  if not(ForceLoadAll) and (LastMod<>'') then
    cl:=cl+' --header "If-Modified-Since: '+LastMod+'"';
  if Pos('/rss',URL)=0 then
    cl:=cl+' --header "Accept: '+Accept+'"';

  if Copy(URL,Length(URL)-
    Length(GatsbyPageDataSuffix)+1,Length(GatsbyPageDataSuffix))=
    GatsbyPageDataSuffix then
   begin
    i:=9;//past 'https://'
    while (i<=Length(URL)) and (URL[i]<>'/') do inc(i);
    cl:=cl+' --referer "'+Copy(URL,1,i)+'"';
   end;

  cl:=cl+
    ' --user-agent "'+ua+'"'+
    ' -o "'+FilePath+'" "'+URL+'"';

  {
  f:=TFileStream.Create(ChangeFileExt(FilePath,'_cl.txt'),fmCreate);
  try
    w:=$FEFF;
    f.Write(w,2);
    f.Write(cl[1],Length(cl)*2);
  finally
    f.Free;
  end;
  }

  ZeroMemory(@si,SizeOf(TStartupInfo));
  si.cb:=SizeOf(TStartupInfo);
  if not CreateProcess(nil,PChar(cl),nil,nil,true,0,nil,nil,si,pi) then RaiseLastOSError;
  CloseHandle(pi.hThread);
  r:=WaitForSingleObject(pi.hProcess,300000);
  if r<>WAIT_OBJECT_0 then
   begin
    TerminateProcess(pi.hProcess,9);
    raise Exception.Create('LoadExternal:'+SysErrorMessage(r));
   end;
  CloseHandle(pi.hProcess);

  f:=TFileStream.Create(FilePath,fmOpenRead);
  try
    f.Read(w,2);
    if w=$FEFF then //UTF16?
     begin
      i:=f.Size-2;
      SetLength(Result,i div 2);
      f.Read(Result[1],i);
     end
    else
    if w=$BBEF then
     begin
      w:=0;
      f.Read(w,1);
      if w<>$BF then raise Exception.Create('Unexpected partial UTF8BOM');
      i:=f.Size-3;
      SetLength(s,i);
      f.Read(s[1],i);
      Result:=UTF8ToWideString(s);
     end
    else
     begin
      f.Position:=0;
      i:=f.Size;
      SetLength(s,i);
      f.Read(s[1],i);

      Result:=UTF8ToWideString(s);
     end;
  finally
    f.Free;
  end;
  Write(']');
end;

function TFeedEater.ParseExternalHeader(var content: WideString): WideString;
var
  i,j,r:integer;
  rh:TStringList;
  s,t:string;
  redir:boolean;
begin
  repeat
    i:=1;
    while (i+4<Length(content)) and not(
      (content[i]=#13) and (content[i+1]=#10) and
      (content[i+2]=#13) and (content[i+3]=#10)) do inc(i);

    Result:='';//default;
    FFeed.LastMod:='';//default
    redir:=false;//default
    rh:=TStringList.Create;
    try
      rh.Text:=Copy(content,1,i);
      if rh.Count<>0 then
       begin

        s:=rh[0];
        if StartsWith(s,'HTTP/') then
         begin
          j:=6;
          while (j<=Length(s)) and (s[j]<>' ') do inc(j);
          inc(j);//' ';
          r:=0;
          while (j<=Length(s)) and (AnsiChar(s[j]) in ['0'..'9']) do
           begin
            r:=r*10+(byte(s[j]) and $F);
            inc(j);
           end;
         end
        else
          r:=200;//?

        if r=301 then
         begin
          redir:=true;
          for j:=1 to rh.Count-1 do
           begin
            s:=rh[j];
            if StartsWithX(s,'Location: ',t) then FFeed.URL:=t;
           end;
          //see also --max-redir
         end
        else
        if r=302 then
          redir:=true
        else
        if r=304 then
          FFeed.NotModified:=true
        else
        if r=200 then
         begin
          for j:=1 to rh.Count-1 do
           begin
            s:=rh[j];
            if StartsWithX(s,'Content-Type: ',t) then
              Result:=t
            else
            if StartsWithX(s,'Last-Modified: ',t) then
              FFeed.LastMod:=t;
           end;
         end
        else
          FFeed.Result:='['+rh[0]+']';
       end;
    finally
      rh.Free;
    end;

    inc(i,4);
    content:=Copy(content,i,Length(content)-i+1);
  until not redir;
end;

procedure TFeedEater.PerformReplaces(var title,content: WideString);
var
  sl:TStringList;
  j,rd:IJSONDocument;
  rc,rt:IJSONDocArray;
  i:integer;
begin
  rc:=JSONDocArray;
  rt:=JSONDocArray;
  j:=JSON(['r',rc,'t',rt]);
  sl:=TStringList.Create;
  try
    sl.LoadFromFile('feeds\'+Format('%.4d',[FFeed.id])+'r.json');
    j.Parse(sl.Text);
  finally
    sl.Free;
  end;

  rd:=JSON;

  //replaces: content
  for i:=0 to rc.Count-1 do
   begin
    rc.LoadItem(i,rd);
    PerformReplace(rd,content);
   end;

  //replaces: title
  for i:=0 to rt.Count-1 do
   begin
    rt.LoadItem(i,rd);
    PerformReplace(rd,title);
   end;

  //prefixes
  if VarIsArray(FPostTags) and //varArray of varStrSomething?
    (VarArrayDimCount(FPostTags)=1) and (VarArrayHighBound(FPostTags,1)-VarArrayLowBound(FPostTags,1)>0) then
   begin
    rd:=JSON(j['p']);
    if rd<>nil then
      for i:=VarArrayLowBound(FPostTags,1) to VarArrayHighBound(FPostTags,1) do
         if not(VarIsNull(rd.Item[FPostTags[i]])) then
           title:=rd.Item[FPostTags[i]]+title;
   end;
end;

procedure TFeedEater.PerformGlobalReplaces(var data: WideString);
var
  sl:TStringList;
  j,rd:IJSONDocument;
  r:IJSONDocArray;
  i:integer;
begin
  r:=JSONDocArray;
  j:=JSON(['r',r]);
  sl:=TStringList.Create;
  try
    sl.LoadFromFile('feeds\'+Format('%.4d',[FFeed.id])+'g.json');
    j.Parse(sl.Text);
  finally
    sl.Free;
  end;
  FConfig:=JSON(j['c']);
  rd:=JSON;
  for i:=0 to r.Count-1 do
   begin
    r.LoadItem(i,rd);
    PerformReplace(rd,data);
   end;
  if FFeed.Result=j['allowResult'] then FFeed.Result:='';  
end;

function TFeedEater.FeedSkipDisplay(d:TDateTime): string;
var
  i:integer;
  s:string;
begin
  i:=Round((d-FFeed.LoadStart)*1440.0);
  if i<0 then
    s:='('+FFeed.Result0+')'
  else
   begin
    //minutes
    s:=IntToStr(i mod 60)+'''';
    i:=i div 60;
    if i<>0 then
     begin
      //hours
      s:=IntToStr(i mod 24)+'h '+s;
      i:=i div  24;
      if i<>0 then
       begin
        //days
        s:=IntToStr(i)+'d '+s;
       end;
     end;
   end;
  if FFeed.Regime<>0 then s:=s+' Regime:'+IntToStr(FFeed.Regime)+'d';
  Result:=s;
end;

procedure TFeedEater.FeedCombineURL(const url, lbl: string);
var
  i,l:integer;
begin
  if LowerCase(Copy(url,1,4))='http' then
    FFeed.URL:=url
  else
  if (Length(url)>1) and (url[1]='/') then
    if (Length(url)>2) and (url[2]='/') then
     begin
      i:=5;
      l:=Length(FFeed.URL);
      while (i<=l) and (FFeed.URL[i]<>'/') do inc(i);
      FFeed.URL:=Copy(FFeed.URL,1,i-1)+url;
     end
   else
     begin
      i:=5;
      l:=Length(FFeed.URL);
      //"http://"
      while (i<=l) and (FFeed.URL[i]<>'/') do inc(i);
      inc(i);
      while (i<=l) and (FFeed.URL[i]<>'/') do inc(i);
      inc(i);
      //then to the next "/"
      while (i<=l) and (FFeed.URL[i]<>'/') do inc(i);
      FFeed.URL:=Copy(FFeed.URL,1,i-1)+url;
     end
  else
   begin
    i:=Length(FFeed.URL);
    while (i<>0) and (FFeed.URL[i]<>'/') do dec(i);
    FFeed.URL:=Copy(FFeed.URL,1,i-1)+url;
   end;
  FFeed.Result:='Feed URL found in content, updating ('+lbl+')';
  FFeed.LastMod:='';
end;

function TFeedEater.FindFeedURL(const data: WideString): boolean;
var
  reLink:RegExp;
  mc:MatchCollection;
  m:Match;
  sm:SubMatches;
  i,s1,s2:integer;
begin
  Result:=false;//default
  reLink:=CoRegExp.Create;
  reLink.Global:=true;
  reLink.IgnoreCase:=true;
  //search for applicable <link type="" href="">
  reLink.Pattern:='<link[^>]+?(rel|type|href)=["'']([^"'']+?)["''][^>]+?(type|href)=["'']([^"'']+?)["'']([^>]+?(type|href)=["'']([^"'']+?)["''])?[^>]*?>';
  mc:=reLink.Execute(data) as MatchCollection;

  if mc.Count=0 then //without quotes?
   begin
    reLink.Pattern:='<link[^>]+?(rel|type|href)=([^ >]+)[^>]+?(type|href)=([^ >]+)([^>]+?(type|href)=([^ >]+))?[^>]*?>';
    mc:=reLink.Execute(data) as MatchCollection;
   end;

  i:=0;
  while (i<mc.Count) and not(Result) do
   begin
    m:=mc[i] as Match;
    inc(i);
    sm:=m.SubMatches as SubMatches;
    if (sm[0]='rel') and (sm[1]='https://api.w.org/') and (sm[2]='href') then
     begin
      //TODO: check +'wp/v2/articles'?
      FeedCombineURL(sm[3]+'wp/v2/posts','WPv2');
      //TODO: +'?per_page=32'?

      //extract title
      reLink.Pattern:='<title>([^<]+?)</title>';
      mc:=reLink.Execute(data) as MatchCollection;
      if mc.Count>0 then
        FFeed.Name:=HTMLDecode(((mc[0] as Match).SubMatches as SubMatches)[0]);

      Result:=true;
      s1:=0;//disable below
      s2:=0;
     end
    else
    if (sm[0]='rel') and (sm[1]='alternate') and (sm[2]='type') and (sm[5]='href') then
     begin
      s1:=3;
      s2:=6;
     end
    else
    if (sm[0]='rel') and (sm[1]='alternate') and (sm[2]='href') and (sm[5]='type') then
     begin
      s1:=6;
      s2:=3;
     end
    else
    if (sm[2]='rel') and (sm[4]='alternate') and (sm[0]='type') and (sm[5]='href') then
     begin
      s1:=1;
      s2:=6;
     end
    else
    if (sm[0]='type') and (sm[2]='href') then
     begin
      s1:=1;
      s2:=3;
     end
    else
    if (sm[0]='href') and (sm[2]='type') then
     begin
      s1:=3;
      s2:=1;
     end
    else
     begin
      s1:=0;
      s2:=0;
     end;
    if s1<>0 then
      if (sm[s1]='application/rss+xml') or (sm[s1]='text/rss+xml') then
       begin
        FeedCombineURL(sm[s2],'RSS');
        Result:=true;
       end
      else
      if (sm[s1]='application/atom') or (sm[s1]='application/atom+xml') or
        (sm[s1]='text/atom') or (sm[s1]='text/atom+xml') then
       begin
        FeedCombineURL(sm[s2],'Atom');
        Result:=true;
       end;
      //TODO if sm[s1]='application/json'?
   end;
  //search for <meta http-equiv="refresh"> redirects
  if not(Result) then
   begin
    reLink.Pattern:='<meta[^>]+?http-equiv=["'']?refresh["'']?[^>]+?content=["'']\d+?;url=([^"'']+?)["''][^>]*?>';
    mc:=reLink.Execute(data) as MatchCollection;
    if mc.Count<>0 then
     begin
      FeedCombineURL(((mc[0] as Match).SubMatches as SubMatches)[0],'Meta');
      Result:=true;
     end;
   end;
  //search for id="__gatsby"
  if not(Result) then
    if Pos(WideString('<div id="___gatsby"'),data)<>0 then
     begin
      FeedCombineURL('/page-data/index/page-data.json','PageDataIndex');
      Result:=true;
     end;
end;

function TFeedEater.GetConfig(const Key: string): string;
begin
  if FConfig=nil then Result:='' else Result:=VarToStr(FConfig[Key]);  
end;

procedure TFeedEater.RenderGraphs;
begin
  DoGraphs(FDB);
end;

procedure TFeedEater.CheckCookie(const url: string; var s1, s2: string);
var
  i,l:integer;
begin
  l:=Length(url);
  i:=9;//Length('https://')+1
  while (i<=l) and (url[i]<>'/') do inc(i);
  s1:=Copy(url,1,i);
  s2:=FCookies.Values[s1];
end;


procedure TFeedEater.SetCookie(const s1, s2: string);
var
  i,l:integer;
begin
  l:=Length(s2);
  i:=1;
  while (i<=l) and (s2[i]<>';') do inc(i);
  FCookies.Values[s1]:=Copy(s2,1,i-1);
end;

initialization
  PGVersion:='';
  BlackList:=TStringList.Create;
  InstagramLastTC:=GetTickCount-InstagramIntervalMS;
  InstagramFailed:=0.0;
finalization
  BlackList.Free;
end.
