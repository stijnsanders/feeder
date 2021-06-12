unit eater1;

interface

uses SysUtils;

procedure OutLn(const x:string);
procedure ErrLn(const x:string);

procedure DoProcessParams;
procedure DoUpdateFeeds;
//procedure DoAnalyze;
function DoCheckRunDone:boolean;

//TODO: from ini
const
  FeederIniPath='..\..\feeder.ini';
  AvgPostsDays=100;
  OldPostsDays=3660;

var
  FeedNew:boolean;

implementation

uses Classes, Windows, DataLank, MSXML2_TLB, Variants, VBScript_RegExp_55_TLB,
  LibPQ, jsonDoc, ActiveX, ComObj, Vcl.Imaging.JPEG;

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
  OldPostsCutOff,LastRun,RunStart,LastLoadStart,LastLoadDone:TDateTime;
  SaveData,FeedAll,NextAnalyze:boolean;
  FeedID,RunContinuous,LastClean,LastFeedCount,LastPostCount:integer;
  FeedOrderBy,PGVersion:WideString;//UTF8String;
  InstagramTC,InstagramNext,InstagramBadTC,InstagramSuccess:cardinal;
  NewFeedEvent:THandle;

const
  InstagramLoadExternal=true;//TODO: from config?
  InstagramTimeoutMS=80*1000;
  InstagramTimeoutRandomPaddingMS=15*1000;
  InstagramBadTimeoutMS=30*60*1000;

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
  dda:boolean;
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
  while (i<=l) and not(AnsiChar(x[i]) in [',',' ']) do inc(i);
  while (i<=l) and not(AnsiChar(x[i]) in ['0'..'9','A'..'Z']) do inc(i);
  dda:=(i<=l) and (AnsiChar(x[i]) in ['0'..'9']);
  if dda then
   begin
    //day of month
    nx(dd,2);
    inc(i);//' '
   end;
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
  if dda then
    inc(i,4)
  else
   begin
    while (i<=l) and not(x[i]=' ') do inc(i);
    inc(i);//' '
    nx(dd,2);
    inc(i);//',';
    inc(i);//' ';
   end;
  nx(dy,4); inc(i);//' '
  if not dda then inc(i);//','  
  nx(th,2); inc(i);//':'
  nx(tm,2); inc(i);//':'
  if dda then
   begin
    nx(ts,2); inc(i);//' '
   end
  else
   begin
    ts:=0;
    //AM/PM
    if (i<l) and (x[i]='P') and (x[i+1]='M') then
     begin
      if th<>12 then th:=th+12;
      inc(i,3);
     end
    else
    if (i<l) and (x[i]='A') and (x[i+1]='M') then
      inc(i,3);
   end;
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
    //TIME_ZONE_ID_INVALID:RaiseLastOSError;
    TIME_ZONE_ID_UNKNOWN:  bias:=tz.Bias/1440.0;
    TIME_ZONE_ID_STANDARD: bias:=(tz.Bias+tz.StandardBias)/1440.0;
    TIME_ZONE_ID_DAYLIGHT: bias:=(tz.Bias+tz.DaylightBias)/1440.0;
    else                   bias:=0.0;
  end;
  Result:=
    EncodeDate(st.wYear,st.wMonth,st.wDay)+
    EncodeTime(st.wHour,st.wMinute,st.wSecond,st.wMilliseconds)+
    bias;
end;

function VarArrFirst(const v:Variant):Variant;
begin
  if VarIsArray(v) then
    Result:=v[VarArrayLowBound(v,1)]
  else
    Result:=Null;
end;

function VarArrLast(const v:Variant):Variant;
begin
  if VarIsArray(v) then
    Result:=v[VarArrayHighBound(v,1)]
  else
    Result:=Null;
end;


var
  rh0,rh1,rh2,rh3,rh4,rh5,rh6,rh7,rhUTM,rhCID,rhLFs,rhTrim,
  rhStartImg,rhImgData,rhImgFoaf:RegExp;
  blacklist,proxies:TStringList;
  proxiesTC:cardinal;
  proxiesIndex:integer;
  proxiesLoaded:TDateTime;

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
  rh6.Pattern:='&lt;(i|b|u|s|em|strong|sub|sup)&gt;(.*?)&lt;/\1&gt;';
  rh6.Global:=true;
  rh6.IgnoreCase:=true;
  rh7:=CoRegExp.Create;
  rh7.Pattern:='&amp;(#x?[0-9a-f]+?|[0-9]+?);';
  rh7.Global:=true;
  rh7.IgnoreCase:=true;

  rhUTM:=CoRegExp.Create;
  rhUTM.Pattern:='\?utm_[^\?]+?$';
  rhCID:=CoRegExp.Create;
  rhCID.Pattern:='\?cid=public-rss_\d{8}$';

  rhLFs:=CoRegExp.Create;
  rhLFs.Pattern:='(\x0D?\x0A)+';
  rhLFs.Global:=true;

  rhTrim:=CoRegExp.Create;
  rhTrim.Pattern:='^\s*(.*?)\s*$';

  rhStartImg:=CoRegExp.Create;
  rhStartImg.Pattern:='^\s*?(<(div|p)[^>]*?>\s*?)?(<img[^>]*?>)\s*(?!<br)';
  rhStartImg.IgnoreCase:=true;

  rhImgData:=nil;//see WPv2

  rhImgFoaf:=CoRegExp.Create;
  rhImgFoaf.Pattern:='<noscript class="adaptive-image"[^>]*?>(<img typeof="foaf:Image"[^>]*?>)</noscript>';
  rhImgFoaf.Global:=true;
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
  if Length(Result)<5 then Result:=Result+'&nbsp;&nbsp;&nbsp;';  
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

function LoadExternal(const URL,FilePath,LastMod,Accept:string;useProxy:boolean): WideString;
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

  if not(FeedAll) and (LastMod<>'') then
    p1:=' --header="If-Modified-Since: '+LastMod+'"'
  else
    p1:='';

  if useProxy and (proxiesIndex<proxies.Count) then
    p1:=p1+' -e http_proxy='+proxies[proxiesIndex];

  if useProxy then //if 'instagram'
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

const
  Base64Codes:array[0..63] of AnsiChar=
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

  YoutubePrefix1='https://www.youtube.com/channel/';
  YoutubePrefix2='https://www.youtube.com/feeds/videos.xml?channel_id=';

function Base64Encode(const x:UTF8String):UTF8String;
var
  i,j,l:cardinal;
begin
  l:=Length(x);
  i:=(l div 3);
  if (l mod 3)<>0 then inc(i);
  SetLength(Result,i*4);
  i:=1;
  j:=0;
  while (i+2<=l) do
   begin
    inc(j);Result[j]:=Base64Codes[  byte(x[i  ]) shr 2];
    inc(j);Result[j]:=Base64Codes[((byte(x[i  ]) and $03) shl 4)
                                or (byte(x[i+1]) shr 4)];
    inc(j);Result[j]:=Base64Codes[((byte(x[i+1]) and $0F) shl 2)
                                or (byte(x[i+2]) shr 6)];
    inc(j);Result[j]:=Base64Codes[  byte(x[i+2]) and $3F];
    inc(i,3);
   end;
  if i=l then
   begin
    inc(j);Result[j]:=Base64Codes[  byte(x[i  ]) shr 2];
    inc(j);Result[j]:=Base64Codes[((byte(x[i  ]) and $03) shl 4)];
    inc(j);Result[j]:='=';
    inc(j);Result[j]:='=';
   end
  else if i+1=l then
   begin
    inc(j);Result[j]:=Base64Codes[  byte(x[i  ]) shr 2];
    inc(j);Result[j]:=Base64Codes[((byte(x[i  ]) and $03) shl 4)
                                or (byte(x[i+1]) shr 4)];
    inc(j);Result[j]:=Base64Codes[((byte(x[i+1]) and $0F) shl 2)];
    inc(j);Result[j]:='=';
   end;
end;

function Base64EncodeStream_JPEG(const s:IStream):UTF8String;
var
  d:UTF8String;
  i,j:integer;
  l:FixedUInt;
  //p:TJPEGImage;
  //m:TMemoryStream;
begin
  i:=1;
  j:=0;
  l:=1;
  while l<>0 do
   begin
    inc(j,$10000);
    SetLength(d,j);
    OleCheck(s.Read(@d[i],$10000,@l));
    inc(i,l);
   end;
  SetLength(d,i-1);

  {
  m:=TMemoryStream.Create;
  try
    m.Write(d[1],Length(d));
    m.Position:=0;
    p:=TJPEGImage.Create;
    try
      p.LoadFromStream(m);
      p.DIBNeeded;

      //???
      p.CompressionQuality:=75;

      p.Compress;
      m.Size:=0;
      p.SaveToStream(m);
    finally
      p.Free;
    end;

    m.Position:=0;
    SetLength(d,m.Size);
    //Move(m.Memory^,d[1],m.Size);
    m.Read(d[1],m.Size);
  finally
    m.Free;
  end;
  }

  Result:=Base64Encode(d);
end;

function StripWhiteSpace(const x:WideString):WideString;
var
  i,j,k,l:integer;
  w:word;
const
  WhiteSpaceCodesCount=30;
  WhiteSpaceCodes:array[0..WhiteSpaceCodesCount-1] of word=//WideChar=
    ($0009,$000A,$000B,$000C,$000D,$0020,$0085,$00A0,
     $1680,$180E,$2000,$2001,$2002,$2003,$2004,$2005,
     $2006,$2007,$2008,$2009,$200A,$200B,$200C,$200D,
     $2028,$2029,$202F,$205F,$2060,$3000);
begin
  l:=Length(x);
  i:=1;
  j:=1;
  SetLength(Result,l);
  while i<=l do
   begin
    w:=word(x[i]);
    k:=0;
    while (k<WhiteSpaceCodesCount) and (w<>WhiteSpaceCodes[k]) do inc(k);
    if k=WhiteSpaceCodesCount then
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

function StripHTML(const x:WideString;MaxLength:integer):WideString;
var
  i,r:integer;
  b:boolean;
begin
  Result:=#$2039+x+'.....';
  i:=1;
  r:=1;
  b:=false;
  while (i<=length(x)) and (r<MaxLength) do
   begin
    if x[i]='<' then
     begin
      inc(i);
      while (i<=Length(x)) and (x[i]<>'>') do inc(i);
     end
    else
    if x[i]<=' ' then
      b:=r>1
    else
     begin
      if b then
       begin
        inc(r);
        Result[r]:=' ';
        b:=false;
       end;
      inc(r);
      Result[r]:=x[i];
     end;
    inc(i);
   end;
  if (i<Length(x)) then
   begin
    while (r<>0) and (Result[r]<>' ') do dec(r);
    Result[r]:='.';
    inc(r);
    Result[r]:='.';
    inc(r);
    Result[r]:='.';
   end;
  inc(r);
  Result[r]:=#$203A;
  SetLength(Result,r);
end;

function HTMLDecode(const w:WideString):WideString;
var
  i,j,l:integer;
  c:word;
begin
  //just for wp/v2 feedname for now
  //TODO: full HTMLDecode
  Result:=w;
  l:=Length(w);
  i:=1;
  j:=0;
  while (i<=l) do
   begin
    if (i<l) and (w[i]='&') and (w[i+1]='#') then
     begin
      inc(i,2);
      c:=0;
      if w[i]='x' then
       begin
        inc(i);
        while (i<=l) and (w[i]<>';') do
         begin
          if (word(w[i]) and $FFF0)=$0030 then //if w[i] in ['0'..'9'] then
            c:=(c shl 4) or (word(w[i]) or $F)
          else
            c:=(c shl 4) or (9+word(w[i]) or 7);
         end;
       end
      else
        while (i<=l) and (w[i]<>';') do
         begin
          c:=c*10+(word(w[i]) and $F);
          inc(i);
         end;
      inc(j);
      Result[j]:=WideChar(c);
     end
    else
     begin
      inc(j);
      Result[j]:=w[i];
     end;
    inc(i);
   end;
  SetLength(Result,j);
end;

function qrDate(qr:TQueryResult;const Idx:Variant):TDateTime;
var
  d:double;
begin
  d:=qr[Idx];
  Result:=d;
end;

function IsProbablyHTML(const x:WideString):boolean;
var
  i:integer;
begin
  i:=1;
  while (i<=Length(x)) and (x[i]<=' ') do inc(i); //skip whitespace
  Result:=(i<=Length(x)) and (x[i]='<');
end;

procedure PerformReplaces(feedid:integer;var data:WideString);
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
    sl.LoadFromFile('feeds\'+Format('%.4d',[feedid])+'r.json');
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

procedure DoFeed(dbA:TDataConnection;feedid:integer;oldPostDate:TDateTime;
  sl:TStringList);
var
  qr0:TQueryResult;
  r:ServerXMLHTTP60;
  doc:DOMDocument60;
  jdoc,jdoc1,jn0,jn1,jc0,jc1,jd1:IJSONDocument;
  jnodes,jcaption,jthumbs:IJSONDocArray;
  je:IJSONEnumerator;
  xl,xl1:IXMLDOMNodeList;
  x,y:IXMLDOMElement;
  x1:IXMLDOMNode;
  feedurl,feedurl0,feedurlskip,feedresult,itemid,itemurl:string;
  feedname,feedname0,title,content,h1:WideString;
  feedload,pubDate:TDateTime;
  feedregime,feedgroupid:integer;
  feedtagprefix:string;
  feedtags:Variant;
  rc,c1,c2,postid:integer;
  v:Variant;
  re:RegExp;
  hasFoaf,hasReplaces:boolean;
const
  regimesteps=8;
  regimestep:array[0..regimesteps-1] of integer=(1,2,3,7,14,30,60,90);

  function CheckNewItem:boolean;
  var
    qr:TQueryResult;
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
    if rhCID.Test(itemid) then itemid:=rhCID.Replace(itemid,'');

    if feedurlskip<>'' then
     begin
      i:=Pos(feedurlskip,itemid);
      if i<>0 then itemid:=Copy(itemid,1,i-1);
     end;

    //TODO: if feed_flag_trim in feed_flags?
    itemurl:=rhTrim.Replace(itemurl,'$1');

    //relative url
    if (itemurl<>'') and (Copy(itemurl,1,4)<>'http') then
      if itemurl[1]='/' then
       begin
        i:=5;
        while (i<=Length(feedurl)) and (feedurl[i]<>':') do inc(i);
        inc(i);
        if (i<=Length(feedurl)) and (feedurl[i]='/') then inc(i);
        if (i<=Length(feedurl)) and (feedurl[i]='/') then inc(i);
        while (i<=Length(feedurl)) and (feedurl[i]<>'/') do inc(i);
        itemurl:=Copy(feedurl,1,i-1)+itemurl;
       end
      else
       begin
        i:=Length(feedurl);
        while (i<>0) and (feedurl[i]<>'/') do dec(i);
        itemurl:=Copy(feedurl,1,i)+itemurl;
       end;

    //TODO: switch: allow future posts?
    if pubDate>feedload+2.0/24.0 then pubDate:=feedload;

    inc(c1);

    //check age, blacklist, already listed
    Result:=pubDate>=OldPostsCutOff;
    i:=0;
    while Result and (i<blacklist.Count) do
      if (blacklist[i]<>'') and (blacklist[i]=Copy(itemurl,1,Length(blacklist[i]))) then
        Result:=false
      else
        inc(i);
    if Result then
     begin
      if feedgroupid<>0 then
        qr:=TQueryResult.Create(dbA,
          'select P.id from "Post" P'
          +' inner join "Feed" F on F.id=P.feed_id'
          +' and F.group_id=$1'
          +' where P.guid=$2'
          ,[feedgroupid,itemid])
      else
        qr:=TQueryResult.Create(dbA,
          'select id from "Post" where feed_id=$1 and guid=$2'
          ,[feedid,itemid]);
      try
        Result:=qr.EOF;

        //TODO: if feedgroupid<>0 and P.feed_id>feedid then update?

      finally
        qr.Free;
      end;
     end;
  end;

  procedure RegisterItem;
  var
    ti:integer;
    tsql:string;
  begin
    inc(c2);
    if IsSomethingEmpty(title) then
     begin
      title:=StripHTML(content,200);
      if Length(title)<=8 then title:=#$2039+itemid+#$203A;
     end;

    //content starts with <img>? inject a <br />
    if rhStartImg.Test(content) then
      content:=rhStartImg.Replace(content,'$1$3<br />');

    //if feedtagprefix<>'' then
    if VarIsArray(feedtags) and //varArray of varStrSomething?
      (VarArrayDimCount(feedtags)=1) and (VarArrayHighBound(feedtags,1)-VarArrayLowBound(feedtags,1)>0) then
     begin
      tsql:='';
      for ti:=VarArrayLowBound(feedtags,1) to VarArrayHighBound(feedtags,1) do
        tsql:=tsql+' or B.url='''+StringReplace(feedtagprefix+':'+VarToStr(feedtags[ti]),'''','''''',[rfReplaceAll])+'''';
     end
    else
      tsql:='';

    //list the post
    dbA.BeginTrans;
    try
      postid:=dbA.Insert('Post',
        ['feed_id',feedid
        ,'guid',itemid
        ,'title',SanitizeTitle(title)
        ,'content',content
        ,'url',itemurl
        ,'pubdate',double(pubDate)
        ,'created',double(UtcNow)
        ],'id');
      dbA.Execute('insert into "UserPost" (user_id,post_id)'+
        ' select S.user_id,$1 from "Subscription" S'+
        ' left outer join "UserBlock" B on B.user_id=S.user_id'+
        ' and (B.url=left($2,length(B.url))'+tsql+')'+
        ' where S.feed_id=$3 and B.id is null',[postid,itemurl,feedid]);
      dbA.CommitTrans;
    except
      dbA.RollbackTrans;
      raise;
    end;
    inc(LastPostCount);

    feedtagprefix:='';
    VarClear(feedtags);
  end;

  procedure combineURL(const s:string);
  var
    i,l:integer;
  begin
    if LowerCase(Copy(s,1,4))='http' then
      feedurl:=s
    else
    if (Length(s)>1) and (s[1]='/') then
      if (Length(s)>2) and (s[2]='/') then
       begin
        i:=5;
        l:=Length(feedurl);
        while (i<=l) and (feedurl[i]<>'/') do inc(i);
        feedurl:=Copy(feedurl,1,i-1)+s;
       end
     else
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
    reLink.Pattern:='<link[^>]+?(rel|type|href)=["'']([^"'']+?)["''][^>]+?(type|href)=["'']([^"'']+?)["'']([^>]+?(type|href)=["'']([^"'']+?)["''])?[^>]*?>';
    //                          0                    1                    2                3             (4)     5                6
    mc:=reLink.Execute(rd) as MatchCollection;
    i:=0;
    while (i<mc.Count) and not(Result) do
     begin
      m:=mc[i] as Match;
      inc(i);
      sm:=m.SubMatches as SubMatches;
      if (sm[0]='rel') and (sm[1]='https://api.w.org/') and (sm[2]='href') then
       begin
        //TODO: check +'wp/v2/articles'?
        combineURL(sm[3]+'wp/v2/posts');
        feedresult:='Feed URL found in content, updating (WPv2)';

        //extract title
        reLink.Pattern:='<title>([^<]+?)</title>';
        mc:=reLink.Execute(rd) as MatchCollection;
        if mc.Count>0 then
          feedname:=HTMLDecode(((mc[0] as Match).SubMatches as SubMatches)[0]);

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
        //TODO if sm[s1]='application/json'?
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

  function FindPrefixAndCrop(var data:WideString;const pattern:WideString):boolean;
  var
    r:RegExp;
    m:MatchCollection;
    mm:Match;
    l:integer;
  begin
    r:=CoRegExp.Create;
    r.Global:=false;
    r.IgnoreCase:=false;//?
    r.Pattern:=pattern;//??!!
    m:=r.Execute(data) as MatchCollection;
    if m.Count=0 then Result:=false else
     begin
      mm:=m.Item[0] as Match;
      l:=mm.FirstIndex+mm.Length;
      data:=Copy(data,1+l,Length(data)-l);
      Result:=true;
     end;
  end;

  function FindMatch(const data:WideString;const pattern:WideString):WideString;
  var
    r:RegExp;
    m:MatchCollection;
    sm:SubMatches;
  begin
    r:=CoRegExp.Create;
    r.Global:=false;
    r.IgnoreCase:=false;//?
    r.Pattern:=pattern;
    m:=r.Execute(data) as MatchCollection;
    if m.Count=0 then Result:='' else
     begin
      sm:=(m.Item[0] as Match).SubMatches as SubMatches;
      if sm.Count=0 then Result:='' else Result:=VarToStr(sm.Item[0]);
     end;
  end;

var
  d:TDateTime;
  i,j,k,totalcount:integer;
  loadlast,postlast,postavg,margin:double;
  loadext,dofeed,newfeed,doreq,xres,notmod:boolean;
  rw,rt,s,sql1,sql2,p1,p2:WideString;
  rf:TFileStream;
  qr1:TQueryResult;
  feedresult0,feedlastmod,feedlastmod0:string;

  procedure ParseExternalHeader;
  var
    i,j:integer;
    rh:TStringList;
  begin
    i:=1;
    while (i+4<Length(rw)) and not(
      (rw[i]=#13) and (rw[i+1]=#10) and
      (rw[i+2]=#13) and (rw[i+3]=#10)) do inc(i);

    rt:='';//default;
    feedlastmod:='';//default
    rh:=TStringList.Create;
    try
      rh.Text:=Copy(rw,1,i);
      if rh.Count<>0 then
       begin
        if Copy(rh[0],1,12)='HTTP/1.1 304' then notmod:=true else
        if Copy(rh[0],1,12)<>'HTTP/1.1 200' then
          feedresult:='['+rh[0]+']';
        for j:=1 to rh.Count-1 do
         begin
          p1:=rh[j];
          if Copy(p1,1,14)='Content-Type: ' then
            rt:=Copy(p1,15,Length(p1)-14)
          else
          if Copy(p1,1,15)='Last-Modified: ' then
            feedlastmod:=Copy(p1,16,Length(p1)-15);
         end;
       end;
    finally
      rh.Free;
    end;

    inc(i,4);
    rw:=Copy(rw,i,Length(rw)-i+1);
  end;

begin
  qr0:=TQueryResult.Create(dbA,'select *'
     +' ,(select count(*) from "Subscription" S where S.feed_id=F.id) as scount'
     +' from "Feed" F where F.id=$1',[feedid]);
  try
    if qr0.EOF then raise Exception.Create('No feed found for this id.');
    feedurl:=qr0.GetStr('url');
    feedurlskip:=qr0.GetStr('urlskip');
    feedload:=UtcNow;
    feedname:=qr0.GetStr('name');
    feedregime:=qr0.GetInt('regime');
    feedlastmod:=qr0.GetStr('lastmod');
    feedresult:='';
    newfeed:=qr0.IsNull('itemcount');
    totalcount:=qr0.GetInt('totalcount');
    feedurl0:=feedurl;
    feedname0:=feedname;
    feedlastmod0:=feedlastmod;
    feedresult0:=qr0.GetStr('result');
    c1:=qr0.GetInt('itemcount');
    c2:=qr0.GetInt('loadcount');
    notmod:=false;//default

    //Out0(IntToStr(feedid)+':'+feedurl);
    s:=feedurl;
    i:=1;
    //ship https?://
    while (i<=Length(s)) and (s[i]<>'/') do inc(i);
    inc(i);
    if (i<=Length(s)) and (s[i]='/') then inc(i);
    if Copy(s,i,4)='www.' then inc(i,4);
    j:=i;
    while (j<=Length(s)) and (s[j]<>'/') do inc(j);
    inc(j);
    while (j<=Length(s)) and (s[j]<>'/') and (s[j]<>'?') do inc(j);
    Out0('#'+IntToStr(feedid)+' '+Copy(s,i,j-i));

    //flags
    feedgroupid:=qr0.GetInt('group_id');
    //i:=qr0.GetInt('flags');
    //feedglobal:=(i and 1)<>0;
    //TODO: more?

    if (feedresult0<>'') and (feedresult0[1]='[') then feedresult0:='';


    sl.Add('<tr>');
    sl.Add('<th>'+IntToStr(feedid)+'</th>');
    sl.Add('<td class="n" title="'+FormatDateTime('yyyy-mm-dd hh:nn:ss',feedload)+'">');
    if feedgroupid<>0 then
      sl.Add('<div class="flag" style="background-color:red;">'+IntToStr(feedgroupid)+'</div>&nbsp;');
    sl.Add('<a href="'+HTMLEncode(feedurl)+'" title="'+HTMLEncode(feedname)+'">'+HTMLEncode(feedname)+'</a></td>');
    sl.Add('<td>'+FormatDateTime('yyyy-mm-dd hh:nn',qrDate(qr0,'created'))+'</td>');
    sl.Add('<td style="text-align:right;">'+VarToStr(qr0['scount'])+'</td>');

    if qr0.IsNull('loadlast') then loadlast:=0.0 else loadlast:=qr0['loadlast'];

  finally
    qr0.Free;
  end;

  //check feed timing and regime
  qr1:=TQueryResult.Create(dbA,
    'select id from "Post" where feed_id=$1 order by 1 desc limit 1 offset 200',[feedid]);
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
  qr1:=TQueryResult.Create(dbA,(//UTF8Encode(
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
  ,[feedid,double(oldPostDate)]);
  try
    if qr1.EOF then
     begin
      postlast:=0.0;
      postavg:=0.0;
     end
    else
     begin
      if not qr1.IsNull('postlast') then postlast:=qr1['postlast'] else postlast:=0.0;
      if not qr1.IsNull('postmedian') then postavg:=qr1['postmedian'] else
        if not qr1.IsNull('postavg') then postavg:=qr1['postavg'] else
          postavg:=0.0;
     end;
  finally
    qr1.Free;
  end;

  margin:=(RunContinuous+5)/1440.0;
  if postlast=0.0 then
   begin
    sl.Add('<td class="empty" title="'+HTMLEncode(feedlastmod0)+'">&nbsp;</td>');
    if loadlast=0.0 then
      d:=feedload-margin
    else
      d:=loadlast+feedregime;
   end
  else
   begin
    sl.Add('<td title="'+HTMLEncode(feedlastmod0)+'">'+FormatDateTime('yyyy-mm-dd hh:nn',postlast)+'</td>');
    d:=postlast+postavg-margin;
    if (loadlast<>0.0) and (d<loadlast) then
      d:=loadlast+feedregime-margin;
   end;
  dofeed:=(d<feedload) or FeedAll;

  //Instagram gone bad, long timeout
  if (Copy(feedurl,1,26)='https://www.instagram.com/') and (InstagramBadTC<>0) then
    if (cardinal(GetTickCount-InstagramBadTC)<InstagramBadTimeoutMS) then
     begin
      dofeed:=false;
      feedresult0:='Instagram ?';
     end
    else
     begin
      InstagramBadTC:=0;
      InstagramSuccess:=0;
     end;

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
  if loadlast=0.0 then
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

  if dofeed then
   begin
    c1:=0;
    c2:=0;
    loadext:=FileExists('feeds\'+Format('%.4d',[feedid])+'.txt');
    try

      //new feed? youtube channel?
      if (feedresult0='') and (Copy(feedurl,1,Length(YoutubePrefix1))=YoutubePrefix1) then
        feedurl:=YoutubePrefix2+
          Copy(feedurl,Length(YoutubePrefix1)+1,Length(feedurl)-Length(YoutubePrefix1));

      if InstagramLoadExternal and (Copy(feedurl,1,26)='https://www.instagram.com/') then
       begin

        //Instagram small timeout: keep number of requests below 200 per hour
        if cardinal(GetTickCount-InstagramTC)<InstagramNext then
         begin
          Write('(t'+IntToStr(cardinal(InstagramNext-(GetTickCount-InstagramTC)) div 1000)+'")');
          while cardinal(GetTickCount-InstagramTC)<InstagramNext do
           begin
            //TODO: allow user interrupt?
            Sleep(100);
           end;
         end;

        //refresh proxies list
        {
        if proxiesLoaded<Now-0.5 then
         begin
          proxiesTC:=GetTickCount;
          proxiesIndex:=0;
          proxiesLoaded:=Now;
          r:=CoServerXMLHTTP60.Create;
          r.open('GET','https://www.proxy-list.download/api/v1/get?type=http',false,EmptyParam,EmptyParam);
          r.send(EmptyParam);
          if r.status=200 then proxies.Text:=r.responseText else proxies.Clear;
         end;
        }

        if (feedurl<>'') and (feedurl[Length(feedurl)]<>'/') then feedurl:=feedurl+'/';

        rw:=LoadExternal(feedurl+'channel/?__a=1','xmls\'+Format('%.4d',[feedid])+'.json',feedlastmod,
          'application/json',true);

        ParseExternalHeader;
       end
      else

      if loadext then
       begin
        rw:=LoadExternal(feedurl,'xmls\'+Format('%.4d',[feedid])+'.xml',feedlastmod,
          'application/rss+xml, application/atom+xml, application/xml, text/xml',false);

        ParseExternalHeader;

        if rt='' then //auto-detect?
         begin
          i:=1;
          while (i<=Length(rw)) and (rw[i]<=' ') do inc(i);
          if (rw<>'') and ((rw[i]='{') or (rw[i]='[')) then
            rt:='application/json'
          else
            rt:='text/html';//enables search for <link>s below
         end;

       end
      else
       begin
        rc:=0;
        doreq:=true;
        while doreq do
         begin
          doreq:=false;
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
            //Instagram small timeout: keep number of requests below 200 per hour
            if cardinal(GetTickCount-InstagramTC)<InstagramNext then
             begin
              Write('(t'+IntToStr(cardinal(InstagramNext-(GetTickCount-InstagramTC)) div 1000)+'")');
              while cardinal(GetTickCount-InstagramTC)<InstagramNext do
               begin
                //TODO: allow user interrupt?
                Sleep(100);
               end;
             end;

            r.open('GET',feedurl+'?__a=1',false,EmptyParam,EmptyParam);
            r.setRequestHeader('Accept','application/json');

            InstagramTC:=GetTickCount;
            InstagramNext:=InstagramTimeoutMS+Random(InstagramTimeoutRandomPaddingMS);
           end
          else
           begin
            r.open('GET',feedurl,false,EmptyParam,EmptyParam);
            if Pos('sparql',feedurl)<>0 then
              r.setRequestHeader('Accept','application/sparql-results+xml, application/xml, text/xml')
            else
              r.setRequestHeader('Accept','application/rss+xml, application/atom+xml, application/xml, application/json, text/xml');
           end;
          r.setRequestHeader('Cache-Control','no-cache, no-store, max-age=0');
          if Pos('tumblr.com',feedurl)<>0 then
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
            r.setRequestHeader('User-Agent','FeedEater/1.0');
          if Copy(feedurl,1,30)='https://www.washingtonpost.com' then
            r.setRequestHeader('Cookie','wp_gdpr=1|1');
          //TODO: ...'/wp/v2/posts' param 'after' last load time?
          if (feedlastmod<>'') and not(FeedAll) then
            r.setRequestHeader('If-Modified-Since',feedlastmod);
          r.send(EmptyParam);
          if (r.status=301) or (r.status=302) or (r.status=308) then //moved permanently
           begin
            feedurl:=r.getResponseHeader('Location');
            doreq:=true;
            inc(rc);
            if rc=8 then
              raise Exception.Create('max redirects exceeded');
           end;
         end;
        if r.status=200 then
         begin

          Write(':');
          rw:=r.responseText;
          //rh:=r.getAllResponseHeaders;
          rt:=r.getResponseHeader('Content-Type');
          feedlastmod:=r.getResponseHeader('Last-Modified');
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

            {
            rf:=TFileStream.Create('xmls\'+Format('%.4d',[feedid])+'.log',fmCreate);
            try
              i:=$FEFF;
              rf.Write(i,2);
              rf.Write(rh[1],Length(rh)*2);
            finally
              rf.Free;
            end;
            }

           end;

         end
        else
        if r.status=304 then
          notmod:=true
        else
          feedresult:='[HTTP:'+IntToStr(r.status)+']'+r.statusText;
       end;
    except
      on e:Exception do
       begin
        feedresult:='['+e.ClassName+']'+e.Message;
        if not(loadext) and (e is EOleException)
          and ((e.Message='A security error occurred')
          or (e.Message='A connection with the server could not be established'))
          then //TODO: e.ErrorCode=?
         begin
          rf:=TFileStream.Create('feeds\'+Format('%.4d',[feedid])+'.txt',fmCreate);
          try
            //
          finally
            rf.Free;
          end;
         end;

       end;
    end;

    if notmod then
     begin
      feedresult:=feedresult0+' [HTTP 403]';
      if not loadext then Writeln(' HTTP 304');
     end
    else
     begin

      if feedresult='' then
        try
          feedtagprefix:='';
          VarClear(feedtags);

          //sanitize content type
          if rt<>'' then
           begin
            i:=1;
            while (i<=Length(rt)) and (rt[i]<>';') do inc(i);
            while (i>0) and (rt[i]<=' ') do dec(i);
            if (i<=Length(rt)) then SetLength(rt,i-1);
           end;

          //sanitize unicode
          for i:=1 to Length(rw) do
            case word(rw[i]) of
              0..8,11,12,14..31:rw[i]:=#9;
              9,10,13:;//leave as-is
              else ;//leave as-is
            end;

          //TODO: "Feed".flags?
          if FileExists('feeds\'+Format('%.4d',[feedid])+'ws.txt') then
           begin
            i:=1;
            while (i<=Length(rw)) and (word(rw[i])<=32) do inc(i);
            if i<>1 then rw:=Copy(rw,i,Length(rw)-i+1);
           end;

          if Copy(feedurl,1,26)='https://www.instagram.com/' then
           begin
            InstagramTC:=GetTickCount;
            InstagramNext:=InstagramTimeoutMS+Random(InstagramTimeoutRandomPaddingMS);
            jnodes:=JSONDocArray;
            jdoc:=JSON(['user{'
              ,'edge_felix_video_timeline{','edges',jnodes,'}'
              ,'edge_owner_to_timeline_media{','edges',jnodes,'}'
              ,'edge_saved_media{','edges',jnodes,'}'
              ,'edge_media_collections{','edges',jnodes,'}'
              ]);

            {
            i:=1;
            while (i<Length(rw)-8) and (Copy(rw,i,11)<>'"graphql":{') do
              inc(i);
            inc(i,10);
            try
              jdoc.Parse(Copy(rw,i,Length(rw)-i+1));
            except
              on EJSONDecodeException do
                ;//ignore "data past end"
            end;
            }

            if rt='application/json' then
             begin

              jdoc1:=JSON(['graphql',jdoc]);
              try
                jdoc1.Parse(rw);
              except
                on EJSONDecodeException do
                  ;//ignore "data past end"
              end;

              if SaveData then
               begin
                rf:=TFileStream.Create('xmls\'+Format('%.4d',[feedid])+'.json',fmCreate);
                try
                  i:=$FEFF;
                  rf.Write(i,2);
                  //rf.Write(rw[i],(Length(rw)-i+1)*2);
                  rw:=jdoc.AsString;
                  rf.Write(rw[1],Length(rw)*2);
                finally
                  rf.Free;
                end;
               end;

              jd1:=JSON(jdoc['user']);
              if jd1<>nil then
                feedname:='Instagram: '+VarToStr(jd1['full_name'])+' (@'+VarToStr(jd1['username'])+')';

              jcaption:=JSONDocArray;
              jthumbs:=JSONDocArray;
              jn1:=JSON(['edge_media_to_caption{','edges',jcaption,'}','thumbnail_resources',jthumbs]);
              jn0:=JSON(['node',jn1]);
              jc1:=JSON();
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

                if CheckNewItem then
                 begin
                  content:=HTMLEncode(content);
                  //if jn1['is_video']=true then content:=#$25B6+content;
                  if jn1['is_video']=true then title:=#$25B6+title;

                  if jthumbs.Count=0 then s:='' else
                    s:=VarToStr(JSON(jthumbs.GetJSON(jthumbs.Count-1))['src']);
                  if s='' then s:=VarToStr(jn1['thumbnail_src']);
                  if s='' then s:=VarToStr(jn1['display_url']);

                  if s<>'' then
                   begin
                    r:=CoServerXMLHTTP60.Create;
                    r.open('GET',s,false,EmptyParam,EmptyParam);
                    r.send(EmptyParam);
                    //if r.status<>200 then raise?
                    content:=
                      '<a href="'+HTMLEncode(itemurl)+'"><img src="data:image/jpeg;base64,'+
                        UTF8ToWideString(Base64EncodeStream_JPEG(IUnknown(r.responseStream) as IStream))+
                        '" border="0" /></a><br />'#13#10+
                      content;

                    r:=nil;
                   end;

                  jd1:=JSON(jn1['location']);
                  if jd1<>nil then
                    content:='<i>'+HTMLEncode(jd1['name'])+'</i><br />'#13#10+content;

                  //TODO: likes, views, owner?

                  RegisterItem;
                 end;

               end;
             end;

            if (c1=0) and (c2=0) then//if rt<>'application/json'?
             begin
              proxiesTC:=GetTickCount;
              inc(proxiesIndex);
              if proxiesIndex>=proxies.Count then
                InstagramBadTC:=GetTickCount
              else
                InstagramTC:=GetTickCount-InstagramTimeoutMS-InstagramTimeoutRandomPaddingMS;
              feedlastmod:='';
              feedresult:=Format('Instagram ? (s:%d, p:%d/%d)',
                [InstagramSuccess,proxiesIndex+1,proxies.Count]);
             end
            else
             begin
              inc(InstagramSuccess);
              feedresult:=Format('Instagram %d/%d',[c2,c1]);
             end;

           end
          else
          if (rt='application/json') and (Copy(StripWhiteSpace(Copy(rw,1,20)),1,8)='{"rss":{') then
           begin
            jnodes:=JSONDocArray;
            jc1:=JSON(['item',jnodes]);
            jc0:=JSON(['channel',jc1]);
            jdoc:=JSON(['rss',jc0]);
            jdoc.Parse(rw);
            //jc0['version']='2.0'?
            feedname:=VarToStr(jc1['title']);
            //jc1['link']
            jn0:=JSON;
            for i:=0 to jnodes.Count-1 do
             begin
              jnodes.LoadItem(i,jn0);
              itemid:=VarToStr(jn0['guid']);
              itemurl:=VarToStr(jn0['link']);
              title:=VarToStr(jn0['title']);
              try
                pubDate:=ConvDate2(VarToStr(jn0['pubDate']));
              except
                pubDate:=UtcNow;
              end;
              //TODO xmlns...=http://purl.org/rss/1.0/modules/content/ "...:encoded"?
              if not VarIsNull(jn0['content']) then
                content:=VarToStr(jn0['content'])
              else
              if not VarIsNull(jn0['description']) then
                content:=VarToStr(jn0['description'])
              else
                content:='';
              if CheckNewItem then RegisterItem;
             end;
            feedresult:=Format('RSS-in-JSON %d/%d',[c2,c1]);

           end
          else
          if (rt='application/json') and (Pos('/wp/v2/',feedurl)<>0)
            and (Copy(rw,1,1)='[') then //and ((Copy(rw,1,7)='[{"id":') or (rw='[]')) then
           begin

            //TODO: if rw='[]' and '/wp/v2/posts' switch to '/wp/v2/articles'? episodes? media?

            hasReplaces:=FileExists('feeds\'+Format('%.4d',[feedid])+'r.json');

            jnodes:=JSONDocArray;
            jdoc:=JSON(['items',jnodes]);
            jdoc.Parse('{"items":'+rw+'}');
            jn0:=JSON;
            for i:=0 to jnodes.Count-1 do
             begin
              jnodes.LoadItem(i,jn0);
              itemid:=VarToStr(jn0['id']);//'slug'?
              if itemid='' then itemid:=VarToStr(JSON(jn0['guid'])['rendered']);
              itemurl:=VarToStr(jn0['link']);
              title:=VarToStr(JSON(jn0['title'])['rendered']);
              try
                v:=jn0['date_gmt'];
                if VarIsNull(v) then v:=jn0['date'];//modified(_gmt)?
                pubDate:=ConvDate1(VarToStr(v));
              except
                pubDate:=UtcNow;
              end;
              if CheckNewItem then
               begin
                //'excerpt'?
                content:=VarToStr(JSON(jn0['content'])['rendered']);

                if rhImgData=nil then
                 begin
                  rhImgData:=CoRegExp.Create;
                  rhImgData.Pattern:='<img(\s+?)data-(srcset="[^"]*?"\s+?)data-(src="[^"]+?")';
                  //TODO: negative lookaround: no src/srcset=""
                  rhImgData.Global:=true;
                 end;
                content:=rhImgData.Replace(content,'<img$1$2$3');

                if hasReplaces then
                  PerformReplaces(feedid,content);

                RegisterItem;
               end;
             end;
            feedresult:=Format('WPv2 %d/%d',[c2,c1]);
           end
          else
          if (rt='application/json') then
           begin
            jnodes:=JSONDocArray;
            jdoc:=JSON(['items',jnodes]);
            jdoc.Parse(rw);
            //if jdoc['version']='https://jsonfeed.org/version/1' then
            feedname:=VarToStr(jdoc['title']);
            if feedname='News' then feedname:=VarToStr(jdoc['description']);//NPR?
            if Length(feedname)>200 then feedname:=Copy(feedname,1,197)+'...';
            //jdoc['home_page_url']?
            //jdoc['feed_url']?
            jn0:=JSON;
            for i:=0 to jnodes.Count-1 do
             begin
              jnodes.LoadItem(i,jn0);
              jn1:=JSON(jn0['contents']);
              itemid:=VarToStr(jn0['id']);
              itemurl:=VarToStr(jn0['url']);
              title:=VarToStr(jn0['title']);
              try
                pubDate:=ConvDate1(VarToStr(jn0['date_published']));
              except
                pubDate:=UtcNow;
              end;
              //TODO: if summary<>content?
              {
              if not(VarIsNull(jn0['summary'])) then
               begin
                s:=VarToStr(jn0['summary']);
                if (s<>'') and (s<>title) then
                 begin
                  if Length(s)>200 then s:=Copy(s,1,197)+'...';
                  title:=title+' '#$2014' '+s;
                 end;
               end;
              }
              if VarIsNull(jn0['content_html']) then
                content:=HTMLEncode(VarToStr(jn0['content_text']))
              else
                content:=VarToStr(jn0['content_html']);
              if CheckNewItem then RegisterItem;
             end;
            feedresult:=Format('JSONfeed %d/%d',[c2,c1]);
           end
          else
          if ((feedresult0='') or (Copy(feedresult0,1,8)='Titanium'))
            and FindPrefixAndCrop(rw,'window\[''titanium-state''\] = ') then
           begin
            jnodes:=JSONDocArray;
            jdoc:=JSON(['hub',JSON(['data',JSON([
              FindMatch(rw,'"data":{"([^"]*?)":{"[^"]+?":\['),
              JSON(['cards',jnodes])])])]);
            try
              jdoc.Parse(rw);
            except
              on EJSONDecodeException do
                ;//ignore "data past end"
            end;
            //feedname:=VarToStr(jdoc[????]);
            jcaption:=JSONDocArray;
            jthumbs:=JSONDocArray;
            jn0:=JSON(['contents',jcaption,'feeds',jthumbs]);
            jn1:=JSON(['media',jthumbs]);
            jd1:=JSON;
            p1:='';
            p2:='';
            for i:=0 to jnodes.Count-1 do
             begin
              jnodes.LoadItem(i,jn0);

              //coalesce contents under feed onto contents
              for j:=0 to jThumbs.Count-1 do
                jcaption.AddJSON(jthumbs.GetJSON(j));

              for j:=0 to jcaption.Count-1 do
               begin
                jcaption.LoadItem(j,jn1);

                itemid:=VarToStr(jn1['id']);
                itemurl:=VarToStr(jn1['localLinkUrl']);
                try
                  if VarIsNull(jn1['published']) then
                    pubDate:=ConvDate1(VarToStr(jn1['updated']))
                  else
                    pubDate:=ConvDate1(VarToStr(jn1['published']));
                except
                  pubDate:=UtcNow;
                end;
                title:=VarToStr(jn1['headline']);

                //TODO: media, mediumIds (leadPhotoId?

                content:=VarToStr(jn1['storyHTML']);
                if content='' then
                 begin
                  content:=HTMLEncode(VarToStr(jn1['firstWords']));
                  if content<>'' then
                    content:=content+'<span style="color:silver;">...</span>';
                 end;

                //jn1['media']
                if jthumbs.Count=0 then
                 begin
                  v:=jn1['mediumIds'];
                  if (p1<>'') and VarIsArray(v) and (VarArrayLowBound(v,1)<=VarArrayHighBound(v,1)) then
                   begin
                    if Copy(content,1,3)='<p>' then h1:=#13#10 else h1:='<br />'#13#10;
                    content:='<img class="postthumb" src="'+p1+
                      VarToStr(v[VarArrayLowBound(v,1)])+
                      p2+'" />'+h1+content;
                   end;

                 end
                else
                 begin
                  jthumbs.LoadItem(0,jd1);
                  if content='' then content:=VarToStr(jd1['caption']);
                  if Copy(content,1,3)='<p>' then h1:=#13#10 else h1:='<br />'#13#10;
                  content:='<img class="postthumb" src="'+
                    VarToStr(jd1['gcsBaseUrl'])+
                    VarToStr(VarArrLast(jd1['imageRenderedSizes']))+
                    VarToStr(jd1['imageFileExtension'])+
                    '" />'+h1+content;
                  if p1='' then //see 'mediumIDs' above
                   begin
                    p1:=VarToStr(jd1['gcsBaseUrl']);
                    k:=Length(p1)-1;
                    while (k<>0) and (p1[k]<>'/') do dec(k);
                    SetLength(p1,k);
                    p2:='/'+//?
                      VarToStr(VarArrLast(jd1['imageRenderedSizes']))+
                      VarToStr(jd1['imageFileExtension']);
                   end;

                 end;

                if not((itemurl='') and (content='')) and CheckNewItem then
                 begin
                  feedtagprefix:='tag';
                  feedtags:=jn1['tagIds'];
                  RegisterItem;
                 end;
               end;
             end;
            feedresult:=Format('Titanium %d/%d',[c2,c1]);
           end
          else
          if ((feedresult0='') or (Copy(feedresult0,1,6)='Fusion'))
            and FindPrefixAndCrop(rw,'Fusion.globalContent=') then
           begin
            jnodes:=JSONDocArray;
            jd1:=JSON;
            jdoc:=JSON(['result',JSON(['articles',jnodes,'section',jd1])]);
            try
              jdoc.Parse(rw);
            except
              on EJSONDecodeException do
                ;//ignore "data past end"
            end;
            feedname:=jd1['title'];
            jn0:=JSON;
            p1:='';
            p2:='';
            for i:=0 to jnodes.Count-1 do
             begin
              jnodes.LoadItem(i,jn0);

              itemid:=jn0['id'];
              itemurl:=jn0['canonical_url'];
              try
                pubDate:=ConvDate1(VarToStr(jn0['display_time']));//published_time?
              except
                pubDate:=UtcNow;
              end;
              title:=jn0['title'];
              v:=jn0['subtitle'];
              if not(VarIsNull(v)) then title:=title+' '#$2014' '+v;
              content:=HTMLEncode(jn0['description']);

              if CheckNewItem then
               begin
                jn1:=JSON(jn0['thumbnail']);
                if jn1<>nil then
                  content:='<img class="postthumb" src="'+HTMLEncode(jn1['url'])+
                    '" alt="'+HTMLEncode(VarToStr(jn1['caption']))+
                    '" /><br />'#13#10+content;
                RegisterItem;
               end;
             end;
            feedresult:=Format('Fusion %d/%d',[c2,c1]);
           end
          else
          if ((feedresult0='') or (Copy(feedresult0,1,8)='NextData'))
            and FindPrefixAndCrop(rw,'<script id="__NEXT_DATA__" type="application/json">') then
           begin
            jd1:=JSON;
            jdoc:=JSON(['props',JSON(['pageProps',JSON(['contentState',jd1])])]);
            try
              jdoc.Parse(rw);
            except
              on EJSONDecodeException do
                ;//ignore "data past end"
            end;
            //feedname?
            je:=JSONEnum(jd1);
            while je.Next do
             begin
              jn0:=JSON(je.Value);
              if jn0<>nil then
               begin
                itemid:=VarToStr(jn0['_id']);
                itemurl:=VarToStr(jn0['canonical_url']);
               end;
              if (jn0<>nil) and (itemid<>'') and (itemurl<>'') then
               begin
                try
                  pubDate:=ConvDate1(VarToStr(jn0['display_date']));//publish_date?
                except
                  pubDate:=UtcNow;
                end;
                if CheckNewItem then
                 begin
                  title:=JSON(jn0['headlines'])['basic'];

                  jn1:=JSON(jn0['description']);
                  if jn1=nil then content:='' else content:=HTMLEncode(jn1['basic']);

                  p1:='';//default;
                  jn1:=JSON(jn0['promo_items']);
                  if jn1<>nil then
                    begin
                     jn1:=JSON(jn1['basic']);
                     if jn1<>nil then p1:=VarToStr(jn1['url']);
                    end;
                  if p1<>'' then
                    content:=
                      '<img class="postthumb" src="'+
                      HTMLEncode(JSON(JSON(jn0['promo_items'])['basic'])['url'])+
                      '" /><br />'#13#10+content;

                  RegisterItem;
                 end;
               end;
             end;
            feedresult:=Format('NextData %d/%d',[c2,c1]);
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
              xres:=doc.load('xmls\'+Format('%.4d',[feedid])+'.xml')
            else
            }
              xres:=doc.loadXML(rw);

            //fix Mashable (grr!)
            if not(xres) then
             begin
              re:=CoRegExp.Create;
              re.Pattern:='Reference to undeclared namespace prefix: ''([^'']+?)''.\r\n';
              if re.Test(doc.parseError.reason) then
               begin
                s:=(((re.Execute(doc.parseError.reason)
                  as MatchCollection).Item[0]
                    as Match).SubMatches
                      as SubMatches).Item[0];
                re.Pattern:='<('+s+':\S+?)[^>]*?[\u0000-\uFFFF]*?</\1>';
                re.Global:=true;
                rw:=re.Replace(rw,'');
                xres:=doc.loadXML(rw);
               end;
              re:=nil;
             end;

            //fix floating nbsp's
            if not(xres) and (Pos('''nbsp''',string(doc.parseError.reason))<>0) then
             begin
              re:=CoRegExp.Create;
              re.Pattern:='&nbsp;';
              re.Global:=true;
              //rw:=re.Replace(rw,'&amp;nbsp;');
              rw:=re.Replace(rw,#$00A0);
              xres:=doc.loadXML(rw);
              re:=nil;
             end;

            if xres then
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
                  y:=x.selectSingleNode('atom:id') as IXMLDOMElement;
                  if y=nil then itemid:='' else itemid:=y.text;
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
                    xl1:=nil;
                    if itemid='' then itemid:=itemurl;
                   end;
                  try
                    y:=x.selectSingleNode('atom:published') as IXMLDOMElement;
                    if y=nil then y:=x.selectSingleNode('atom:issued') as IXMLDOMElement;
                    if y=nil then y:=x.selectSingleNode('atom:modified') as IXMLDOMElement;
                    if y=nil then y:=x.selectSingleNode('atom:updated') as IXMLDOMElement;
                    if y=nil then pubDate:=UtcNow else pubDate:=ConvDate1(y.text);
                  except
                    pubDate:=UtcNow;
                  end;

                  if CheckNewItem then
                   begin

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

                    xl1:=x.selectNodes('atom:category');
                    if xl1.length<>0 then
                     begin
                      feedtagprefix:='category';
                      feedtags:=VarArrayCreate([0,xl1.length-1],varOleStr);
                      i:=0;
                      y:=xl1.nextNode as IXMLDOMElement;
                      while y<>nil do
                       begin
                        feedtags[i]:=y.getAttribute('term');
                        inc(i);
                        y:=xl1.nextNode as IXMLDOMElement;
                       end;
                     end;
                    xl1:=nil;

                    if not IsProbablyHTML(content) then
                     begin
                      x1:=x.selectSingleNode('atom:link[@rel="enclosure" and @type="image/jpeg"]/@href');
                      if x1<>nil then
                       begin
                        if Copy(content,1,3)='<p>' then h1:=#13#10 else h1:='<br />'#13#10;
                        content:='<img class="postthumb" src="'+//<a href="?
                          HTMLEncode(x1.text)+'" />'+h1+content;
                       end;
                      x1:=nil;
                     end;

                    RegisterItem;
                   end;

                  x:=xl.nextNode as IXMLDOMElement;
                 end;
                xl:=nil;
                feedresult:=Format('Atom %d/%d',[c2,c1]);
               end
              else

              //RSS
              if doc.documentElement.nodeName='rss' then
               begin
                doc.setProperty('SelectionNamespaces',
                  'xmlns:content="http://purl.org/rss/1.0/modules/content/" '+
                  'xmlns:media="http://search.yahoo.com/mrss/"');

                hasFoaf:=false;
                i:=0;
                while not(hasFoaf) and (i<doc.namespaces.length) do
                 begin
                  s:=doc.namespaces[i];
                  if Copy(s,1,22)='http://xmlns.com/foaf/' then hasFoaf:=true;
                  inc(i);
                 end;

                hasReplaces:=FileExists('feeds\'+Format('%.4d',[feedid])+'r.json');

                x:=doc.documentElement.selectSingleNode('channel/title') as IXMLDOMElement;
                if x<>nil then feedname:=x.text;

                xl:=doc.documentElement.selectNodes('channel/item');
                x:=xl.nextNode as IXMLDOMElement;
                while x<>nil do
                 begin
                  y:=x.selectSingleNode('guid') as IXMLDOMElement;
                  if y=nil then y:=x.selectSingleNode('link') as IXMLDOMElement;
                  if y=nil then itemid:='' else itemid:=y.text;
                  y:=x.selectSingleNode('link') as IXMLDOMElement;
                  if y=nil then itemurl:='' else itemurl:=y.text;
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
                  if CheckNewItem then
                   begin
                    xl1:=x.selectNodes('category');
                    if xl1.length<>0 then
                     begin
                      feedtagprefix:='category';
                      feedtags:=VarArrayCreate([0,xl1.length-1],varOleStr);
                      i:=0;
                      y:=xl1.nextNode as IXMLDOMElement;
                      while y<>nil do
                       begin
                        feedtags[i]:=y.text;
                        inc(i);
                        y:=xl1.nextNode as IXMLDOMElement;
                       end;
                     end;
                    xl1:=nil;

                    if hasFoaf and rhImgFoaf.Test(content) then
                      content:=rhImgFoaf.Replace(content,'$1');

                    if Copy(content,1,5)<>'<img ' then //not already starts with image
                     begin
                      if IsProbablyHTML(content) then
                        x1:=nil //see below
                      else
                       begin
                        //x1:=x.selectSingleNode('media:content/@url');
                        //if x1=nil then
                        x1:=x.selectSingleNode('media:thumbnail/@url');
                        if x1=nil then
                        x1:=x.selectSingleNode('media:content[@medium="image"]/media:thumbnail/@url');
                       end;
                      if x1=nil then
                        x1:=x.selectSingleNode('enclosure[@type="image/jpeg"]/@url');
                      if x1=nil then
                        x1:=x.selectSingleNode('enclosure[@type="image/png"]/@url');
                      if x1<>nil then //<a href="?
                       begin
                        if Copy(content,1,3)='<p>' then h1:=#13#10 else h1:='<br />'#13#10;
                        content:='<img class="postthumb" src="'+
                          HTMLEncode(x1.text)+'" />'+h1+content;
                        x1:=nil;
                       end;
                     end;

                    if hasReplaces then
                      PerformReplaces(feedid,content);

                    RegisterItem;
                   end;

                  x:=xl.nextNode as IXMLDOMElement;
                 end;
                xl:=nil;
                feedresult:=Format('RSS %d/%d',[c2,c1]);
               end
              else

              //RDF
              if doc.documentElement.nodeName='rdf:RDF' then
               begin
                doc.setProperty('SelectionNamespaces',
                 'xmlns:rss="http://purl.org/rss/1.0/"'+
                 ' xmlns:dc="http://purl.org/dc/elements/1.1/"');
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
                  if CheckNewItem then RegisterItem;
                  x:=xl.nextNode as IXMLDOMElement;
                 end;
                xl:=nil;

                if c2=0 then
                 begin
                  doc.setProperty('SelectionNamespaces',
                   'xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"'+
                   ' xmlns:schema="http://schema.org/"');
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
                    if CheckNewItem then RegisterItem;
                    x:=xl.nextNode as IXMLDOMElement;
                   end;
                  xl:=nil;
                 end;


                feedresult:=Format('RDF %d/%d',[c2,c1]);
               end
              else

              //SPARQL
              if doc.documentElement.nodeName='sparql' then
               begin
                doc.setProperty('SelectionNamespaces',
                 'xmlns:s="http://www.w3.org/2005/sparql-results#"');

                //feedname:=??
                xl:=doc.documentElement.selectNodes('s:results/s:result');
                x:=xl.nextNode as IXMLDOMElement;
                while x<>nil do
                 begin
                  itemid:=x.selectSingleNode('s:binding[@name="news"]/s:uri').text;
                  itemurl:=x.selectSingleNode('s:binding[@name="url"]/s:uri').text;
                  title:=x.selectSingleNode('s:binding[@name="headline"]/s:literal').text;

                  y:=x.selectSingleNode('s:binding[@name="description"]/s:literal') as IXMLDOMElement;
                  if (y<>nil) and (y.text<>title) then
                    title:=title+' '#$2014' '+y.text;

                  y:=x.selectSingleNode('s:binding[@name="body"]/s:literal') as IXMLDOMElement;
                  if y=nil then content:='' else content:=y.text;
                  try
                    y:=x.selectSingleNode('s:binding[@name="pubDate"]/s:literal') as IXMLDOMElement;
                    pubDate:=ConvDate1(y.text);
                  except
                    pubDate:=UtcNow;
                  end;
                  if CheckNewItem then RegisterItem;
                  x:=xl.nextNode as IXMLDOMElement;
                 end;
                xl:=nil;

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

          inc(LastFeedCount);

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

        if feedname='' then
         begin
          i:=5;
          while (i<=Length(feedurl)) and (feedurl[i]<>':') do inc(i);
          inc(i);
          if (i<=Length(feedurl)) and (feedurl[i]='/') then inc(i);
          if (i<=Length(feedurl)) and (feedurl[i]='/') then inc(i);
          feedname:='['+Copy(feedurl,i,Length(feedurl)-i+1);
          i:=2;
          while (i<=Length(feedname)) and (feedname[i]<>'/') do inc(i);
          SetLength(feedname,i);
          feedname[i]:=']';
         end;

        if newfeed or
          (feedurl<>feedurl0) or (feedname<>feedname0) then
         begin
          dbA.Update('Feed',
            ['id',feedid
            ,'name',feedname
            ,'url',feedurl
            ,'loadlast',double(feedload)
            ,'result',feedresult
            ,'loadcount',c2
            ,'itemcount',c1
            ,'totalcount',totalcount+c2
            ,'regime',feedregime
            ]);
          if (NewFeedEvent<>0) and (feedurl<>feedurl0) then
            SetEvent(NewFeedEvent);
         end
        else
          dbA.Update('Feed',
            ['id',feedid
            ,'loadlast',double(feedload)
            ,'result',feedresult
            ,'loadcount',c2
            ,'itemcount',c1
            ,'totalcount',totalcount+c2
            ,'regime',feedregime
            ]);

        if feedlastmod<>feedlastmod0 then
          dbA.Update('Feed',
            ['id',feedid
            ,'lastmod',feedlastmod
            ]);

        dbA.CommitTrans;
      except
        dbA.RollbackTrans;
        raise;
      end;

    end;

   end
  else
   begin
    i:=Round((d-feedload)*1440.0);
    if i<0 then
      s:='('+feedresult0+')'
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
    if feedregime<>0 then s:=s+' Regime:'+IntToStr(feedregime)+'d';
    Writeln(' Skip '+s);
    feedresult:=feedresult0;
    //c1,c2: see above
    feedload:=loadlast;
   end;

  if (feedresult+'-')[1]='[' then
    sl.Add('<td style="color:#CC0000;">'+HTMLEncode(feedresult)+'</td>')
  else
    sl.Add('<td>'+HTMLEncode(feedresult)+'</td>');
  if c2=0 then
    sl.Add('<td class="empty">&nbsp;</td>')
  else
    sl.Add('<td style="text-align:right;">'+IntToStr(c2)+'</td>');
  sl.Add('<td style="text-align:right;" title="'+FormatDateTime('yyyy-mm-dd hh:nn:ss',feedload)
    +#13#10+HTMLEncode(feedlastmod)+'">'+IntToStr(c1)+'</td>');
  sl.Add('<td style="text-align:right;">'+IntToStr(totalcount)+'</td>');
  sl.Add('</tr>');

end;

{
function SelfVersion:string;
const
  dSize=$1000;
var
  d:array[0..dSize-1] of byte;
  verblock:PVSFIXEDFILEINFO;
  verlen:cardinal;
  p:PAnsiChar;
  h1,h2:THandle;
begin
  h1:=FindResource(HInstance,pointer(1),RT_VERSION);
  if h1=0 then SelfVersion:='[no version data]' else
   begin
    h2:=LoadResource(HInstance,h1);
    if h2=0 then SelfVersion:='[verion load failed]' else
     begin
      //odd, a copy is required to avoid access violation in version.dll
      Move(LockResource(h2)^,d[0],SizeofResource(HInstance,h1));
      UnlockResource(h2);
      FreeResource(h2);
      //
      if VerQueryValueA(@d[0],'\',pointer(verblock),verlen) then
        Result:=
          IntToStr(HiWord(verblock.dwFileVersionMS))+'.'+
          IntToStr(LoWord(verblock.dwFileVersionMS))+'.'+
          IntToStr(HiWord(verblock.dwFileVersionLS))+'.'+
          IntToStr(LoWord(verblock.dwFileVersionLS))
      else
        Result:='v???';
      if VerQueryValueA(@d[0],'\StringFileInfo\040904E4\FileDescription',pointer(p),verlen) then
        Result:=string(p)+' '+Result;
     end;
   end;
end;
}



procedure DoProcessParams;
var
  i:integer;
  s:string;
begin
  SaveData:=false;
  RunContinuous:=0;
  FeedID:=0;
  FeedAll:=false;
  FeedNew:=false;
  NewFeedEvent:=0;
  FeedOrderBy:=' order by F.id';
  NextAnalyze:=false;//?

  for i:=1 to ParamCount do
   begin
    s:=ParamStr(i);
    if s='/a' then FeedOrderBy:=' order by X.postavg,X.postlast,F.id'
    else
    if s='/s' then SaveData:=true
    else
    if s='/n' then FeedNew:=true
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

  s:=ExtractFilePath(ParamStr(0))+'blacklist.txt';
  if FileExists(s) then blacklist.LoadFromFile(s);

  SanitizeInit;
end;

function DoCheckRunDone:boolean;
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
                'd'://diagnostics
                 begin
                  Writeln(#13'Diagnostics:  ');
                  Writeln('  Running since '+DateTimeToStr(RunStart));
                  Writeln('  Last load: '+DateTimeToStr(LastLoadStart));
                  i:=Round((LastLoadDone-LastLoadStart)*86400.0);
                  Writeln(Format('  %d posts from %d feeds (%d''%d")',[LastPostCount,LastFeedCount,i div 60,i mod 60]));
                  if InstagramBadTC<>0 then
                   begin
                    Writeln('  Instagram timeout since '+
                      FormatDateTime('hh:nn:ss',Now-cardinal(GetTickCount-InstagramBadTC)/(24*60*60*1000)));
                    Writeln('  Instagram successes before timeout: '+IntToStr(InstagramSuccess));
                   end;
                  Writeln(Format('  Proxy: %d/%d since %s/%s',[proxiesIndex+1,proxies.Count,
                    FormatDateTime('yyyy-mm-dd hh:nn',Now-cardinal(GetTickCount-proxiesTC)/(24*60*60*1000)),
                    FormatDateTime('yyyy-mm-dd hh:nn',proxiesLoaded)]));
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
                'p'://proxies list refresh
                 begin
                  Writeln(#13'Force proxies list refresh   ');
                  proxiesLoaded:=0;
                 end
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

{
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
    sqlite3_close(b);
  end;
end;
}

procedure DoUpdateFeeds;
var
  dbA,dbB:TDataConnection;
  qr:TQueryResult;
  i,j,l:integer;
  ids:array of integer;
  d:TDateTime;
  sl:TStringList;
begin
  try
    LastRun:=UtcNow;
    OutLn('Opening databases...');

    sl:=TStringList.Create;
    try
      sl.LoadFromFile(FeederIniPath);
      dbA:=TDataConnection.Create(sl.Text);
      dbB:=TDataConnection.Create(sl.Text);
    finally
      sl.Free;
    end;

    if PGVersion='' then //?
     begin
      qr:=TQueryResult.Create(dbB,'select version()',[]);
      try
        if qr.Read then PGVersion:=qr.GetStr(0);        
      finally
        qr.Free;
      end;
     end;

    sl:=TStringList.Create;
    try

      sl.Add('<style>');
      sl.Add('P{font-family:"PT Sans",Calibri,sans-serif;font-size:0.7em;}');
      sl.Add('TH{font-family:"PT Sans",Calibri,sans-serif;font-size:0.7em;white-space:nowrap;border:1px solid #333333;}');
      sl.Add('TD{font-family:"PT Sans",Calibri,sans-serif;font-size:0.7em;white-space:nowrap;border:1px solid #CCCCCC;}');
      sl.Add('TD.n{max-width:20em;overflow:hidden;text-overflow:ellipsis;}');
      sl.Add('TD.empty{background-color:#CCCCCC;}');
      sl.Add('DIV.flag{display:inline;padding:2pt;color:#FFCC00;border-radius:4pt;white-space:nowrap;}');
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
      sl.Add('<th>total</th>');
      sl.Add('</tr>');

      i:=Trunc(LastRun*2.0-0.302);//twice a day on some off-hour
      if LastClean<>i then
       begin
        LastClean:=i;

        Out0('Clean-up old...');
        OldPostsCutOff:=UtcNow-OldPostsDays;
        qr:=TQueryResult.Create(dbB,'select id from "Post" where pubdate<$1',[double(OldPostsCutOff)]);
        try

          j:=0;
          while qr.Read do
           begin
            i:=qr.GetInt('id');
            dbA.BeginTrans;
            try
              dbA.Execute('delete from "UserPost" where post_id=$1',[i]);
              dbA.Execute('delete from "Opinion" where post_id=$1',[i]);
              dbA.Execute('delete from "Post" where id=$1',[i]);
              dbA.CommitTrans;
            except
              dbA.RollbackTrans;
              raise;
            end;
            inc(j);
           end;
          Writeln(' '+IntToStr(j)+' posts cleaned      ');

        finally
          qr.Free;
        end;

        Out0('Clean-up unused...');
        qr:=TQueryResult.Create(dbB,'select id from "Feed" where id>0'+
          ' and not exists (select S.id from "Subscription" S where S.feed_id="Feed".id)',[]);
        try
          j:=0;
          while qr.Read do
           begin
            i:=qr.GetInt('id');
            Write(#13'... #'+IntToStr(i)+'   ');
            dbA.BeginTrans;
            try
              dbA.Execute('delete from "UserPost" where post_id in (select P.id from "Post" P where P.feed_id=$1)',[i]);
              dbA.Execute('delete from "Opinion" where post_id in (select P.id from "Post" P where P.feed_id=$1)',[i]);
              dbA.Execute('delete from "Post" where feed_id=$1',[i]);
              dbA.Execute('delete from "Feed" where id=$1',[i]);
              dbA.CommitTrans;
            except
              dbA.RollbackTrans;
              raise;
            end;
            inc(j);
           end;
          Writeln(' '+IntToStr(j)+' feeds cleaned      ');

        finally
         qr.Free;
        end;
       end;

      Out0('Auto-unread after...');
      qr:=TQueryResult.Create(dbB,'select X.id from "UserPost" X'
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
        dbA.BeginTrans;
        try
          i:=dbA.Execute('delete from "UserPost" where id in (select X.id'
            +' from "UserPost" X'
            +' inner join "Post" P on P.id=X.post_id'
            +' inner join "Subscription" S on S.feed_id=P.feed_id and S.user_id=X.user_id'
            +' where P.pubdate<$1-S.autounread/24.0)',[double(UtcNow)]);
          dbA.CommitTrans;
        except
          dbA.RollbackTrans;
          raise;
        end;
        Writeln(' '+IntToStr(i)+' items marked read');
       end;

      OutLn('List feeds for loading...');
      LastLoadStart:=Now;
      LastFeedCount:=0;
      LastPostCount:=0;
      if FeedID<>0 then
       begin
        l:=1;
        SetLength(ids,1);
        ids[0]:=FeedID;
       end
      else
       begin
        if FeedNew then
         begin
          FeedNew:=false;//only once
          qr:=TQueryResult.Create(dbA,'select F.id from "Feed" F where F.id>0'+
            ' and F.created>$1'+FeedOrderBy,[UtcNow-1.0]);
         end
        else
          qr:=TQueryResult.Create(dbA,'select F.id from "Feed" F where F.id>0'+FeedOrderBy,[]);
        try
          l:=0;
          i:=0;
          while qr.Read do
           begin
            if i=l then
             begin
              inc(l,$400);
              SetLength(ids,l);
             end;
            ids[i]:=qr.GetInt('id');
            inc(i);
           end;
          l:=i;
        finally
          qr.Free;
        end;
       end;

      d:=UtcNow-AvgPostsDays;
      i:=0;
      while i<l do
       begin
        DoFeed(dbA,ids[i],d,sl);
        inc(i);
       end;

      OutLn(Format('Loaded: %d posts from %d feeds',[LastPostCount,LastFeedCount]));

      sl.Add('</table>');

      qr:=TQueryResult.Create(dbB,
        'select ((select count(*) from "Post")+500)/1000||''K posts, '''
        +'||((select count(*) from "UserPost")+500)/1000||''K unread, '''
        +'||pg_database_size(''feeder'')/1024000||''MB, '''
        +'||version()',[]);
      try
        while qr.Read do
          sl.Add('<p>'+HTMLEncode(qr.GetStr(0))+'</p>');
      finally
        qr.Free;
      end;

      sl.SaveToFile('..\Load.html');

    finally
      dbA.Free;
      dbB.Free;
      sl.Free;
      LastLoadDone:=Now;
    end;
  except
    on e:Exception do
     begin
      ErrLn('['+e.ClassName+']'+e.Message);
      ExitCode:=1;
     end;
  end;
end;

{
procedure DoAnalyze;
var
  db:TDataConnection;
  sl:TStringList;
begin
  if (RunContinuous<>0) and NextAnalyze then
   begin
    OutLn('Analyze...');

    sl:=TStringList.Create;
    try
      sl.LoadFromFile(FeederIniPath);
      db:=TDataConnection.Create(sl.Text);
    finally
      sl.Free;
    end;

    try
      //db.BusyTimeout:=120000;//?
      db.Execute('analyze');
    finally
      db.Free;
    end;

    OutLn('Analyze:done');
    NextAnalyze:=false;
   end;
end;
}

initialization
  Randomize;
  RunStart:=Now;//UtcNow?
  InstagramTC:=GetTickCount-InstagramTimeoutMS-InstagramTimeoutRandomPaddingMS;
  InstagramNext:=InstagramTimeoutMS;
  InstagramBadTC:=0;
  InstagramSuccess:=0;
  LastClean:=0;
  PGVersion:='';
  blacklist:=TStringList.Create;
  proxies:=TStringList.Create;
  proxiesTC:=GetTickCount;
  proxiesIndex:=0;
  proxiesLoaded:=0;//start stale
finalization
  blacklist.Free;
  proxies.Free;
end.
