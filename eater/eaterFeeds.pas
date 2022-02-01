unit eaterFeeds;

interface

uses Classes, DataLank, eaterReg;

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
    OldPostsCutOff:TDateTime;
    function LoadExternal(const URL,FilePath,LastMod,Accept:string):WideString;
    function ParseExternalHeader(var content:WideString):WideString;
    function FeedSkipDisplay(d:TDateTime):string;
    procedure PerformReplaces(var title,content:WideString);
    procedure PerformGlobalReplaces(var data:WideString);
    procedure FeedCombineURL(const url,lbl:string);
    function FindFeedURL(const data:WideString):boolean;
    //IFeedStore
    function CheckLastLoadResultPrefix(const Prefix:string):boolean;
    //IFeedHandler
    function CheckNewPost(const PostID:string;const PostURL:WideString;
      PostPubDate:TDateTime):boolean;
    procedure UpdateFeedName(const NewName:string);
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
    function DoUpdateFeeds(SpecificFeedID:integer;
      PubDateMargin:double):TFeedEatResult;
    procedure RenderGraphs;
  end;

const
  Specific_NewFeeds=-111;

var
  PGVersion:string;
  BlackList:TStringList;

implementation

uses Windows, SysUtils, Variants, ComObj, eaterUtils, eaterSanitize, MSXML2_TLB,
  jsonDoc, VBScript_RegExp_55_TLB, eaterGraphs, feedSoundCloud;

const
  FeederIniPath='..\..\feeder.ini';
  //TODO: from ini?
  FeedLoadReport='..\Load.html';
  AvgPostsDays=100;
  OldPostsDays=3660;

  regimesteps=8;
  regimestep:array[0..regimesteps-1] of integer=(1,2,3,7,14,30,60,90);

  YoutubePrefix1='https://www.youtube.com/channel/';
  YoutubePrefix2='https://www.youtube.com/feeds/videos.xml?channel_id=';

  InstagramDelaySecs=120;
  InstagramURLSuffix='?__a=1';

var
  InstagramDelayMS:cardinal;


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
end;

destructor TFeedEater.Destroy;
begin
  FDB.Free;
  FDBStats.Free;
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
  qr:=TQueryResult.Create(FDBStats,'select X.id from "UserPost" X'
    +' inner join "Post" P on P.id=X.post_id'
    +' inner join "Subscription" S on S.feed_id=P.feed_id and S.user_id=X.user_id'
    +' where P.pubdate<$1-S.autounread/24.0 limit 1',[double(UtcNow)]);
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
        +' from "UserPost" X'
        +' inner join "Post" P on P.id=X.post_id'
        +' inner join "Subscription" S on S.feed_id=P.feed_id and S.user_id=X.user_id'
        +' where P.pubdate<$1-S.autounread/24.0)',[double(UtcNow)]);
      FDB.CommitTrans;
    except
      FDB.RollbackTrans;
      raise;
    end;
    Writeln(' '+IntToStr(i)+' items marked read');
   end;
end;

function TFeedEater.DoUpdateFeeds(SpecificFeedID:integer;
  PubDateMargin:double):TFeedEatResult;
var
  qr:TQueryResult;
  ids:array of integer;
  ids_i,ids_l:integer;
  d,oldPostDate:TDateTime;
  sql1,sql2,ss:string;

  postlast,postavg,f:double;
  newfeed,dofeed,doreq,loadext,xres:boolean;
  r:ServerXMLHTTP60;
  redirCount,i:integer;
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
  FReport.Add('<tr>');
  FReport.Add('<th>&nbsp;</th>');
  FReport.Add('<th>name</th>');
  FReport.Add('<th>created</th>');
  FReport.Add('<th>#</th>');
  FReport.Add('<th>post:last</th>');
  FReport.Add('<th>post:avg</th>');
  FReport.Add('<th>regime</th>');
  FReport.Add('<th>load:last</th>');
  FReport.Add('<th>:since</th>');
  FReport.Add('<th>load:result</th>');
  FReport.Add('<th>load:new</th>');
  FReport.Add('<th>load:items</th>');
  FReport.Add('<th>total</th>');
  FReport.Add('</tr>');

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

        if (FFeed.Result0<>'') and (FFeed.Result0[1]='[') then
          FFeed.Result0:='';

        FReport.Add('<tr>');
        FReport.Add('<th>'+IntToStr(FFeed.id)+'</th>');
        FReport.Add('<td class="n" title="'+FormatDateTime('yyyy-mm-dd hh:nn:ss',FFeed.LoadStart)+'">');
        if FFeed.group_id<>0 then
          FReport.Add('<div class="flag" style="background-color:red;">'+IntToStr(FFeed.group_id)+'</div>&nbsp;');
        FReport.Add('<a href="'+HTMLEncode(FFeed.URL)+'">'+HTMLEncode(FFeed.Name)+'</a></td>');
        FReport.Add('<td>'+FormatDateTime('yyyy-mm-dd hh:nn',qrDate(qr,'created'))+'</td>');
        FReport.Add('<td style="text-align:right;">'+VarToStr(qr['scount'])+'</td>');

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
        FReport.Add('<td class="empty" title="'+HTMLEncode(FFeed.LastMod0)+'">&nbsp;</td>');
        if FFeed.LoadLast=0.0 then
          d:=FFeed.LoadStart-PubDateMargin
        else
          d:=FFeed.LoadLast+FFeed.Regime;
       end
      else
       begin
        FReport.Add('<td title="'+HTMLEncode(FFeed.LastMod0)+'">'+FormatDateTime('yyyy-mm-dd hh:nn',postlast)+'</td>');
        d:=postlast+postavg-PubDateMargin;
        if (FFeed.LoadLast<>0.0) and (d<FFeed.LoadLast) then
          d:=FFeed.LoadLast+FFeed.Regime-PubDateMargin;
       end;
      dofeed:=(d<FFeed.LoadStart) or ForceLoadAll;

      if postavg=0.0 then
        FReport.Add('<td class="empty">&nbsp;</td>')
      else
      if postavg>1.0 then
        FReport.Add('<td style="text-align:right;background-color:#FFFFCC;">'+IntToStr(Round(postavg))+' days</td>')
      else
        FReport.Add('<td style="text-align:right;">'+IntToStr(Round(postavg*1440.0))+' mins</td>');
      if FFeed.Regime=0 then
        FReport.Add('<td class="empty">&nbsp;</td>')
      else
        FReport.Add('<td style="text-align:right;">'+IntToStr(FFeed.Regime)+'</td>');
      if FFeed.LoadLast=0.0 then
        FReport.Add('<td class="empty">&nbsp;</td><td class="empty">&nbsp;</td>')
      else
       begin
        FReport.Add('<td>'+FormatDateTime('yyyy-mm-dd hh:nn',FFeed.LoadLast)+'</td>');
        f:=UtcNow-FFeed.LoadLast;
        if f>1.0 then
          FReport.Add('<td style="text-align:right;background-color:#FFFFCC;">'+IntToStr(Round(f))+' days</td>')
        else
          FReport.Add('<td style="text-align:right;">'+IntToStr(Round(f*1440.0))+' mins</td>');
       end;

      //proceed with this feed?
      if dofeed then
       begin

        //load feed data
        loadext:=FileExists('feeds\'+Format('%.4d',[FFeed.id])+'.txt');
        try

          //TODO: move these into specific feed handlers

          if (FFeed.Result0='') and StartsWithX(FFeed.URL,YoutubePrefix1,ss) then
            FFeed.URL:=YoutubePrefix2+ss;

          if StartsWith(FFeed.URL,'https://www.instagram.com/') then
           begin

            i:=cardinal(GetTickCount-InstagramDelayMS);
            if i<InstagramDelaySecs*1000 then
             begin
              Writeln('');
              while i<InstagramDelaySecs*1000 do
               begin
                Write(#13'Instagram delay '+IntToStr(InstagramDelaySecs-(i div 1000))+'s...   ');
                Sleep(10);
                i:=cardinal(GetTickCount-InstagramDelayMS);
               end;
              Write(#13'[Instagram delay...]');
             end;

            if (FFeed.URL<>'') and (FFeed.URL[Length(FFeed.URL)]<>'/') then
              FFeed.URL:=FFeed.URL+'/';
            FeedData:=LoadExternal(FFeed.URL+InstagramURLSuffix,
              'xmls\'+Format('%.4d',[FFeed.ID])+'.json',
              FFeed.LastMod,
              'application/json');//UseProxy?
            if FeedData='' then //if StartsWith(FeedData,'HTTP/1.1 301') then
              FFeed.Result:='[Instagram]'
            else
              FeedDataType:=ParseExternalHeader(FeedData);
            InstagramDelayMS:=GetTickCount;
           end
          else

          if loadext then
           begin
            FeedData:=LoadExternal(FFeed.URL,
              'xmls\'+Format('%.4d',[FFeed.id])+'.xml',
              FFeed.LastMod,
              'application/rss+xml, application/atom+xml, application/xml, text/xml');
            FeedDataType:=ParseExternalHeader(FeedData);

           end
          else
           begin
            redirCount:=0;
            doreq:=true;
            while doreq do
             begin
              doreq:=false;
              Write(':');
              r:=CoServerXMLHTTP60.Create;

              if StartsWith(FFeed.URL,'sparql://') then
               begin
                r.open('GET','https://'+Copy(FFeed.URL,10,Length(FFeed.URL)-9)+
                  '?default-graph-uri=&query=PREFIX+schema%3A+<http%3A%2F%2Fschema.org%2F>%0D%0A'+
                  'SELECT+*+WHERE+%7B+%3Fnews+a+schema%3ANewsArticle%0D%0A.+%3Fnews+schema%3Aurl+%3Furl%0D%0A'+
                  '.+%3Fnews+schema%3AdatePublished+%3FpubDate%0D%0A'+
                  '.+%3Fnews+schema%3Aheadline+%3Fheadline%0D%0A'+
                  '.+%3Fnews+schema%3Adescription+%3Fdescription%0D%0A'+
                  '.+%3Fnews+schema%3AarticleBody+%3Fbody%0D%0A'+
                  '%7D+ORDER+BY+DESC%28%3FpubDate%29+LIMIT+20'
                  ,false,EmptyParam,EmptyParam);
                r.setRequestHeader('Accept','application/sparql-results+xml, application/xml, text/xml')
               end
              else
              if StartsWith(FFeed.URL,'https://www.instagram.com/') then
               begin
                if (FFeed.URL<>'') and (FFeed.URL[Length(FFeed.URL)]<>'/') then
                  FFeed.URL:=FFeed.URL+'/';
                r.open('GET',FFeed.URL+InstagramURLSuffix,false,EmptyParam,EmptyParam);
                r.setRequestHeader('Accept','application/json');
               end
              else
              if StartsWith(FFeed.URL,'https://soundcloud.com/') then
               begin
                r.open('GET','https://api-v2.soundcloud.com/resolve?url='+
                  string(URLEncode(FFeed.URL))+'&client_id='+SoundCloudClientID,
                  false,EmptyParam,EmptyParam);
                r.setRequestHeader('Accept','application/json');
               end
              else
               begin
                r.open('GET',FFeed.URL,false,EmptyParam,EmptyParam);
                if Pos('sparql',FFeed.URL)<>0 then
                  r.setRequestHeader('Accept','application/sparql-results+xml, application/xml, text/xml')
                else
                  r.setRequestHeader('Accept','application/rss+xml, application/atom+xml, application/xml, application/json, text/xml');
               end;
              r.setRequestHeader('Cache-Control','no-cache, no-store, max-age=0');
              if Pos('tumblr.com',FFeed.URL)<>0 then
               begin
                r.setRequestHeader('User-Agent','Mozilla/5.0 (Windows NT 10.0; Win64; x'+
                  '64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/75.0.3770.100 Safari/537.36');
                r.setRequestHeader('Cookie','_ga=GA1.2.23714421.1433010142; rxx=1tcxhdz'+
                  'ww7.1lckhv27&v=1; tmgioct=5d2ce7032975560097163000; pfg=1fd4f3446c5c'+
                  'c43c229f7759a039c1f03c54916c6dbe1ad54d36c333d0cf0ed4%23%7B%22eu_resi'+
                  'dent%22%3A1%2C%22gdpr_is_acceptable_age%22%3A1%2C%22gdpr_consent_cor'+
                  'e%22%3A1%2C%22gdpr_consent_first_party_ads%22%3A1%2C%22gdpr_consent_'+
                  'third_party_ads%22%3A1%2C%22gdpr_consent_search_history%22%3A1%2C%22'+
                  'exp%22%3A1594760108%2C%22vc%22%3A%22granted_vendor_oids%3D%26oath_ve'+
                  'ndor_list_version%3D18%26vendor_list_version%3D154%22%7D%233273090316');
               end
              else
                r.setRequestHeader('User-Agent','FeedEater/1.1');
              if StartsWith(FFeed.URL,'https://www.washingtonpost.com') then
                r.setRequestHeader('Cookie','wp_gdpr=1|1');
              //TODO: ...'/wp/v2/posts' param 'after' last load time?
              if (FFeed.LastMod<>'') and not(ForceLoadAll) then
                r.setRequestHeader('If-Modified-Since',FFeed.LastMod);
              r.send(EmptyParam);
              if (r.status=301) or (r.status=302) or (r.status=308) then //moved permanently
               begin
                FFeed.URL:=r.getResponseHeader('Location');
                doreq:=true;
                inc(redirCount);
                if redirCount=8 then
                  raise Exception.Create('Maximum number of redirects reached');
               end;
             end;
            if r.status=200 then
             begin

              Write(':');
              FeedData:=r.responseText;
              //:=r.getAllResponseHeaders;
              FeedDataType:=r.getResponseHeader('Content-Type');
              FFeed.LastMod:=r.getResponseHeader('Last-Modified');
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
            FFeed.Result:='['+e.ClassName+']'+e.Message;
            if not(loadext) and (e is EOleException)
              and ((e.Message='A security error occurred')
              or (e.Message='A connection with the server could not be established'))
              then //TODO: e.ErrorCode=?
              SaveUTF16('feeds\'+Format('%.4d',[FFeed.id])+'.txt','');
           end;
        end;

        //global replaces
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
          FFeed.Result:=FFeed.Result+' [HTTP 304]';
          if not loadext then Writeln(' HTTP 304');
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
               begin
                if FeedProcessors[handler_i].Determine(
                  Self,FFeed.URL,FeedData,FeedDataType) then
                 begin
                  FeedProcessors[handler_i].ProcessFeed(Self,FeedData);
                  //assert FFeed.Result set by ReportSuccess or ReportFailure
                  handler_i:=FeedProcessorsIndex;
                 end
                else
                  inc(handler_i);
               end;

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
                   begin
                    if FeedProcessorsXML[handler_i].Determine(doc) then
                     begin
                      FeedProcessorsXML[handler_i].ProcessFeed(Self,doc);
                      //assert FFeed.Result set by ReportSuccess or ReportFailure
                      handler_i:=FeedProcessorsXMLIndex;
                     end
                    else
                      inc(handler_i);
                   end;

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
          if (FFeed.Result<>'') and (FFeed.Result[1]='[') then
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
                ,'name',FFeed.Name
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

      if (FFeed.Result<>'') and (FFeed.Result[1]='[') then
        FReport.Add('<td style="color:#CC0000;">'+HTMLEncode(FFeed.Result)+'</td>')
      else
        FReport.Add('<td>'+HTMLEncode(FFeed.Result)+'</td>');
      if FPostsTotal=0 then
        FReport.Add('<td class="empty">&nbsp;</td>')
      else
        FReport.Add('<td style="text-align:right;">'+IntToStr(FPostsTotal)+'</td>');
      FReport.Add('<td style="text-align:right;" title="'+FormatDateTime('yyyy-mm-dd hh:nn:ss',FFeed.LoadStart)
        +#13#10+HTMLEncode(FFeed.LastMod)+'">'+IntToStr(FPostsNew)+'</td>');
      FReport.Add('<td style="text-align:right;">'+IntToStr(FFeed.TotalCount)+'</td>');
      FReport.Add('</tr>');

      inc(ids_i);
     end;

    OutLn(Format('Loaded: %d posts from %d feeds',
      [Result.PostCount,Result.FeedCount]));

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
  if VarIsArray(FPostTags) and //varArray of varStrSomething?
    (VarArrayDimCount(FPostTags)=1) and (VarArrayHighBound(FPostTags,1)-VarArrayLowBound(FPostTags,1)>0) then
   begin
    tsql:='';
    for ti:=VarArrayLowBound(FPostTags,1) to VarArrayHighBound(FPostTags,1) do
      tsql:=tsql+' or B.url='''+StringReplace(FPostTagPrefix+':'+
        VarToStr(FPostTags[ti]),'''','''''',[rfReplaceAll])+'''';
   end
  else
    tsql:='';

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
    FDB.Execute('insert into "UserPost" (user_id,post_id)'+
      ' select S.user_id,$1 from "Subscription" S'+
      ' left outer join "UserBlock" B on B.user_id=S.user_id'+
      ' and (B.url=left($2,length(B.url))'+tsql+')'+
      ' where S.feed_id=$3 and B.id is null',[postid,FPostURL,FFeed.id]);
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

function TFeedEater.LoadExternal(const URL, FilePath, LastMod,
  Accept: string): WideString;
var
  si:TStartupInfo;
  pi:TProcessInformation;
  f:TFileStream;
  s:UTF8String;
  i:integer;
  w:word;
  r:cardinal;
  p1:string;
begin
  WriteLn(' ->');
  DeleteFile(PChar(FilePath));//remove any previous file

  if not(ForceLoadAll) and (LastMod<>'') then
    p1:=' --header="If-Modified-Since: '+LastMod+'"'
  else
    p1:='';

  {
  if useProxy and (proxiesIndex<proxies.Count) then
    p1:=p1+' -e http_proxy='+proxies[proxiesIndex];

  if useProxy then //if 'instagram'
    p1:=p1+' --max-redirect=0';
  }
  if StartsWith(URL,'https://www.instagram.com/') then
    p1:=p1+' --max-redirect=0';

  ZeroMemory(@si,SizeOf(TStartupInfo));
  si.cb:=SizeOf(TStartupInfo);
  {
  si.dwFlags:=STARTF_USESTDHANDLES;
  si.hStdInput:=GetStdHandle(STD_INPUT_HANDLE);
  si.hStdOutput:=GetStdHandle(STD_OUTPUT_HANDLE);
  si.hStdError:=GetStdHandle(STD_ERROR_HANDLE);
  }
  {
  if not CreateProcess(nil,PChar('curl.exe -Lk --max-redirs 8 -H "Accept:application/rss+xml, application/atom+xml, application/xml, text/xml" -o "'+
    FilePath+'" "'+URL+'"'),nil,nil,true,0,nil,nil,si,pi) then RaiseLastOSError;
  }
  if not CreateProcess(nil,PChar(
    'wget.exe -nv --no-cache --max-redirect 8 --no-http-keep-alive --no-check-certificate'+
    p1+' --save-headers --content-on-error --header="Accept: '+Accept+'"'+
    ' --user-agent="FeedEater/1.0" --compression=auto'+
    ' -O "'+FilePath+'" "'+URL+'"'),nil,nil,true,0,nil,nil,si,pi) then RaiseLastOSError;
  CloseHandle(pi.hThread);
  r:=WaitForSingleObject(pi.hProcess,30000);
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
end;

function TFeedEater.ParseExternalHeader(var content: WideString): WideString;
var
  i,j:integer;
  rh:TStringList;
  s,t:string;
begin
  i:=1;
  while (i+4<Length(content)) and not(
    (content[i]=#13) and (content[i+1]=#10) and
    (content[i+2]=#13) and (content[i+3]=#10)) do inc(i);

  Result:='';//default;
  FFeed.LastMod:='';//default
  rh:=TStringList.Create;
  try
    rh.Text:=Copy(content,1,i);
    if rh.Count<>0 then
     begin
      if StartsWith(rh[0],'HTTP/1.1 304') then FFeed.NotModified:=true else
      if not StartsWith(rh[0],'HTTP/1.1 200') then
        FFeed.Result:='['+rh[0]+']';
      for j:=1 to rh.Count-1 do
       begin
        s:=rh[j];
        if StartsWithX(s,'Content-Type: ',t) then
          Result:=t
        else
        if StartsWithX(s,'Last-Modified: ',t) then
          FFeed.LastMod:=t;
       end;
     end;
  finally
    rh.Free;
  end;

  inc(i,4);
  content:=Copy(content,i,Length(content)-i+1);
end;

procedure TFeedEater.PerformReplaces(var title,content: WideString);
var
  sl:TStringList;
  j,rd:IJSONDocument;
  rc,rt:IJSONDocArray;
  i:integer;
  re:RegExp;
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
    re:=CoRegExp.Create;
    re.Pattern:=rd['x'];
    if not(VarIsNull(rd['g'])) then re.Global:=boolean(rd['g']);
    if not(VarIsNull(rd['m'])) then re.Multiline:=boolean(rd['m']);
    if not(VarIsNull(rd['i'])) then re.IgnoreCase:=boolean(rd['i']);
    content:=re.Replace(content,rd['s']);
   end;

  //replaces: title
  for i:=0 to rt.Count-1 do
   begin
    rt.LoadItem(i,rd);
    re:=CoRegExp.Create;
    re.Pattern:=rd['x'];
    if not(VarIsNull(rd['g'])) then re.Global:=boolean(rd['g']);
    if not(VarIsNull(rd['m'])) then re.Multiline:=boolean(rd['m']);
    if not(VarIsNull(rd['i'])) then re.IgnoreCase:=boolean(rd['i']);
    title:=re.Replace(title,rd['s']);
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
  re:RegExp;
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

  rd:=JSON;

  for i:=0 to r.Count-1 do
   begin
    r.LoadItem(i,rd);
    re:=CoRegExp.Create;
    re.Pattern:=rd['x'];
    if not(VarIsNull(rd['g'])) then re.Global:=boolean(rd['g']);
    if not(VarIsNull(rd['m'])) then re.Multiline:=boolean(rd['m']);
    if not(VarIsNull(rd['i'])) then re.IgnoreCase:=boolean(rd['i']);
    data:=re.Replace(data,rd['s']);
   end;
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
  //                          0                    1                    2                3             (4)     5                6
  mc:=reLink.Execute(data) as MatchCollection;
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
      if (sm[s1]='application/atom') or (sm[s1]='text/atom') then
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
    if (mc.Count<>0) and (sm[0]<>'') then
     begin
      FeedCombineURL(((mc[0] as Match).SubMatches as SubMatches)[0],'Meta');
      Result:=true;
     end;
   end;
end;

procedure TFeedEater.RenderGraphs;
begin
  DoGraphs(FDB);
end;

initialization
  PGVersion:='';
  BlackList:=TStringList.Create;
  InstagramDelayMS:=GetTickCount-InstagramDelaySecs*1000;
finalization
  BlackList.Free;
end.
