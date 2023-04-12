unit eaterUtils;

interface

procedure OutLn(const x:string);
procedure ErrLn(const x:string);
procedure Out0(const x:string);
procedure SaveUTF16(const fn:string;const Data:WideString);

function StartsWith(const Value,Prefix:string):boolean;
function StartsWithX(const Value,Prefix:string;var Suffix:string):boolean;
function HTMLStartsWithImg(const Value:string):boolean;

function ConvDate1(const x:string):TDateTime;
function ConvDate2(const x:string):TDateTime;
function UtcNow:TDateTime;

function HTMLEncode(const x:string):string;
function HTMLEncodeQ(const x:string):string;
function URLEncode(const x:string):AnsiString;
function StripWhiteSpace(const x:WideString):WideString;
function IsSomethingEmpty(const x:WideString):boolean;
function StripHTML(const x:WideString;MaxLength:integer):WideString;
function HTMLDecode(const w:WideString):WideString;
function IsProbablyHTML(const x:WideString):boolean;

function VarArrFirst(const v:Variant):Variant;
function VarArrLast(const v:Variant):Variant;

implementation

uses Windows, SysUtils, Variants, Classes;

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

procedure SaveUTF16(const fn:string;const Data:WideString);
var
  rf:TFileStream;
  i:word;
begin
  rf:=TFileStream.Create(fn,fmCreate);
  try
    i:=$FEFF;
    rf.Write(i,2);
    rf.Write(Data[1],Length(Data)*2);
  finally
    rf.Free;
  end;
end;

function StartsWith(const Value,Prefix:string):boolean; inline;
begin
  Result:=Copy(Value,1,Length(Prefix))=Prefix;
end;

function StartsWithX(const Value,Prefix:string;var Suffix:string):boolean;
begin
  if Copy(Value,1,Length(Prefix))=Prefix then
   begin
    Suffix:=Copy(Value,Length(Prefix)+1,Length(Value)-Length(Prefix));
    Result:=true;
   end
  else
    Result:=false;
end;

function HTMLStartsWithImg(const Value:string):boolean;
var
  i,j,l:integer;
  ok:boolean;
  s:string;
begin
  i:=1;
  l:=Length(Value);
  Result:=false;//default
  ok:=true;//
  while ok do
   begin
    //ignore white space
    while (i<=l) and (Value[i]<=' ') do inc(i);
    //next element
    if (i<=l) and (Value[i]='<') then
     begin
      inc(i);
      j:=i;
      while (j<=l) and (Value[j]<>' ') and (Value[j]<>'>') and (Value[j]<>'/') do inc(j);
      s:=LowerCase(Copy(Value,i,j-i));
      //skippable?
      if (s='a') or (s='div') or (s='p') or (s='center') then
        //continue loop
      else
      //image?
      if (s='img') or (s='figure') then
       begin
        Result:=true;
        ok:=false;//end loop
       end;
      if ok then
       begin
        i:=j;
        while (i<=l) and (Value[i]<>'>') do inc(i);
        inc(i);
       end;
     end
    else
      ok:=false;//end loop
   end;
end;

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
    //ignore superflous digits
    while (i<=l) and (AnsiChar(x[i]) in ['0'..'9']) do inc(i);
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
  st:TSystemTime;
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
  //check number of digits
  j:=i;
  if (i<=l) and (AnsiChar(x[i]) in ['0'..'9']) then
    while (j<=l) and (AnsiChar(x[j]) in ['0'..'9']) do inc(j);
  if j-i=4 then //assume "yyyy-mm-dd hh:nn:ss
    Result:=ConvDate1(x)
  else
   begin
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
    if dy<100 then
     begin
      //guess century
      GetSystemTime(st);
      j:=st.wYear div 100;
      if ((st.wYear mod 100)>70) and (dy<30) then dec(j);//?
      dy:=dy+j*100;
     end;
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
end;

function UtcNow:TDateTime;
var
  st:TSystemTime;
begin
  GetSystemTime(st);
  Result:=
    EncodeDate(st.wYear,st.wMonth,st.wDay)+
    EncodeTime(st.wHour,st.wMinute,st.wSecond,st.wMilliseconds);
end;

function HTMLEncode(const x:string):string;
begin
  //TODO: redo smarter than sequential StringReplace
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

function HTMLEncodeQ(const x:string):string;
begin
  Result:=
    StringReplace(
    StringReplace(
    StringReplace(
    StringReplace(
      x
      ,'&','&amp;',[rfReplaceAll])
      ,'<','&lt;',[rfReplaceAll])
      ,'>','&gt;',[rfReplaceAll])
      ,'"','&quot;',[rfReplaceAll])
  ;
end;

function URLEncode(const x:string):AnsiString;
const
  Hex:array[0..15] of AnsiChar='0123456789abcdef';
var
  s,t:AnsiString;
  p,q,l:integer;
begin
  s:=UTF8Encode(x);
  q:=1;
  l:=Length(s)+$80;
  SetLength(t,l);
  for p:=1 to Length(s) do
   begin
    if q+4>l then
     begin
      inc(l,$80);
      SetLength(t,l);
     end;
    case s[p] of
      #0..#31,'"','#','$','%','&','''','+','/',
      '<','>','?','@','[','\',']','^','`','{','|','}',
      #$80..#$FF:
       begin
        t[q]:='%';
        t[q+1]:=Hex[byte(s[p]) shr 4];
        t[q+2]:=Hex[byte(s[p]) and $F];
        inc(q,2);
       end;
      ' ':
        t[q]:='+';
      else
        t[q]:=s[p];
    end;
    inc(q);
   end;
  SetLength(t,q-1);
  Result:=t;
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

function IsProbablyHTML(const x:WideString):boolean;
var
  i:integer;
begin
  i:=1;
  while (i<=Length(x)) and (x[i]<=' ') do inc(i); //skip whitespace
  Result:=(i<=Length(x)) and (x[i]='<');
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
  if VarIsArray(v) and (VarArrayHighBound(v,1)>=VarArrayLowBound(v,1)) then
    Result:=v[VarArrayHighBound(v,1)]
  else
    Result:=Null;
end;

end.
