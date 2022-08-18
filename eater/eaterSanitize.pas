unit eaterSanitize;

interface

uses MSXML2_TLB;

procedure SanitizeInit;
function SanitizeTrim(const x:WideString):WideString;
procedure SanitizePostID(var id:string);
function SanitizeTitle(const title:WideString):WideString;
procedure SanitizeContentType(var rt:WideString);
procedure SanitizeUnicode(var rw:WideString);
procedure SanitizeStartImg(var content:WideString);
procedure SanitizeWPImgData(var content:WideString);
procedure SanitizeFoafImg(var content:WideString);
function EncodeNonHTMLContent(const title:WideString):WideString;
function DisplayShortURL(const URL:string):string;

function FindPrefixAndCrop(var data:WideString;const pattern:WideString):boolean;
function FindMatch(const data:WideString;const pattern:WideString):WideString;

function FixUndeclNSPrefix(doc:DOMDocument60;var FeedData:WideString):boolean;
function FixNBSP(doc:DOMDocument60;var FeedData:WideString):boolean;

implementation

uses VBScript_RegExp_55_TLB, Variants;

var
  rh0,rh1,rh2,rh3,rh4,rh5,rh6,rh7,rhUTM,rhCID,rhLFs,rhTrim,
  rhStartImg,rhImgData,rhImgFoaf:RegExp;

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

  rhImgData:=nil;//see SanitizeWPImgData
  rhImgFoaf:=nil;//see SanitizeFoafImg
end;

function SanitizeTrim(const x:WideString):WideString;
begin
  Result:=rhTrim.Replace(x,'$1');
end;

procedure SanitizePostID(var id:string);
begin
  //strip '?utm_'... query string
  if rhUTM.Test(id) then id:=rhUTM.Replace(id,'');
  if rhCID.Test(id) then id:=rhCID.Replace(id,'');
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

procedure SanitizeContentType(var rt:WideString);
var
  i:integer;
begin
  if rt<>'' then
   begin
    i:=1;
    while (i<=Length(rt)) and (rt[i]<>';') do inc(i);
    if i<=Length(rt) then
     while (i>0) and (rt[i]<=' ') do dec(i);
    if (i<=Length(rt)) then SetLength(rt,i-1);
   end;
end;

procedure SanitizeUnicode(var rw:WideString);
var
  i:integer;
begin
  for i:=1 to Length(rw) do
    case word(rw[i]) of
      0..8,11,12,14..31:rw[i]:=#9;
      9,10,13:;//leave as-is
      else ;//leave as-is
    end;
end;


procedure SanitizeStartImg(var content:WideString);
begin
  if rhStartImg.Test(content) then
    content:=rhStartImg.Replace(content,'$1$3<br />');
end;

procedure SanitizeWPImgData(var content:WideString);
begin
  if rhImgData=nil then
   begin
    rhImgData:=CoRegExp.Create;
    rhImgData.Pattern:='<img(\s+?)data-(srcset="[^"]*?"\s+?)data-(src="[^"]+?")';
    //TODO: negative lookaround: no src/srcset=""
    rhImgData.Global:=true;
   end;
  content:=rhImgData.Replace(content,'<img$1$2$3');
end;

procedure SanitizeFoafImg(var content:WideString);
begin
  if rhImgFoaf=nil then
   begin
    rhImgFoaf:=CoRegExp.Create;
    rhImgFoaf.Pattern:='<noscript class="adaptive-image"[^>]*?>(<img typeof="foaf:Image"[^>]*?>)</noscript>';
    rhImgFoaf.Global:=true;
   end;
  content:=rhImgFoaf.Replace(content,'$1');
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

function DisplayShortURL(const URL:string):string;
var
  s:string;
  i,j:integer;
begin
  s:=URL;
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
  Result:=Copy(s,i,j-i);
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

function FixUndeclNSPrefix(doc:DOMDocument60;var FeedData:WideString):boolean;
var
  re:RegExp;
  s:string;
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
    FeedData:=re.Replace(FeedData,'');
    Result:=doc.loadXML(FeedData);
   end
  else
    Result:=false;
end;

function FixNBSP(doc:DOMDocument60;var FeedData:WideString):boolean;
var
  re:RegExp;
begin
  re:=CoRegExp.Create;
  re.Pattern:='&nbsp;';
  re.Global:=true;
  //rw:=re.Replace(rw,'&amp;nbsp;');
  FeedData:=re.Replace(FeedData,#$00A0);
  Result:=doc.loadXML(FeedData);
end;

end.
