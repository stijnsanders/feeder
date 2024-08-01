unit eaterSanitize;

interface

uses SysUtils, jsonDoc, MSXML2_TLB;

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

procedure SanitizeYoutubeURL(var URL:string);

procedure LoadJSON(data:IJSONDocument;const FilePath:string);
procedure PerformReplace(data:IJSONDocument;var subject:WideString);

procedure FetchSection(xItem:IXMLDOMElement;const pattern:string);

implementation

uses VBScript_RegExp_55_TLB, Variants, eaterUtils, Classes;

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

procedure SanitizeYoutubeURL(var URL:string);
const
  YoutubePrefix1a='https://www.youtube.com/@';
  YoutubePrefix1f='https://www.youtube.com/feeds/videos.xml?channel_id=';
  YoutubePrefix2a='https://www.youtube.com/channel/';
  YoutubePrefix2f='https://www.youtube.com/feeds/videos.xml?user=';
  YoutubePrefix3a='https://www.youtube.com/playlist?list=';
  YoutubePrefix3f='https://www.youtube.com/feeds/videos.xml?playlist_id=';
var
  d:ServerXMLHTTP60;
  r:RegExp;
  m:MatchCollection;
  mm:Match;
  s:string;
begin
  if StartsWith(URL,YoutubePrefix1a) then
   begin
    d:=CoServerXMLHTTP60.Create;
    d.open('GET',URL,false,EmptyParam,EmptyParam);
    d.setRequestHeader('User-Agent','FeedEater/1.1');
    d.setRequestHeader('Cookie','CONSENT=YES+US.en+V9+BX');
    d.send(EmptyParam);
    //assert d.status=200
    r:=CoRegExp.Create;
    r.Pattern:='<meta property="og:url" content="https://www.youtube.com/channel/([^"]+?)">';
    m:=r.Execute(d.responseText) as MatchCollection;
    if m.Count=0 then
      raise Exception.Create('YouTube: unable to get channel ID from channel name');
    mm:=m.Item[0] as Match;
    URL:=YoutubePrefix1f+(mm.SubMatches as SubMatches).Item[0];
   end
  else
  if StartsWithX(URL,YoutubePrefix2a,s) then
    URL:=YoutubePrefix2f+s
  else
  if StartsWithX(URL,YoutubePrefix3a,s) then
    URL:=YoutubePrefix3f+s
  else
   begin
    r:=CoRegExp.Create;
    r.Pattern:='^https://www.youtube.com/([^/@]+)$';
    m:=r.Execute(URL) as MatchCollection;
    if m.Count=1 then
     begin
      mm:=m.Item[0] as Match;
      URL:=YoutubePrefix2f+(mm.SubMatches as SubMatches).Item[0];
     end;
   end;
end;

procedure LoadJSON(data:IJSONDocument;const FilePath:string);
var
  m:TMemoryStream;
  i:integer;
  w:WideString;
begin
  m:=TMemoryStream.Create;
  try
    {
    if Copy(FilePath,Length(FilePath)-5,6)='.jsonz' then
      LoadFromCompressed(m,FilePath)
    else
    }
      m.LoadFromFile(FilePath);
    if m.Size=0 then
      w:='{}'
    else
     begin
      //UTF-16
      if (PAnsiChar(m.Memory)[0]=#$FF) and
         (PAnsiChar(m.Memory)[1]=#$FE) then
       begin
        i:=m.Size-2;
        SetLength(w,i div 2);
        Move(PAnsiChar(m.Memory)[2],w[1],i);
       end
      else
      //UTF-8
      if (PAnsiChar(m.Memory)[0]=#$EF) and
         (PAnsiChar(m.Memory)[1]=#$BB) and
         (PAnsiChar(m.Memory)[2]=#$BF) then
       begin
        m.Position:=m.Size;
        i:=0;
        m.Write(i,1);
        w:=UTF8ToWideString(PAnsiChar(@PAnsiChar(m.Memory)[3]));
       end
      //ANSI
      else
       begin
        m.Position:=m.Size;
        i:=0;
        m.Write(i,1);
        w:=string(PAnsiChar(m.Memory));
       end;
     end;
  finally
    m.Free;
  end;
  //if (w<>'') and (w[1]='[') then w:='{"":'+w+'}';
  data.Parse(w);
end;

procedure PerformReplace(data:IJSONDocument;var subject:WideString);
var
  re,re1:RegExp;
  sub:IJSONDocument;
  base,p:WideString;
  i,j,k,l:integer;
  mc:MatchCollection;
  m:Match;
  sm:SubMatches;
begin
  re:=CoRegExp.Create;
  re.Pattern:=data['x'];
  if not(VarIsNull(data['g'])) then re.Global:=boolean(data['g']);
  if not(VarIsNull(data['m'])) then re.Multiline:=boolean(data['m']);
  if not(VarIsNull(data['i'])) then re.IgnoreCase:=boolean(data['i']);
  sub:=JSON(data['p']);
  if sub=nil then
    subject:=re.Replace(subject,data['s'])
  else
   begin
    mc:=re.Execute(subject) as MatchCollection;
    if mc.Count<>0 then
     begin
      base:=subject;
      re1:=CoRegExp.Create;
      re1.Pattern:=sub['x'];
      if not(VarIsNull(sub['g'])) then re1.Global:=boolean(sub['g']);
      if not(VarIsNull(sub['m'])) then re1.Multiline:=boolean(sub['m']);
      if not(VarIsNull(sub['i'])) then re1.IgnoreCase:=boolean(sub['i']);
      j:=0;
      subject:='';
      for i:=0 to mc.Count-1 do
       begin
        m:=mc.Item[i] as Match;
        subject:=subject+Copy(base,j+1,m.FirstIndex-j);
        //assert m.Value=Copy(base,m.FirstIndex+1,m.Length)
        if VarIsNull(sub['n']) then
          subject:=subject+re1.Replace(m.Value,sub['s'])
        else
         begin
          sm:=(m.SubMatches as SubMatches);
          j:=m.FirstIndex;
          //for k:=0 to sm.Count-1 do
          k:=sub['n']-1;
           begin
            //////??????? sm.Index? Pos(sm[k],m.Value)?
            l:=m.FirstIndex;
            p:=sm[k];
            if p='' then
              j:=l+1//??
            else
             begin
              while (l<=Length(base)) and (Copy(base,l,Length(p))<>p) do inc(l);
              subject:=subject+Copy(base,j+1,l-j-1);
              subject:=subject+re1.Replace(p,sub['s']);
              j:=l+Length(p);
             end;
           end;
          subject:=subject+Copy(base,j,m.FirstIndex+m.Length-j+1);
         end;
        j:=m.FirstIndex+m.Length;
       end;
      subject:=subject+Copy(base,j+1,Length(base)-j);
     end;
   end;
end;

procedure FetchSection(xItem:IXMLDOMElement;const pattern:string);
var
  r:ServerXMLHTTP60;
  c:RegExp;
  mc:MatchCollection;
  m:Match;
  url:string;
  x:IXMLDOMElement;
begin
  c:=CoRegExp.Create;
  c.Pattern:=pattern;
  x:=xItem.selectSingleNode('link') as IXMLDOMElement;
  url:=x.text;
  r:=CoServerXMLHTTP60.Create;
  r.open('GET',url,false,EmptyParam,EmptyParam);
  r.send(EmptyParam);
  mc:=c.Execute(r.responseText) as MatchCollection;
  if mc.Count<>0 then
   begin
    //TODO: for i:=0 to mc.Count-1 do
    m:=mc[0] as Match;
    x:=xItem.ownerDocument.createElement('category');
    x.text:='section:'+(m.SubMatches as SubMatches).Item[0];
    xItem.appendChild(x);
   end;
end;

end.
