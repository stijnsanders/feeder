unit eater1;

interface

uses SysUtils;

procedure DoProcessParams;
procedure DoUpdateFeeds;
function DoCheckRunDone:boolean;

//TODO: from ini
const
  FeederDBPath='..\feeder.db';
  OldPostsDays=732;

implementation

uses Classes, Windows, DataLank, MSXML2_TLB, Variants, VBScript_RegExp_55_TLB;

var
  OldPostsCutOff,LastRun:TDateTime;
  SaveData:boolean;
  FeedID,RunContinuous,LastClean:integer;

function ConvDate1(const x:string):TDateTime;
var
  dy,dm,dd,th,tm,ts,tz,b,b0:word;
  i,l,b1:integer;
  procedure nx(var xx:word;yy:integer);
  var
    ii:integer;
  begin
    xx:=0;
    for ii:=0 to yy-1 do
      if (i<=l) and (x[i] in ['0'..'9']) then
       begin
        xx:=xx*10+(byte(x[i]) and $F);
        inc(i);
       end;
  end;
begin
  i:=1;
  l:=Length(x);
  while (i<=l) and (x[i]<=' ') do inc(i);
  nx(dy,4); inc(i);//':'
  nx(dm,2); inc(i);//':'
  nx(dd,2); inc(i);//'T'
  nx(th,2); inc(i);//':'
  nx(tm,2); inc(i);//':'
  nx(ts,2);
  if (i<=l) and (x[i]='.') then
   begin
    inc(i);
    nx(tz,3);
   end
  else
    tz:=0;
  b:=0;//default
  b1:=0;//default
  if i<=l then
    case x[i] of
      '+':
       begin
        b1:=+1; inc(i);
        nx(b,2); inc(i);//':'
        nx(b0,2); b:=b*100+b0;
       end;
      '-':
       begin
        b1:=-1; inc(i);
        nx(b,2); inc(i);//':'
        nx(b0,2); b:=b*100+b0;
       end;
      'Z':begin b1:=+1; b:=0000; end;
      'A'..'M':begin b1:=+1; b:=(byte(x[1])-64)*100; end;
      'N'..'Y':begin b1:=-1; b:=(byte(x[1])-77)*100; end;
    end;
  Result:=
    EncodeDate(dy,dm,dd)+
    EncodeTime(th,tm,ts,tz)+
    b1*((b div 100)/24.0+(b mod 100)/1440.0);
end;

const
  TimeZoneCodeCount=191;
  TimeZoneCode:array[0..TimeZoneCodeCount-1] of string=(
  'ACDT+1030' ,
  'ACST+0930',
  'ACT-0500',
  //'ACT+0800'//ASEAN Common
  'ACWST+0845',
  'ADT-0300',
  'AEDT+1100',
  'AEST+1000',
  'AFT+0430',
  'AKDT-0800',
  'AKST-0900',
  'AMST-0300',
  'AMT+0400',
  'ART-0300',
  'AST+0300',
  'AST-0400',
  'AWST+0800',
  'AZOST+0000',
  'AZOT-0100',
  'AZT+0400',
  'BDT+0800',
  'BIOT+0600',
  'BIT-1200',
  'BOT-0400',
  'BRST-0200',
  'BRT-0300',
  'BST+0600',
  'BST+1100',
  'BTT+0600',
  'CAT+0200',
  'CCT+0630',
  'CDT-0500',
  'CDT-0400',
  'CEST+0200',
  'CET+0100',
  'CHADT+1345',
  'CHAST+1245',
  'CHOT+0800',
  'CHOST+0900',
  'CHST+1000',
  'CHUT+1000',
  'CIST-0800',
  'CIT+0800',
  'CKT-1000',
  'CLST-0300',
  'CLT-0400',
  'COST-0400',
  'COT-0500',
  'CST-0600',
  'CST+0800',
  'CST-0500',
  'CT+0800',
  'CVT-0100',
  'CWST+0845',
  'CXT+0700',
  'DAVT+0700',
  'DDUT+1000',
  'DFT+0100',
  'EASST-0500',
  'EAST-0600',
  'EAT+0300',
  'ECT-0400',
  'ECT-0500',
  'EDT-0400',
  'EEST+0300',
  'EET+0200',
  'EGST+0000',
  'EGT-0100',
  'EIT+0900',
  'EST-0500',
  'FET+0300',
  'FJT+1200',
  'FKST-0300',
  'FKT-0400',
  'FNT-0200',
  'GALT-0600',
  'GAMT-0900',
  'GET+0400',
  'GFT-0300',
  'GILT+1200',
  'GIT-0900',
  'GMT+0000',
  'GST-0200',
  'GST+0400',
  'GYT-0400',
  'HDT-0900',
  'HAEC+0200',
  'HST-1000',
  'HKT+0800',
  'HMT+0500',
  'HOVST+0800',
  'HOVT+0700',
  'ICT+0700',
  'IDLW-1200',
  'IDT+0300',
  'IOT+0300',
  'IRDT+0430',
  'IRKT+0800',
  'IRST+0330',
  'IST+0530',//Indian Standard Time
  //'IST+0100',//Irish Standard Time
  //'IST+0200',//Israel Standard Time
  'JST+0900',
  'KALT+0200',
  'KGT+0600',
  'KOST+1100',
  'KRAT+0700',
  'KST+0900',
  'LHST+1030',//Lord Howe Standard Time
  //'LHST+1100',//Lord Howe Summer Time
  'LINT+1400',
  'MAGT+1200',
  'MART-0930',
  'MAWT+0500',
  'MDT-0600',
  'MET+0100',
  'MEST+0200',
  'MHT+1200',
  'MIST+1100',
  'MIT-0930',
  'MMT+0630',
  'MSK+0300',
  //'MST+0800',//Malaysia Standard Time
  'MST-0700',//Mountain Standard Time (North America)
  'MUT+0400',
  'MVT+0500',
  'MYT+0800',
  'NCT+1100',
  'NDT-0230',
  'NFT+1100',
  'NPT+0545',
  'NST-0330',
  'NT-0330',
  'NUT-1100',
  'NZDT+1300',
  'NZST+1200',
  'OMST+0600',
  'ORAT+0500',
  'PDT-0700',
  'PET-0500',
  'PETT+1200',
  'PGT+1000',
  'PHOT+1300',
  'PHT+0800',
  'PKT+0500',
  'PMDT-0200',
  'PMST-0300',
  'PONT+1100',
  'PST-0800',//Pacific Standard Time (North America)
  //'PST+0800',//Phillipine Standard Time
  'PYST-0300',
  'PYT-0400',
  'RET+0400',
  'ROTT-0300',
  'SAKT+1100',
  'SAMT+0400',
  'SAST+0200',
  'SBT+1100',
  'SCT+0400',
  'SDT-1000',
  'SGT+0800',
  'SLST+0530',
  'SRET+1100',
  'SRT-0300',
  'SST-1100',
  'SST+0800',
  'SYOT+0300',
  'TAHT-1000',
  'THA+0700',
  'TFT+0500',
  'TJT+0500',
  'TKT+1300',
  'TLT+0900',
  'TMT+0500',
  'TRT+0300',
  'TOT+1300',
  'TVT+1200',
  'ULAST+0900',
  'ULAT+0800',
  'UTC+0000',
  'UYST-0200',
  'UYT-0300',
  'UZT+0500',
  'VET-0400',
  'VLAT+1000',
  'VOLT+0400',
  'VOST+0600',
  'VUT+1100',
  'WAKT+1200',
  'WAST+0200',
  'WAT+0100',
  'WEST+0100',
  'WET+0000',
  'WIT+0700',
  'WST+0800',
  'YAKT+0900',
  'YEKT+0500');

function ConvDate2(const x:string):TDateTime;
var
  dy,dm,dd,th,tm,ts,tz,b:word;
  i,j,k,l,b1:integer;
  procedure nx(var xx:word;yy:integer);
  var
    ii:integer;
  begin
    xx:=0;
    for ii:=0 to yy-1 do
      if (i<=l) and (x[i] in ['0'..'9']) then
       begin
        xx:=xx*10+(byte(x[i]) and $F);
        inc(i);
       end;
  end;
begin
  i:=1;
  l:=Length(x);
  while (i<=l) and (x[i]<=' ') do inc(i);
  //day of week 'Mon,','Tue,'...
  while (i<=l) and not(x[i] in ['0'..'9']) do inc(i);
  //day of month
  nx(dd,2);
  inc(i);//' '
  //month
  dm:=0;//default
  if i+3<l then
    case x[i] of
      'J':
        case x[i+1] of
          'a':dm:=1;//Jan
          'u':
            case x[i+2] of
              'n':dm:=6;//Jun
              'l':dm:=7;//Jul
            end;
        end;
      'F':dm:=2;//Feb
      'M':
        case x[i+2] of
         'r':dm:=3;//Mar
         'y':dm:=5;//May
        end;
      'A':
        case x[i+1] of
          'p':dm:=4;//Apr
          'u':dm:=8;//Aug
        end;
      'S':dm:=9;//Sep
      'O':dm:=10;//Oct
      'N':dm:=11;//Nov
      'D':dm:=12;//Dec
    end;
  inc(i,4);
  nx(dy,4); inc(i);//' '
  nx(th,2); inc(i);//':'
  nx(tm,2); inc(i);//':'
  nx(ts,2); inc(i);//' '
  tz:=0;
  //timezone
  b:=0;//default
  b1:=0;//default
  if i+2<=l then
    case x[i] of
      '+':
       begin
        b1:=+1;
        inc(i);
        nx(b,4);
       end;
      '-':
       begin
        b1:=-1;
        inc(i);
        nx(b,4);
       end;
      'A'..'Z':
       begin
        j:=0;
        while j<>TimeZoneCodeCount do
         begin
          k:=0;
          while (byte(TimeZoneCode[j][1+k])>64) and
            (x[i+k]=TimeZoneCode[j][1+k]) do inc(k);
          if byte(TimeZoneCode[j][1+k])<64 then
           begin
            if TimeZoneCode[j][1+k]='-' then b1:=-1 else b1:=+1;
            b:=StrToInt(Copy(TimeZoneCode[j],2+k,4));
            j:=TimeZoneCodeCount;
           end
          else
            inc(j);
         end;
       end;
    end;
  Result:=
    EncodeDate(dy,dm,dd)+
    EncodeTime(th,tm,ts,tz)+
    b1*((b div 100)/24.0+(b mod 100)/1440.0);
end;

function UtcNow:TDateTime;
var
  st:TSystemTime;
  tz:TTimeZoneInformation;
  tx:cardinal;
  bias:TDateTime;
begin
  GetLocalTime(st);
  tx:=GetTimeZoneInformation(tz);
  case tx of
    0:bias:=tz.Bias/1440.0;
    1:bias:=(tz.Bias+tz.StandardBias)/1440.0;
    2:bias:=(tz.Bias+tz.DaylightBias)/1440.0;
    else bias:=0.0;
  end;
  Result:=
    EncodeDate(st.wYear,st.wMonth,st.wDay)+
    EncodeTime(st.wHour,st.wMinute,st.wSecond,st.wMilliseconds)+
    bias;
end;


var
  rh0,rh1,rh2,rh3,rh4,rh5,rh6,rh7:RegExp;

procedure SanitizeInit;
begin
  rh0:=CoRegExp.Create;
  rh0.Pattern:='[\u0000-\u001F]';
  rh0.Global:=true;
  rh1:=CoRegExp.Create;
  rh1.Pattern:='&';
  rh1.Global:=true;
  rh2:=CoRegExp.Create;
  rh2.Pattern:='<';
  rh2.Global:=true;
  rh3:=CoRegExp.Create;
  rh3.Pattern:='>';
  rh3.Global:=true;
  rh4:=CoRegExp.Create;
  rh4.Pattern:='"';
  rh4.Global:=true;
  rh5:=CoRegExp.Create;
  rh5.Pattern:='&amp;([a-z]+?);';
  rh5.Global:=true;
  rh6:=CoRegExp.Create;
  rh6.Pattern:='&lt;(i|b|u|s|em|strong)&gt;(.+?)&lt;/\1&gt;';
  rh6.Global:=true;
  rh6.IgnoreCase;
  rh7:=CoRegExp.Create;
  rh7.Pattern:='&amp;(#x?[0-9a-f]+?|[0-9]+?);';
  rh7.Global:=true;
  rh7.IgnoreCase:=true;
end;

function SanitizeTitle(const title:WideString):WideString;
begin
  Result:=
    rh7.Replace(
    rh6.Replace(
    rh5.Replace(
    rh4.Replace(
    rh3.Replace(
    rh2.Replace(
    rh1.Replace(
    rh0.Replace(
      title
      ,' ')//rh0
      ,'&amp;')//rh1
      ,'&lt;')//rh2
      ,'&gt;')//rh3
      ,'&quot;')//rh4
      ,'&$1;')//rh5
      ,'<$1>$2</$1>')//rh6
      ,'&$1;')//rh7
  ;
  if Result='' then Result:='&nbsp;&nbsp;&nbsp;';
end;

procedure DoFeed(db:TDataConnection;qr:TQueryResult);
var
  r:ServerXMLHTTP60;
  doc:DOMDocument60;
  xl,xl1:IXMLDOMNodeList;
  x,y:IXMLDOMElement;
  feedid:integer;
  feedurl,feedresult,itemid,itemurl:string;
  feedname,title,content:WideString;
  feedload,pubDate:TDateTime;
  feedregime:integer;
  feedglobal,b:boolean;
  rc,c1,c2,postid:integer;
const
  regimesteps=8;
  regimestep:array[0..regimesteps-1] of integer=(1,2,3,7,14,30,60,90);

  procedure regItem;
  var
    qr:TQueryResult;
    b:boolean;
  begin
    if Copy(itemid,1,7)='http://' then
      itemid:=Copy(itemid,8,Length(itemid)-7)
    else
      if Copy(itemid,1,8)='https://' then
        itemid:=Copy(itemid,9,Length(itemid)-8);

    //TODO: switch: allow future posts?
    if pubDate>feedload+2.0/24.0 then pubDate:=feedload;

    if pubDate<OldPostsCutOff then b:=false else
     begin
      if feedglobal then
        qr:=TQueryResult.Create(db,
          'select P.id from Post P'
          +' inner join Feed F on F.id=P.feed_id'
          +' where P.guid=? and ifnull(F.flags,0)&1=1'
          ,[itemid])
      else
        qr:=TQueryResult.Create(db,
          'select id from Post where feed_id=? and guid=?'
          ,[feedid,itemid]);
      try
        b:=qr.EOF;
      finally
        qr.Free;
      end;
     end;
    inc(c1);
    if b then
     begin
      inc(c2);
      postid:=db.Insert('Post',
        ['feed_id',feedid
        ,'guid',itemid
        ,'title',SanitizeTitle(title)
        ,'content',content
        ,'url',itemurl
        ,'pubdate',pubDate
        ,'created',UtcNow
        ],'id');
      db.Execute('insert into UserPost (user_id,post_id)'+
        ' select S.user_id,? from Subscription S where S.feed_id=?',[postid,feedid]);
     end;
  end;

  procedure combineURL(const s:string);
  var
    i,l:integer;
  begin
    if LowerCase(Copy(s,1,4))='http' then
      feedurl:=s
    else
    if s[1]='/' then
     begin
      i:=5;
      l:=Length(feedurl);
      //"http://"
      while (i<=l) and (feedurl[i]<>'/') do inc(i);
      inc(i);
      while (i<=l) and (feedurl[i]<>'/') do inc(i);
      inc(i);
      //then to the next "/"
      while (i<=l) and (feedurl[i]<>'/') do inc(i);
      feedurl:=Copy(feedurl,1,i-1)+s;
     end
    else
     begin
      i:=Length(feedurl);
      while (i<>0) and (feedurl[i]<>'/') do dec(i);
      feedurl:=Copy(feedurl,1,i-1)+s;
     end;
  end;

  function findFeedURL(const rd:WideString):boolean;
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
    //TODO: <link rel="alternate"?
    reLink.Pattern:='<link[^>]+?(type|href)=["'']([^"'']+?)["''][^>]+?(type|href)=["'']([^"'']+?)["''][^>]*?>';
    mc:=reLink.Execute(rd) as MatchCollection;
    i:=0;
    while (i<mc.Count) and not(Result) do
     begin
      m:=mc[i] as Match;
      inc(i);
      sm:=m.SubMatches as SubMatches;
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
          combineURL(sm[s2]);
          feedresult:='Feed URL found in content, updating (RSS)';
          Result:=true;
         end
        else
        if (sm[s1]='application/atom') or (sm[s1]='text/atom') then
         begin
          combineURL(sm[s2]);
          feedresult:='Feed URL found in content, updating (Atom)';
          Result:=true;
         end;
     end;
    //search for <meta http-equiv="refresh"> redirects
    if not(Result) then
     begin
      reLink.Pattern:='<meta[^>]+?http-equiv=["'']?refresh["'']?[^>]+?content=["'']\d+?;url=([^"'']+?)["''][^>]*?>';
      mc:=reLink.Execute(rd) as MatchCollection;
      if (mc.Count<>0) and (sm[0]<>'') then
       begin
        combineURL(((mc[0] as Match).SubMatches as SubMatches)[0]);
        feedresult:='Meta redirect found, updating URL';
        Result:=true;
       end;
     end;
  end;

var
  d:TDateTime;
  i:integer;
  loadlast,postlast,postavg:double;
  rw,rt,s:WideString;
  rf:TFileStream;
begin
  feedid:=qr.GetInt('id');
  feedurl:=qr.GetStr('url');
  feedload:=UtcNow;
  feedname:=qr.GetStr('name');
  feedregime:=qr.GetInt('regime');
  feedresult:='';

  Write(IntToStr(feedid)+':'+feedurl);

  //flags
  i:=qr.GetInt('flags');
  feedglobal:=(i and 1)<>0;
  //TODO: more?

  //check feed timing and regime
  if qr.IsNull('postlast') then postlast:=0.0 else postlast:=qr['postlast'];
  if qr.IsNull('postavg') then postavg:=0.0 else postavg:=qr['postavg'];
  if qr.IsNull('loadlast') then loadlast:=0.0 else loadlast:=qr['loadlast'];
  if postlast=0.0 then
    if loadlast=0.0 then
      d:=feedload-5.0/1440.0
    else
      d:=loadlast+feedregime
  else
   begin
    d:=postlast+postavg-5.0/1440.0;
    if (loadlast<>0.0) and (d<loadlast) then
      d:=loadlast+feedregime;
   end;
  b:=d<feedload;

  c1:=0;
  c2:=0;
  if b then
   begin
    try
      rc:=0;
      r:=CoServerXMLHTTP60.Create;
      while b do
       begin
        b:=false;
        r.open('GET',feedurl,false,EmptyParam,EmptyParam);
        r.setRequestHeader('Accept','application/rss+xml, application/atom+xml, application/xml, text/xml');
        r.setRequestHeader('Cache-Control','max-age=0');
        if Pos('tumblr.com',feedurl)<>0 then
         begin
          r.setRequestHeader('User-Agent','Mozilla/5.0 (Windows NT 10.0; Win64; x'+
            '64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.99 Safar'+
            'i/537.36');
          r.setRequestHeader('Cookie','_ga=GA1.2.23714421.1433010142; rxx=2kenj37'+
            'frug.zcwv3sm&v=1; __utma=189990958.23714421.1433010142.1515355375.15'+
            '15513281.39; tmgioct=5b490b2e517e660612702270; pfg=324066a0306b92f0b'+
            '5346487b1309edb56a909231a6bc33a78f47993e4b695ef%23%7B%22eu_resident%'+
            '22%3A1%2C%22gdpr_is_acceptable_age%22%3A1%2C%22gdpr_consent_core%22%'+
            '3A1%2C%22gdpr_consent_first_party_ads%22%3A1%2C%22gdpr_consent_third'+
            '_party_ads%22%3A1%2C%22gdpr_consent_search_history%22%3A1%2C%22exp%2'+
            '2%3A1563049750%2C%22vc%22%3A%22%22%7D%238216174849');
         end
        else
          r.setRequestHeader('User-Agent','FeedEater/1.0');
        r.send(EmptyParam);
        if r.status=301 then //moved permanently
         begin
          feedurl:=r.getResponseHeader('Location');
          b:=true;
          inc(rc);
          if rc=8 then
            raise Exception.Create('max redirects exceeded');
         end;
       end;
      if r.status<>200 then
        feedresult:='[HTTP:'+IntToStr(r.status)+']'+r.statusText;
    except
      on e:Exception do
        feedresult:='['+e.ClassName+']'+e.Message;
    end;

    rw:=r.responseText;
    rt:=r.getResponseHeader('Content-Type');
    i:=1;
    while (i<=Length(rt)) and (rt[i]<>';') do inc(i);
    if (i<Length(rt)) then SetLength(rt,i-1);
    r:=nil;

    if SaveData then
     begin
      rf:=TFileStream.Create('xmls\'+Format('%.4d',[feedid])+'.xml',fmCreate);
      try
        i:=$FEFF;
        rf.Write(i,2);
        rf.Write(rw[1],Length(rw)*2);
      finally
        rf.Free;
      end;
     end;

    //sanitize unicode
    for i:=1 to Length(rw) do
      case word(rw[i]) of
        0..8,11,12,14..31:rw[i]:=#9;
        9,10,13:;//leave as-is
        else ;//leave as-is
      end;

    db.BeginTrans;
    try

      if feedresult='' then
        try
          doc:=CoDOMDocument60.Create;
          doc.async:=false;
          doc.validateOnParse:=false;
          doc.resolveExternals:=false;

          if doc.loadXML(rw) then
           begin

            //atom
            if doc.documentElement.nodeName='feed' then
             begin
              if doc.namespaces.length=0 then
                s:='xmlns:atom=''http://www.w3.org/2005/Atom'''
              else
                s:='xmlns:atom='''+doc.namespaces[0]+'''';
              doc.setProperty('SelectionNamespaces',s);

              x:=doc.documentElement.selectSingleNode('atom:title') as IXMLDOMElement;
              if x<>nil then feedname:=x.text;

              xl:=doc.documentElement.selectNodes('atom:entry');
              x:=xl.nextNode as IXMLDOMElement;
              while x<>nil do
               begin
                itemid:=x.selectSingleNode('atom:id').text;
                if Copy(itemid,1,4)='http' then
                  itemurl:=itemid
                else
                 begin
                  xl1:=x.selectNodes('atom:link');
                  y:=xl1.nextNode as IXMLDOMElement;
                  if y=nil then
                    itemurl:=itemid
                  else
                    itemurl:=y.getAttribute('href');//default
                  while y<>nil do
                   begin
                    //'rel'?
                    if y.getAttribute('type')='text/html' then
                      itemurl:=y.getAttribute('href');
                    y:=xl1.nextNode as IXMLDOMElement;
                   end;
                 end;
                title:=x.selectSingleNode('atom:title').text;
                y:=x.selectSingleNode('atom:content') as IXMLDOMElement;
                if y=nil then
                  y:=x.selectSingleNode('atom:summary') as IXMLDOMElement;
                if y=nil then content:='' else content:=y.text;
                try
                  y:=x.selectSingleNode('atom:updated') as IXMLDOMElement;
                  if y=nil then y:=x.selectSingleNode('atom:modified') as IXMLDOMElement;
                  if y=nil then y:=x.selectSingleNode('atom:published') as IXMLDOMElement;
                  if y=nil then y:=x.selectSingleNode('atom:issued') as IXMLDOMElement;
                  if y=nil then pubDate:=UtcNow else pubDate:=ConvDate1(y.text);
                except
                  pubDate:=UtcNow;
                end;
                regItem;

                x:=xl.nextNode as IXMLDOMElement;
               end;
              feedresult:=Format('Atom %d/%d',[c2,c1]);
             end
            else

            //RSS
            if doc.documentElement.nodeName='rss' then
             begin
              doc.setProperty('SelectionNamespaces','xmlns:content="http://purl.org/rss/1.0/modules/content/"');

              x:=doc.documentElement.selectSingleNode('channel/title') as IXMLDOMElement;
              if x<>nil then feedname:=x.text;

              xl:=doc.documentElement.selectNodes('channel/item');
              x:=xl.nextNode as IXMLDOMElement;
              while x<>nil do
               begin
                y:=x.selectSingleNode('guid') as IXMLDOMElement;
                if y=nil then y:=x.selectSingleNode('link') as IXMLDOMElement;
                itemid:=y.text;
                itemurl:=x.selectSingleNode('link').text;
                title:=x.selectSingleNode('title').text;
                y:=x.selectSingleNode('content:encoded') as IXMLDOMElement;
                if y=nil then
                  y:=x.selectSingleNode('content') as IXMLDOMElement;
                if y=nil then
                  y:=x.selectSingleNode('description') as IXMLDOMElement;
                if y=nil then content:='' else content:=y.text;
                try
                  y:=x.selectSingleNode('pubDate') as IXMLDOMElement;
                  if y=nil then pubDate:=UtcNow else pubDate:=ConvDate2(y.text);
                except
                  pubDate:=UtcNow;
                end;
                regItem;

                x:=xl.nextNode as IXMLDOMElement;
               end;
              feedresult:=Format('RSS %d/%d',[c2,c1]);
             end
            else

            //RDF
            if doc.documentElement.nodeName='rdf:RDF' then
             begin
              doc.setProperty('SelectionNamespaces','xmlns:rss=''http://purl.org/rss/1.0/'''+
               ' xmlns:dc=''http://purl.org/dc/elements/1.1/''');

              x:=doc.documentElement.selectSingleNode('rss:channel/rss:title') as IXMLDOMElement;
              if x<>nil then feedname:=x.text;

              xl:=doc.documentElement.selectNodes('rss:item');
              x:=xl.nextNode as IXMLDOMElement;
              while x<>nil do
               begin
                itemid:=x.getAttribute('rdf:about');
                itemurl:=x.selectSingleNode('rss:link').text;
                title:=x.selectSingleNode('rss:title').text;
                y:=x.selectSingleNode('rss:description') as IXMLDOMElement;
                if y=nil then content:='' else content:=y.text;
                try
                  y:=x.selectSingleNode('rss:pubDate') as IXMLDOMElement;
                  if y=nil then
                   begin
                    y:=x.selectSingleNode('dc:date') as IXMLDOMElement;
                    if y=nil then pubDate:=UtcNow else pubDate:=ConvDate1(y.text);
                   end
                  else pubDate:=ConvDate2(y.text);
                except
                  pubDate:=UtcNow;
                end;
                regItem;

                x:=xl.nextNode as IXMLDOMElement;
               end;

              feedresult:=Format('RDF %d/%d',[c2,c1]);
             end
            else

            //unknown
              if not((rt='text/html') and findFeedURL(rw)) then
              feedresult:='Unkown "'+doc.documentElement.tagName+'" ('
                +rt+')';

           end
          else
          //XML parse failed
            if not((rt='text/html') and findFeedURL(rw)) then
              feedresult:='[XML'+IntToStr(doc.parseError.line)+':'+
                IntToStr(doc.parseError.linepos)+']'+doc.parseError.Reason;

        except
          on e:Exception do
            feedresult:='['+e.ClassName+']'+e.Message;
        end;

      if (feedresult<>'') and (feedresult[1]='[') then
       begin
        Writeln(' !!!');
        Writeln(ErrOutput,feedresult);
       end
      else
       begin
        //stale? update regime
        if (c2=0) and (c1<>0) then
         begin
          i:=0;
          while (i<regimesteps) and (feedregime>=regimestep[i]) do inc(i);
          if (i<regimesteps) and ((postlast=0.0)
            or (postlast+regimestep[i]*2<feedload)) then
           begin
            feedresult:=feedresult+' (stale? r:'+IntToStr(feedregime)+
              '->'+IntToStr(regimestep[i])+')';
            feedregime:=regimestep[i];
           end;
         end
        else
         begin
          //not stale: update regime to apparent post average period
          if feedregime<>0 then
           begin
            i:=regimesteps;
            while (i<>0) and (postavg<regimestep[i-1]) do dec(i);
            if i=0 then feedregime:=0 else feedregime:=regimestep[i-1];
           end;
         end;

        Writeln(' '+feedresult);
       end;

      if qr.IsNull('itemcount') or
        (feedurl<>qr.GetStr('url')) or (feedname<>qr.GetStr('name')) then
        db.Update('Feed',
          ['id',feedid
          ,'name',feedname
          ,'url',feedurl
          ,'loadlast',feedload
          ,'result',feedresult
          ,'loadcount',c2
          ,'itemcount',c1
          ,'regime',feedregime
          ])
      else
        db.Update('Feed',
          ['id',feedid
          ,'loadlast',feedload
          ,'result',feedresult
          ,'loadcount',c2
          ,'itemcount',c1
          ,'regime',feedregime
          ]);

      db.CommitTrans;
    except
      db.RollbackTrans;
      raise;
    end;
   end
  else
    Writeln(' Skip '+
      IntToStr(Round((d-feedload)*1440.0))+''' regime:'+IntToStr(feedregime));
end;

procedure DoProcessParams;
var
  i:integer;
  s:string;
begin
  SaveData:=false;
  RunContinuous:=0;
  FeedID:=0;

  for i:=1 to ParamCount do
   begin
    s:=ParamStr(i);
    if s='/s' then SaveData:=true
    else
    if s='/c' then RunContinuous:=15
    else
    if Copy(s,1,2)='/c' then RunContinuous:=StrToInt(Copy(s,3,99))
    else
    if Copy(s,1,2)='/f' then FeedID:=StrToInt(Copy(s,3,99))
    else
      raise Exception.Create('Unknown parameter #'+IntToStr(i));
   end;

  SanitizeInit;
end;

function DoCheckRunDone:boolean;
var
  RunNext,d:TDateTime;
  i:integer;
begin
  if RunContinuous=0 then
    Result:=true
  else
   begin

    RunNext:=LastRun+RunContinuous/1440.0;
    d:=UtcNow;
    while d<RunNext do
     begin
      i:=Round((RunNext-d)*86400.0);
      Write(Format(#13'Waiting %.2d:%.2d',[i div 60,i mod 60]));
      //TODO: check std-in?
      //Result:=Eof(Input);
      Sleep(1000);//?
      d:=UtcNow;
     end;
    Writeln(#13'>>> '+FormatDateTime('yyyy-mm-dd hh:nn:ss',d));

    Result:=false;
   end;
end;

procedure DoUpdateFeeds;
var
  db:TDataConnection;
  qr:TQueryResult;
  i,j:integer;
  w,w1:WideString;
begin
  LastRun:=UtcNow;
  db:=TDataConnection.Create(FeederDBPath);
  try
    db.BusyTimeout:=30000;

    i:=Trunc(LastRun*2.0-0.302);//twice a day on some off-hour
    if LastClean<>i then
     begin
      LastClean:=i;

      db.BeginTrans;
      try

        Write('Clean-up old...');
        OldPostsCutOff:=UtcNow-OldPostsDays;
        i:=db.Execute('delete from UserPost where post_id in (select id from Post where pubdate<?)',[OldPostsCutOff]);
        j:=db.Execute('delete from Post where pubdate<?',[OldPostsCutOff]);
        Writeln(Format(' [%d,%d]',[j,i]));

        Write('Clean-up unused...');
        db.Execute('delete from UserPost where post_id in (select P.id from Post P where P.feed_id in (select F.id from Feed F where not exists (select S.id from Subscription S where S.feed_id=F.id)))');
        j:=db.Execute('delete from Post where feed_id in (select F.id from Feed F where not exists (select S.id from Subscription S where S.feed_id=F.id))');
        i:=db.Execute('delete from Feed where not exists (select S.id from Subscription S where S.feed_id=Feed.id)');
        Writeln(Format(' [%d,%d]',[j,i]));

//TRANSITIONAL
if SaveData then
begin
Writeln('Fixing...');
      db.Execute('update Post set guid=substr(guid,8) where substr(guid,1,7)=''http://''');
      db.Execute('update Post set guid=substr(guid,9) where substr(guid,1,8)=''https://''');

      qr:=TQueryResult.Create(db,'select id, title from Post where title like ''%&%'' or title like ''%<%'' or title like ''%>%''');
      try
        while qr.Read do
         begin
          w1:=qr.GetStr('title');
          w:=SanitizeTitle(w1);
          if w<>w1 then
           begin
            i:=qr.GetInt('id');
            db.Execute('update Post set title=? where id=?',[w,i]);
            Writeln(Format('%d:%s',[i,w]));
           end;
         end;
      finally
        qr.Free;
      end;
end;

        db.CommitTrans;
      except
        db.RollbackTrans;
        raise;
      end;
     end;


    qr:=TQueryResult.Create(db,
      'select * from Feed F'
      +' left outer join ('
      +'   select X.feed_id, max(X.pubdate) as postlast, avg(X.pd) as postavg'
      +'   from('
      +'     select'
      +'     P1.feed_id, P1.pubdate, min(P2.pubdate-P1.pubdate) as pd'
      +'     from Post P1'
      +'     inner join Post P2 on P2.feed_id=P1.feed_id and P2.pubdate>P1.pubdate'
      +'     group by P1.feed_id, P1.pubdate'
      +'   ) X'
      +'   group by X.feed_id'
      +' ) X on X.feed_id=F.id'
      +' where ? in (0,F.id)',[FeedID]);
    try
      while qr.Read do
        DoFeed(db,qr);
    finally
      qr.Free;
    end;

  finally
    db.Free;
  end;
end;

initialization
  LastClean:=0;
end.
