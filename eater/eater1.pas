unit eater1;

interface

uses SysUtils;

procedure OutLn(const x:string);
procedure ErrLn(const x:string);

procedure DoProcessParams;
procedure DoUpdateFeeds;
function DoCheckRunDone:boolean;

//TODO: from ini
const
  FeederIniPath='..\..\feeder.ini';
  AvgPostsDays=100;
  OldPostsDays=3660;

implementation

uses Classes, Windows, DataLank, MSXML2_TLB, Variants, VBScript_RegExp_55_TLB,
  SQLite, jsonDoc;

procedure OutLn(const x:string);
begin
  WriteLn(FormatDateTime('hh:nn:ss.zzz ',Now)+x);
end;

procedure ErrLn(const x:string);
begin
  WriteLn(ErrOutput,FormatDateTime('hh:nn:ss.zzz ',Now)+x);
end;

procedure Out0(const x:string);
begin
  Write(FormatDateTime('hh:nn:ss.zzz ',Now)+x);
end;


var
  OldPostsCutOff,LastRun:TDateTime;
  SaveData,FeedAll,WasLockedDB:boolean;
  FeedID,RunContinuous,LastClean:integer;
  FeedOrderBy:UTF8String;

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
      if (i<=l) and (AnsiChar(x[i]) in ['0'..'9']) then
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
        b1:=-1; inc(i);
        nx(b,2); inc(i);//':'
        nx(b0,2); b:=b*100+b0;
       end;
      '-':
       begin
        b1:=+1; inc(i);
        nx(b,2); inc(i);//':'
        nx(b0,2); b:=b*100+b0;
       end;
      'Z':begin b1:=0; b:=0000; end;
      'A'..'M':begin b1:=-1; b:=(byte(x[1])-64)*100; end;
      'N'..'Y':begin b1:=+1; b:=(byte(x[1])-77)*100; end;
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
      if (i<=l) and (AnsiChar(x[i]) in ['0'..'9']) then
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
  while (i<=l) and not(AnsiChar(x[i]) in ['0'..'9']) do inc(i);
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
        b1:=-1;
        inc(i);
        nx(b,4);
       end;
      '-':
       begin
        b1:=+1;
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
            if TimeZoneCode[j][1+k]='-' then b1:=+1 else b1:=-1;
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
  rh0,rh1,rh2,rh3,rh4,rh5,rh6,rh7,rhUTM,rhLFs:RegExp;

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
  rh6.Pattern:='&lt;(i|b|u|s|em|strong|sub|sup)&gt;(.+?)&lt;/\1&gt;';
  rh6.Global:=true;
  rh6.IgnoreCase:=true;
  rh7:=CoRegExp.Create;
  rh7.Pattern:='&amp;(#x?[0-9a-f]+?|[0-9]+?);';
  rh7.Global:=true;
  rh7.IgnoreCase:=true;
  rhUTM:=CoRegExp.Create;
  rhUTM.Pattern:='\?utm_[^\?]+?$';
  rhLFs:=CoRegExp.Create;
  rhLFs.Pattern:='(\x0D?\x0A)+';
  rhLFs.Global:=true;
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
end;

function EncodeNonHTMLContent(const title:WideString):WideString;
begin
  Result:=
    rhLFs.Replace(
    rh3.Replace(
    rh2.Replace(
    rh1.Replace(
      title
      ,'&amp;')//rh1
      ,'&lt;')//rh2
      ,'&gt;')//rh3
      ,'<br />')//rhLFs
  ;
end;

function HTMLEncode(const x:string):string;
begin
  Result:=
    StringReplace(
    StringReplace(
    StringReplace(
      x
      ,'&','&amp;',[rfReplaceAll])
      ,'<','&lt;',[rfReplaceAll])
      ,'>','&gt;',[rfReplaceAll])
  ;
end;

{$IF not Declared(UTF8ToWideString)}
function UTF8ToWideString(const x:UTF8String):WideString;
begin
  Result:=UTF8Decode(x);
end;
{$ENDIF}

function LoadExternal(const URL,FilePath:string): WideString;
var
  si:TStartupInfo;
  pi:TProcessInformation;
  f:TFileStream;
  s:UTF8String;
  i:integer;
  w:word;
  r:cardinal;
begin
  WriteLn(' ->');
  DeleteFile(PChar(FilePath));//remove any previous file

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
    ' -A "Accept: application/rss+xml, application/atom+xml, application/xml, text/xml"'+
    ' --user-agent="FeedEater/1.0"'+
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

function StripWhiteSpace(const x:WideString):WideString;
var
  i,j,l:integer;
begin
  l:=Length(x);
  i:=1;
  j:=1;
  SetLength(Result,l);
  while i<=l do
   begin
    if word(x[i])>32 then
     begin
      Result[j]:=x[i];
      inc(j);
     end;
    inc(i);
   end;
  SetLength(Result,j-1);
end;

function IsSomethingEmpty(const x:WideString):boolean;
var
  xx:WideString;
begin
  if Length(x)>60 then Result:=false else
   begin
    xx:=StripWhiteSpace(x);
    Result:=(xx='')
      or (xx='<div></div>');
   end;
end;

procedure DoFeed(dbA,dbX:TDataConnection;qr:TQueryResult;oldPostDate:TDateTime;
  sl:TStringList);
var
  r:ServerXMLHTTP60;
  doc:DOMDocument60;
  jdoc,jn0,jn1,jc0,jc1,jd1:IJSONDocument;
  jnodes,jcaption:IJSONDocArray;
  xl,xl1:IXMLDOMNodeList;
  x,y:IXMLDOMElement;
  feedid:integer;
  feedurl,feedurlskip,feedresult,itemid,itemurl:string;
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
    i:integer;
  begin
    if itemurl='' then itemurl:=itemid;//assert Copy(itemid,1,4)='http'

    if Copy(itemid,1,7)='http://' then
      itemid:=Copy(itemid,8,Length(itemid)-7)
    else
      if Copy(itemid,1,8)='https://' then
        itemid:=Copy(itemid,9,Length(itemid)-8);

    //strip '?utm_'... query string
    if rhUTM.Test(itemid) then itemid:=rhUTM.Replace(itemid,'');

    if feedurlskip<>'' then
     begin
      i:=Pos(feedurlskip,itemid);
      if i<>0 then itemid:=Copy(itemid,1,i-1);
     end;

    //TODO: switch: allow future posts?
    if pubDate>feedload+2.0/24.0 then pubDate:=feedload;

    if pubDate<OldPostsCutOff then b:=false else
     begin
      if feedglobal then
        qr:=TQueryResult.Create(dbX,
          'select P.id from "Post" P'
          +' inner join "Feed" F on F.id=P.feed_id'
          //+' and coalesce(F.flags,0)&1=1'
          +' and F.flags=1'
          +' where P.guid=?'
          ,[itemid])
      else
        qr:=TQueryResult.Create(dbX,
          'select id from "Post" where feed_id=? and guid=?'
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
      if IsSomethingEmpty(title) then title:='['+itemid+']';
      dbA.BeginTrans;
      try
        postid:=dbA.Insert('Post',
          ['feed_id',feedid
          ,'guid',itemid
          ,'title',SanitizeTitle(title)
          ,'content',content
          ,'url',itemurl
          ,'pubdate',pubDate
          ,'created',UtcNow
          ],'id');
        dbA.Execute('insert into "UserPost" (user_id,post_id)'+
          ' select S.user_id,? from "Subscription" S where S.feed_id=?',[postid,feedid]);
        dbA.CommitTrans;
      except
        dbA.RollbackTrans;
        raise;
      end;
      dbX.BeginTrans;
      try
        dbX.Insert('Post',['id',postid,'feed_id',feedid,'guid',itemid,'pubdate',pubDate]);
        dbX.CommitTrans;
      except
        dbX.RollbackTrans;
        raise;
      end;
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
  i,j:integer;
  loadlast,postlast,postavg,margin:double;
  loadext:boolean;
  rw,rt,s,sql1,sql2:WideString;
  rf:TFileStream;
  qr1:TQueryResult;
begin
  feedid:=qr.GetInt('id');
  feedurl:=qr.GetStr('url');
  feedurlskip:=qr.GetStr('urlskip');
  feedload:=UtcNow;
  feedname:=qr.GetStr('name');
  feedregime:=qr.GetInt('regime');
  feedresult:='';

  Out0(IntToStr(feedid)+':'+feedurl);

  //flags
  i:=qr.GetInt('flags');
  //feedglobal:=(i and 1)<>0;
  feedglobal:=i=1;
  //TODO: more?

  sl.Add('<tr>');
  sl.Add('<td style="text-align:right;">'+IntToStr(feedid)+'</td>');
  sl.Add('<td class="n" title="'+FormatDateTime('yyyy-mm-dd hh:nn:ss',feedload)+'">');
  if feedglobal then
    sl.Add('<div class="flag" style="background-color:red;">g</div>&nbsp;');
  sl.Add('<a href="'+HTMLEncode(feedurl)+'" title="'+HTMLEncode(feedname)+'">'+HTMLEncode(feedname)+'</a></td>');
  sl.Add('<td>'+FormatDateTime('yyyy-mm-dd hh:nn',qr.GetDate('created'))+'</td>');
  sl.Add('<td style="text-align:right;">'+VarToStr(qr['scount'])+'</td>');

  //check feed timing and regime
  qr1:=TQueryResult.Create(dbX,
    'select id from "Post" where feed_id=? order by 1 desc limit 1000,1',[feedid]);
  try
    if qr1.EOF then
     begin
      sql1:='';
      sql2:='';
     end
    else
     begin
      sql1:=' and P1.id>'+IntToStr(qr1.GetInt('id'));
      sql2:=' and P2.id>'+IntToStr(qr1.GetInt('id'));
     end;
  finally
    qr1.Free;
  end;
  qr1:=TQueryResult.Create(dbX,UTF8Encode(
     'select max(X.pubdate) as postlast, avg(X.pd) as postavg'
    +' from('
    +'  select'
    +'  P2.pubdate, min(P2.pubdate-P1.pubdate) as pd'
    +'  from "Post" P1'
    +'  inner join "Post" P2 on P2.feed_id=P1.feed_id'+sql2+' and P2.pubdate>P1.pubdate'
    +'  where P1.feed_id=?'+sql1+' and P1.pubdate>?'
    +'  group by P2.pubdate'
    +' ) X')
  ,[feedid,oldPostDate]);
  try
    if qr1.EOF or qr1.IsNull('postlast') then postlast:=0.0 else postlast:=qr1['postlast'];
    if qr1.EOF or qr1.IsNull('postavg') then postavg:=0.0 else postavg:=qr1['postavg'];
  finally
    qr1.Free;
  end;
  if qr.IsNull('loadlast') then loadlast:=0.0 else loadlast:=qr['loadlast'];

  margin:=(RunContinuous+5)/1440.0;
  if postlast=0.0 then
   begin
    sl.Add('<td class="empty">&nbsp;</td>');
    if loadlast=0.0 then
      d:=feedload-margin
    else
      d:=loadlast+feedregime;
   end
  else
   begin
    sl.Add('<td>'+FormatDateTime('yyyy-mm-dd hh:nn',postlast)+'</td>');
    d:=postlast+postavg-margin;
    if (loadlast<>0.0) and (d<loadlast) then
      d:=loadlast+feedregime-margin;
   end;
  b:=(d<feedload) or FeedAll;

  if postavg=0.0 then
    sl.Add('<td class="empty">&nbsp;</td>')
  else
  if postavg>1.0 then
    sl.Add('<td style="text-align:right;background-color:#FFFFCC;">'+IntToStr(Round(postavg))+' days</td>')
  else
    sl.Add('<td style="text-align:right;">'+IntToStr(Round(postavg*1440.0))+' mins</td>');
  if feedregime=0 then
    sl.Add('<td class="empty">&nbsp;</td>')
  else
    sl.Add('<td style="text-align:right;">'+IntToStr(feedregime)+'</td>');
  if qr.IsNull('loadlast') then
    sl.Add('<td class="empty">&nbsp;</td><td class="empty">&nbsp;</td>')
  else
   begin
    sl.Add('<td>'+FormatDateTime('yyyy-mm-dd hh:nn',loadlast)+'</td>');
    loadlast:=UtcNow-loadlast;
    if loadlast>1.0 then
      sl.Add('<td style="text-align:right;background-color:#FFFFCC;">'+IntToStr(Round(loadlast))+' days</td>')
    else
      sl.Add('<td style="text-align:right;">'+IntToStr(Round(loadlast*1440.0))+' mins</td>');
   end;

  //Write(?

  c1:=0;
  c2:=0;
  if b then
   begin
    try

      loadext:=FileExists('feeds\'+Format('%.4d',[feedid])+'.txt');
      if loadext then                  
       begin
        rw:=LoadExternal(feedurl,'xmls\'+Format('%.4d',[feedid])+'.xml');
        rt:='text/html';//?? here just to enable search for <link>s
       end
      else
       begin
        rc:=0;
        while b do
         begin
          b:=false;
          Write(':');
          r:=CoServerXMLHTTP60.Create;

          if Copy(feedurl,1,9)='sparql://' then
           begin
            r.open('GET','https://'+Copy(feedurl,10,Length(feedurl)-9)+
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
          if Copy(feedurl,1,26)='https://www.instagram.com/' then
           begin
            r.open('GET',feedurl,false,EmptyParam,EmptyParam);
            //+'?__a=1'?
            r.setRequestHeader('Accept','text/html');
           end
          else
           begin
            r.open('GET',feedurl,false,EmptyParam,EmptyParam);
            if Pos('sparql',feedurl)<>0 then
              r.setRequestHeader('Accept','application/sparql-results+xml, application/xml, text/xml')
            else
              r.setRequestHeader('Accept','application/rss+xml, application/atom+xml, application/xml, text/xml');
           end;
          r.setRequestHeader('Cache-Control','no-cache, no-store, max-age=0');
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
        if r.status=200 then
         begin

          Write(':');
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

         end
        else
          feedresult:='[HTTP:'+IntToStr(r.status)+']'+r.statusText;
       end;
    except
      on e:Exception do
        feedresult:='['+e.ClassName+']'+e.Message;
    end;

    //sanitize unicode
    for i:=1 to Length(rw) do
      case word(rw[i]) of
        0..8,11,12,14..31:rw[i]:=#9;
        9,10,13:;//leave as-is
        else ;//leave as-is
      end;

    if feedresult='' then
      try

        if Copy(feedurl,1,26)='https://www.instagram.com/' then
         begin

          i:=1;
          while (i<Length(rw)-8) and (Copy(rw,i,11)<>'"graphql":{') do
            inc(i);
          inc(i,10);

          jnodes:=JSONDocArray;
          jdoc:=JSON(['user{'
            ,'edge_felix_video_timeline{','edges',jnodes,'}'
            ,'edge_owner_to_timeline_media{','edges',jnodes,'}'
            ,'edge_saved_media{','edges',jnodes,'}'
            ,'edge_media_collections{','edges',jnodes,'}'
            ]);
          try
            jdoc.Parse(Copy(rw,i,Length(rw)-i+1));
          except
            on EJSONDecodeException do
              ;//ignore "data past end"
          end;

          jd1:=JSON(jdoc['user']);
          if jd1<>nil then
            feedname:='Instagram: '+VarToStr(jd1['full_name'])+' (@'+VarToStr(jd1['username'])+')';

          jcaption:=JSONDocArray;
          jn1:=JSON(['edge_media_to_caption{','edges',jcaption]);
          jn0:=JSON(['node',jn1]);
          jc1:=JSON;
          jc0:=JSON(['node',jc1]);
          for i:=0 to jnodes.Count-1 do
           begin
            jnodes.LoadItem(i,jn0);

            itemid:=VarToStr(jn1['id']);
            if itemid='' then raise Exception.Create('edge node without ID');
            itemurl:='https://www.instagram.com/p/'+VarToStr(jn1['shortcode'])+'/';
            pubDate:=int64(jn1['taken_at_timestamp'])/SecsPerDay+UnixDateDelta;//is UTC?

            content:=VarToStr(jn1['title'])+' ';
            for j:=0 to jcaption.Count-1 do
             begin
              jcaption.LoadItem(j,jc0);
              content:=content+VarToStr(jc1['text'])+#13#10;
             end;

            if Length(content)<200 then title:=content else title:=Copy(content,1,99)+'...';
            content:=
              '<a href="'+HTMLEncode(itemurl)+'"><img src="'+
              HTMLEncode(VarToStr(jn1['display_url']))+'" border="0" /></a><br />'#13#10+
              HTMLEncode(content);

            jd1:=JSON(jn1['location']);
            if jd1<>nil then
              content:='<i>'+HTMLEncode(jd1['name'])+'</i><br />'#13#10+content;

            //TODO: likes, views, owner?

            regItem;

           end;

          feedresult:=Format('Instagram %d/%d',[c2,c1]);

         end
        else
         begin


          doc:=CoDOMDocument60.Create;
          doc.async:=false;
          doc.validateOnParse:=false;
          doc.resolveExternals:=false;
          doc.preserveWhiteSpace:=true;
          doc.setProperty('ProhibitDTD',false);

          {
          if loadext then
            b:=doc.load('xmls\'+Format('%.4d',[feedid])+'.xml')
          else
          }
            b:=doc.loadXML(rw);

          if b then
           begin

            //atom
            if doc.documentElement.nodeName='feed' then
             begin
              if doc.namespaces.length=0 then
                s:='xmlns:atom="http://www.w3.org/2005/Atom"'
              else
               begin
                i:=0;
                while (i<doc.namespaces.length) and (doc.namespaces[i]<>'http://www.w3.org/2005/Atom') do inc(i);
                if i=doc.namespaces.length then i:=0;
                s:='xmlns:atom="'+doc.namespaces[i]+'"';
               end;
              s:=s+' xmlns:media="http://search.yahoo.com/mrss/"';
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
                y:=x.selectSingleNode('atom:title') as IXMLDOMElement;
                if y=nil then y:=x.selectSingleNode('media:group/media:title') as IXMLDOMElement;
                if y=nil then title:='' else title:=y.text;
                y:=x.selectSingleNode('atom:content') as IXMLDOMElement;
                if y=nil then y:=x.selectSingleNode('atom:summary') as IXMLDOMElement;
                if y=nil then
                 begin
                  y:=x.selectSingleNode('media:group/media:description') as IXMLDOMElement;
                  if y=nil then
                    content:=''
                  else
                    content:=EncodeNonHTMLContent(y.text);
                 end
                else
                  content:=y.text;
                try
                  y:=x.selectSingleNode('atom:published') as IXMLDOMElement;
                  if y=nil then y:=x.selectSingleNode('atom:issued') as IXMLDOMElement;
                  if y=nil then y:=x.selectSingleNode('atom:modified') as IXMLDOMElement;
                  if y=nil then y:=x.selectSingleNode('atom:updated') as IXMLDOMElement;
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
                y:=x.selectSingleNode('title') as IXMLDOMElement;
                if y=nil then title:='' else title:=y.text;
                y:=x.selectSingleNode('content:encoded') as IXMLDOMElement;
                if (y=nil) or IsSomeThingEmpty(y.text) then
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
                y:=x.selectSingleNode('rss:title') as IXMLDOMElement;
                if y=nil then title:='' else title:=y.text;
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

              if c2=0 then
               begin
                doc.setProperty('SelectionNamespaces',
                 'xmlns:rdf=''http://www.w3.org/1999/02/22-rdf-syntax-ns#'''+
                 ' xmlns:schema=''http://schema.org/''');
                xl:=doc.documentElement.selectNodes('rdf:Description/schema:hasPart/rdf:Description');
                x:=xl.nextNode as IXMLDOMElement;
                while x<>nil do
                 begin
                  itemid:=x.getAttribute('rdf:about');
                  y:=x.selectSingleNode('schema:url') as IXMLDOMElement;
                  if y=nil then itemurl:=itemid else
                    itemurl:=VarToStr(y.getAttribute('rdf:resource'));
                  y:=x.selectSingleNode('schema:headline') as IXMLDOMElement;
                  if y=nil then title:='' else title:=y.text;
                  y:=x.selectSingleNode('schema:description') as IXMLDOMElement;
                  if y<>nil then title:=title+' '#$2014' '+y.text;


                  y:=x.selectSingleNode('schema:articleBody') as IXMLDOMElement;
                  if y=nil then content:='' else content:=y.text;
                  try
                    y:=x.selectSingleNode('schema:datePublished') as IXMLDOMElement;
                    pubDate:=ConvDate1(y.text);
                  except
                    pubDate:=UtcNow;
                  end;
                  regItem;
                  x:=xl.nextNode as IXMLDOMElement;
                 end;
               end;


              feedresult:=Format('RDF %d/%d',[c2,c1]);
             end
            else

            //SPARQL
            if doc.documentElement.nodeName='sparql' then
             begin
              doc.setProperty('SelectionNamespaces',
               'xmlns:s=''http://www.w3.org/2005/sparql-results#''');

              //feedname:=??
              xl:=doc.documentElement.selectNodes('s:results/s:result');
              x:=xl.nextNode as IXMLDOMElement;
              while x<>nil do
               begin
                itemid:=x.selectSingleNode('s:binding[@name="news"]/s:uri').text;
                itemurl:=x.selectSingleNode('s:binding[@name="url"]/s:uri').text;
                title:=x.selectSingleNode('s:binding[@name="headline"]/s:literal').text;

                y:=x.selectSingleNode('s:binding[@name="description"]/s:literal') as IXMLDOMElement;
                if y<>nil then title:=title+' '#$2014' '+y.text;

                y:=x.selectSingleNode('s:binding[@name="body"]/s:literal') as IXMLDOMElement;
                if y=nil then content:='' else content:=y.text;
                try
                  y:=x.selectSingleNode('s:binding[@name="pubDate"]/s:literal') as IXMLDOMElement;
                  pubDate:=ConvDate1(y.text);
                except
                  pubDate:=UtcNow;
                end;
                regItem;
                x:=xl.nextNode as IXMLDOMElement;
               end;

              feedresult:=Format('SPARQL %d/%d',[c2,c1]);
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
         end;

      except
        on e:Exception do
          feedresult:='['+e.ClassName+']'+e.Message;
      end;

    if (feedresult<>'') and (feedresult[1]='[') then
     begin
      Writeln(' !!!');
      ErrLn(feedresult);
     end
    else
     begin
      //stale? update regime
      if (c2=0) and (c1<>0) then
       begin
        i:=0;
        if feedregime>=0 then
         begin
          while (i<regimesteps) and (feedregime>=regimestep[i]) do inc(i);
          if (i<regimesteps) and ((postlast=0.0)
            or (postlast+regimestep[i]*2<feedload)) then
           begin
            feedresult:=feedresult+' (stale? r:'+IntToStr(feedregime)+
              '->'+IntToStr(regimestep[i])+')';
            feedregime:=regimestep[i];
           end;
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

    dbA.BeginTrans;
    try

      if qr.IsNull('itemcount') or
        (feedurl<>qr.GetStr('url')) or (feedname<>qr.GetStr('name')) then
        dbA.Update('Feed',
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
        dbA.Update('Feed',
          ['id',feedid
          ,'loadlast',feedload
          ,'result',feedresult
          ,'loadcount',c2
          ,'itemcount',c1
          ,'regime',feedregime
          ]);

      dbA.CommitTrans;
    except
      dbA.RollbackTrans;
      raise;
    end;
   end
  else
   begin
    Writeln(' Skip '+
      IntToStr(Round((d-feedload)*1440.0))+''' regime:'+IntToStr(feedregime));
    feedresult:=qr.GetStr('result');
    c1:=qr.GetInt('itemcount');
    c2:=qr.GetInt('loadcount');
    feedload:=qr.GetDate('loadlast');
   end;

  if (feedresult+'-')[1]='[' then
    sl.Add('<td style="color:#CC0000;">'+HTMLEncode(feedresult)+'</td>')
  else
    sl.Add('<td>'+HTMLEncode(feedresult)+'</td>');
  if c2=0 then
    sl.Add('<td class="empty">&nbsp;</td>')
  else
    sl.Add('<td style="text-align:right;">'+IntToStr(c2)+'</td>');
  sl.Add('<td style="text-align:right;" title="'+FormatDateTime('yyyy-mm-dd hh:nn:ss',feedload)+'">'+IntToStr(c1)+'</td>');
  sl.Add('</tr>');

end;

procedure DoProcessParams;
var
  i:integer;
  s:string;
begin
  SaveData:=false;
  RunContinuous:=0;
  FeedID:=0;
  FeedAll:=false;
  FeedOrderBy:=' order by F.id';
  WasLockedDB:=false;

  for i:=1 to ParamCount do
   begin
    s:=ParamStr(i);
    if s='/a' then FeedOrderBy:=' order by X.postavg,X.postlast,F.id'
    else
    if s='/s' then SaveData:=true
    else
    if s='/c' then RunContinuous:=15
    else
    if Copy(s,1,2)='/c' then RunContinuous:=StrToInt(Copy(s,3,99))
    else
    if Copy(s,1,2)='/f' then FeedID:=StrToInt(Copy(s,3,99))
    else
    if s='/x' then FeedAll:=true
    else
      raise Exception.Create('Unknown parameter #'+IntToStr(i));
   end;

  SanitizeInit;
end;

function DoCheckRunDone:boolean;
var
  RunNext,d:TDateTime;
  i:integer;
  h:THandle;
  b:TInputRecord;
  c:cardinal;
begin
  if RunContinuous=0 then
    Result:=true
  else
  if WasLockedDB then
   begin
    WasLockedDB:=false;
    Sleep(2500);
    Writeln(#13'>>> '+FormatDateTime('yyyy-mm-dd hh:nn:ss',UtcNow));
    Result:=false;
   end
  else
   begin

    RunNext:=LastRun+RunContinuous/1440.0;
    FeedAll:=false;//only once
    d:=UtcNow;
    while d<RunNext do
     begin
      i:=Round((RunNext-d)*86400.0);
      Write(Format(#13'Waiting %.2d:%.2d',[i div 60,i mod 60]));
      //TODO: check std-in?
      //Result:=Eof(Input);
      Sleep(1000);//?
      d:=UtcNow;


      h:=GetStdHandle(STD_INPUT_HANDLE);
      while WaitForSingleObject(h,0)=WAIT_OBJECT_0 do
       begin
        if not ReadConsoleInput(h,b,1,c) then
          RaiseLastOSError;
        if (c<>0) and (b.EventType=KEY_EVENT) and b.Event.KeyEvent.bKeyDown then
          case b.Event.KeyEvent.AsciiChar of
            's'://skip
             begin
              Writeln(#13'Manual skip    ');
              d:=RunNext;
             end;
            'x'://skip + run all
             begin
              Writeln(#13'Skip + Feed all   ');
              d:=RunNext;
              FeedAll:=true;
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

     end;
    Writeln(#13'>>> '+FormatDateTime('yyyy-mm-dd hh:nn:ss',d));

    Result:=false;
   end;
end;

procedure BackupSQLite(db1:HSQLiteDB;const db2:AnsiString);
var
  b:HSQLiteDB;
  b1:HSQLiteBackup;
  p:integer;
begin
  sqlite3_check(sqlite3_open(PAnsiChar(db2),b));
  try
    b1:=sqlite3_backup_init(b,'main',db1,'main');
    p:=$4000;
    while sqlite3_backup_step(b1,p)<>SQLITE_DONE do
      Write(#13'... '+IntToStr((sqlite3_backup_remaining(b1) div p)+1)+' ');
    Write(#13);//Writeln(#13'Done');
    sqlite3_check(sqlite3_backup_finish(b1));
  finally
    {sqlite3_check}(sqlite3_close(b));
  end;
end;

procedure DoUpdateFeeds;
var
  dbA,dbX:TDataConnection;
  qr:TQueryResult;
  i,j,r:integer;
  sql:UTF8String;
  d:TDateTime;
  sl:TStringList;
  newdb:boolean;
begin
  try
    LastRun:=UtcNow;
    OutLn('Opening databases...');

    dbA:=TDataConnection.Create('..\feeder.db');
    sl:=TStringList.Create;
    try
      dbA.BusyTimeout:=30000;

      sl.Add('<style>');
      sl.Add('TH,TD{font-family:"PT Sans",Calibri,sans-serif;font-size:0.7em;white-space:nowrap;border:1px solid #CCCCCC;}');
      sl.Add('TD.n{max-width:12em;overflow:hidden;text-overflow:ellipsis;}');
      sl.Add('TD.empty{background-color:#CCCCCC;}');
      sl.Add('DIV.flag{display:inline;padding:2pt;border-radius:4pt;white-space:nowrap;}');
      sl.Add('</style>');
      sl.Add('<table cellspacing="0" cellpadding="4" border="1">');
      sl.Add('<tr>');
      sl.Add('<th>&nbsp;</th>');
      sl.Add('<th>name</th>');
      sl.Add('<th>created</th>');
      sl.Add('<th>#</th>');
      sl.Add('<th>post:last</th>');
      sl.Add('<th>post:avg</th>');
      sl.Add('<th>regime</th>');
      sl.Add('<th>load:last</th>');
      sl.Add('<th>:since</th>');
      sl.Add('<th>load:result</th>');
      sl.Add('<th>load:new</th>');
      sl.Add('<th>load:items</th>');
      sl.Add('</tr>');

      //OutLn('Copy for queries...');
      //BackupSQLite(dbA.Handle,'feederX.db');

      newdb:=not(FileExists('feederXX.db'));
      dbX:=TDataConnection.Create('feederXX.db');
      try
        dbX.BusyTimeout:=30000;

        //previous dbX? check post count
        if not newdb then
         begin
          qr:=TQueryResult.Create(dbA,'select count(*) from "Post"',[]);
          try
            i:=qr.GetInt(0);
          finally
            qr.Free;
          end;
          qr:=TQueryResult.Create(dbX,'select count(*) from "Post"',[]);
          try
            j:=qr.GetInt(0);
          finally
            qr.Free;
          end;
          if i<>j then
           begin
            dbX.Free;
            DeleteFile(PChar('feederXX.db'));
            dbX:=TDataConnection.Create('feederXX.db');
            newdb:=true;
           end;
         end;

        if newdb then
         begin
          OutLn('Copy for queries...');
          dbX.Execute('create table "Post" (id integer,'
            +'feed_id integer not null,'
            +'guid varchar(500) not null,'
            +'pubdate datetime not null)');
          dbX.Execute('create index IX_Post on "Post" (feed_id,pubdate)');
          dbX.Execute('create index IX_PostGuid on "Post" (guid,feed_id)');

          dbX.Execute('create table "Feed" (id integer,flags int null)');

          qr:=TQueryResult.Create(dbA,'select id,feed_id,guid,pubdate from "Post" order by id',[]);
          try
            i:=0;
            dbX.BeginTrans;
            try
              while qr.Read do
               begin
                dbX.Insert('Post',
                  ['id',qr['id']
                  ,'feed_id',qr['feed_id']
                  ,'guid',qr['guid']
                  ,'pubdate',qr['pubdate']
                  ]);
                inc(i);
                Write(#13+IntToStr(i)+' posts... ');
               end;
              dbX.CommitTrans;
            except
              dbX.RollbackTrans;
              raise;
            end;
          finally
            qr.Free;
          end;
          Writeln(#13+IntToStr(i)+' posts    ');
         end;

        dbX.BeginTrans;
        try
          dbX.Execute('delete from "Feed"',[]);
          qr:=TQueryResult.Create(dbA,'select * from "Feed" where id>0 order by id',[]);
          try
            i:=0;
            while qr.Read do
             begin
              dbX.Insert('Feed',['id',qr['id'],'flags',qr['flags']]);
              inc(i);
              Write(#13+IntToStr(i)+' feeds... ');
             end;
          finally
            qr.Free;
          end;
          Writeln(#13+IntToStr(i)+' feeds    ');
          dbX.CommitTrans;
        except
          dbX.RollbackTrans;
          raise;
        end;

        i:=Trunc(LastRun*2.0-0.302);//twice a day on some off-hour
        if LastClean<>i then
         begin
          LastClean:=i;

          Out0('Clean-up old...');
          OldPostsCutOff:=UtcNow-OldPostsDays;
          qr:=TQueryResult.Create(dbX,'select id from "Post" where pubdate<?',[OldPostsCutOff]);
          try

            j:=0;
            while qr.Read do
             begin
              i:=qr.GetInt('id');
              dbA.BeginTrans;
              try
                dbA.Execute('delete from "UserPost" where post_id=?',[i]);
                dbA.Execute('delete from "Post" where id=?',[i]);
                dbA.CommitTrans;
              except
                dbA.RollbackTrans;
                raise;
              end;
              dbX.BeginTrans;
              try
                dbX.Execute('delete from "Post" where id=?',[i]);
                dbX.CommitTrans;
              except
                dbX.RollbackTrans;
                raise;
              end;
              inc(j);
             end;
            Writeln(' '+IntToStr(j)+' posts cleaned      ');

          finally
            qr.Free;
          end;

          Out0('Clean-up unused...');
          qr:=TQueryResult.Create(dbA,'select id from "Feed" where id>0'+
            ' and not exists (select S.id from "Subscription" S where S.feed_id="Feed".id)',[]);
          try
            j:=0;
            while qr.Read do
             begin
              i:=qr.GetInt('id');
              Write(#13'... #'+IntToStr(i)+'   ');
              dbA.BeginTrans;
              try
                dbA.Execute('delete from "UserPost" where post_id in (select P.id from "Post" P where P.feed_id=?)',[i]);
                dbA.Execute('delete from "Post" where feed_id=?',[i]);
                dbA.Execute('delete from "Feed" where id=?',[i]);
                dbA.CommitTrans;
              except
                dbA.RollbackTrans;
                raise;
              end;
              dbX.BeginTrans;
              try
                dbX.Execute('delete from "Post" where feed_id=?',[i]);
                dbX.CommitTrans;
              except
                dbX.RollbackTrans;
                raise;
              end;
              inc(j);
             end;
            Writeln(' '+IntToStr(j)+' feeds cleaned      ');

          finally
            qr.Free;
          end;
         end;

        OutLn('Listing feeds...');
        if FeedID=0 then sql:=' where F.id>0' else sql:=UTF8Encode(' where F.id='+IntToStr(FeedID));
        d:=UtcNow-AvgPostsDays;
        qr:=TQueryResult.Create(dbA,'select *'
           +' ,(select count(*) from "Subscription" S where S.feed_id=F.id) as scount'
           +' from "Feed" F'+sql+FeedOrderBy,[]);
        try
          while qr.Read do
           begin
            r:=5;
            while r<>0 do
              try
                DoFeed(dbA,dbX,qr,d,sl);
                r:=0;
              except
                on e:ESQLiteException do
                  if e.ErrorCode=SQLITE_BUSY then
                   begin
                    ErrLn('['+e.ClassName+'#'+IntToStr(r)+']'+e.Message);
                    dec(r);
                    if r=0 then raise;
                   end
                  else
                    raise;
              end;
           end;

        finally
          qr.Free;
        end;

      finally
        dbX.Free;
      end;

      sl.Add('</table>');
      sl.SaveToFile('..\Load.html');

    finally
      dbA.Free;
      sl.Free;
    end;
  except
    on e:Exception do
     begin
      if (e is ESQLiteException) and ((e as ESQLiteException).ErrorCode=SQLITE_BUSY) then
        WasLockedDB:=true;
      ErrLn('['+e.ClassName+']'+e.Message);
      ExitCode:=1;
     end;
  end;
end;

initialization
  LastClean:=0;
end.
