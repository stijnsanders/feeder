unit fCommon;

interface

function NameFromFeedURL(const url:string):string;
function ShowLabel(const Lbl,LblColor,ClassPrefix:string):string;
function ColorPicker(const ValColor:string):string;
function CheckColor(const ValColor:string):string;
function UtcNow:TDateTime;
procedure ClearChart(const key:string);

implementation

uses Windows, SysUtils;

function NameFromFeedURL(const url:string):string;
var
  i,j,l:integer;
begin
  l:=Length(url);
  i:=1;
  while (i<=l) and (url[i]<>':') do inc(i);
  inc(i);
  if (i<=l) and (url[i]='/') then inc(i);
  if (i<=l) and (url[i]='/') then inc(i);
  j:=i;
  while (j<=l) and (url[j]<>'/') do inc(j);
  Result:=Copy(url,i,j-i);
  if Result='feeds.feedburner.com' then
   begin
    inc(j);
    i:=j;
    while (j<=l) and (url[j]<>'/') do inc(j);
    Result:=Copy(url,i,j-i);
   end
  else if Result='www.instagram.com' then
   begin
    inc(j);
    i:=j;
    while (j<=l) and (url[j]<>'/') do inc(j);
    //Result:='i@'+Copy(url,i,j-i);
    Result:=#$D83D#$DCF8+Copy(url,i,j-i);
   end
  else if Result='reddit.com' then
   begin
    inc(j);
    i:=j;
    while (j<=l) and (url[j]<>'/') do inc(j);
    Result:='r/'+Copy(url,i,j-i);
   end
  else if Copy(Result,Length(Result)-13,14)='.wordpress.com' then
    Result:='wp:'+Copy(Result,1,Length(Result)-15);
  //more?
  if Result='' then Result:=FormatDateTime('[yyyy-mm-dd hh:nn]',UtcNow);
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

function ShowLabel(const Lbl,LblColor,ClassPrefix:string):string;
var
  c:string;
  i,j,k:integer;
begin
  if (Lbl='') and (LblColor='') then
    Result:='<div class="'+ClassPrefix+'label" title="feeder: system message" style="background-color:#FFCC00;color:#000000;border:1px solid #000000;border-radius:0;">feeder</div>'
  else
   begin
    c:=LblColor;
    if LowerCase(c)='ffffff' then c:='-666666';
    if (c<>'') and (c[1]='-') then
     begin
      while Length(c)<7 do c:='-0'+Copy(c,2,6);
      c:='FFFFFF;color:#'+Copy(c,2,6)+';border:1px solid #'+Copy(c,2,6)
     end
    else
     begin
      while Length(c)<6 do c:='0'+c;
      try
        i:=StrToInt('$0'+c);
        if i=0 then
         begin
          c:='EEEEEE';
          i:=$EEEEEE;
         end;
      except
        i:=$EEEEEE;
      end;
      j:=0;
      k:=(i shr 16) and $FF; inc(j,((k*k) shr 8)*3);//R
      k:=(i shr 8)  and $FF; inc(j,((k*k) shr 8)*5);//G
      k:= i         and $FF; inc(j,((k*k) shr 8)*2);//B
      if j<750 then c:=c+';color:#DDDDDD';
    end;
    Result:='<div class="'+ClassPrefix+'label" style="background-color:#'+c+';">'+HTMLEncode(Lbl)+'</div>';
   end;
end;

function ColorPicker(const ValColor:string):string;
var
  i,j,c:integer;
const
  hex:array[0..15] of char='0123456789ABCDEF';
begin
  try
    if ValColor='' then
      c:=$CCCCCC //default
    else
      c:=StrToInt('$0'+ValColor);
  except
    c:=0;
  end;
  Result:='<script>'+
    #13#10'function doColorSelect(xx){'+
    #13#10'  var c=document.getElementById("c1");'+
    #13#10'  var r=document.getElementById("c1r");'+
    #13#10'  var g=document.getElementById("c1g");'+
    #13#10'  var b=document.getElementById("c1b");'+
    #13#10'  var x=r.options[r.selectedIndex].label+g.options[g.selectedIndex].label+b.options[b.selectedIndex].label;'+
    #13#10'  if(xx)c.value=x;'+
    #13#10'  r.style.backgroundColor="#"+x;'+
    #13#10'  g.style.backgroundColor="#"+x;'+
    #13#10'  b.style.backgroundColor="#"+x;'+
    #13#10'  for(var i=0;i<6;i++){'+
    #13#10'    r.options[i].style.backgroundColor="#"+r.options[i].label+g.options[g.selectedIndex].label+b.options[b.selectedIndex].label;'+
    #13#10'    g.options[i].style.backgroundColor="#"+r.options[r.selectedIndex].label+g.options[i].label+b.options[b.selectedIndex].label;'+
    #13#10'    b.options[i].style.backgroundColor="#"+r.options[r.selectedIndex].label+g.options[g.selectedIndex].label+b.options[i].label;'+
    #13#10'  }'+
    #13#10'}'+
    #13#10'</script>'+
    '<input type="text" name="color" id="c1" value="'+HTMLEncode(ValColor)+'" style="width:6em;" />'
    +'&nbsp;R:<select id="c1r" onchange="doColorSelect(true);">';
  i:=0;
  j:=((c shr 16) and $FF) shr 4;
  while i<$10 do
   begin
    Result:=Result+'<option';
    if (j>i-2) and (j<=i+2) then Result:=Result+' selected="1"';
    Result:=Result+'>'+hex[i]+hex[i]+'</option>';
    inc(i,3);
   end;
  Result:=Result+'</select>&nbsp;G:<select id="c1g" onchange="doColorSelect(true);">';
  i:=0;
  j:=((c shr 8) and $FF) shr 4;
  while i<$10 do
   begin
    Result:=Result+'<option';
    if (j>i-2) and (j<=i+2) then Result:=Result+' selected="1"';
    Result:=Result+'>'+hex[i]+hex[i]+'</option>';
    inc(i,3);
   end;
  Result:=Result+'</select>&nbsp;B:<select id="c1b" onchange="doColorSelect(true);">';
  i:=0;
  j:=(c and $FF) shr 4;
  while i<$10 do
   begin
    Result:=Result+'<option';
    if (j>i-2) and (j<=i+2) then Result:=Result+' selected="1"';
    Result:=Result+'>'+hex[i]+hex[i]+'</option>';
    inc(i,3);
   end;
  Result:=Result+'</select><script>doColorSelect(false);</script>';
  Result:=Result+' //TODO: replace this with a nice color picker';
end;

function CheckColor(const ValColor:string):string;
var
  i:integer;
  c:string;
begin
  c:=ValColor;
  try
    if (c<>'') and (c[1]='#') then c:=Copy(c,2,Length(c)-1);
    if (c<>'') and (c[1]='-') then
      begin
      i:=StrToInt('$0'+Copy(c,2,999));
      if i<$1000000 then
        if Length(c)=4 then
          c:='-'+c[2]+c[2]+c[3]+c[3]+c[4]+c[4]
        else
          while Length(c)<7 do c:='-0'+Copy(c,2,999)
      else
        c:='0';
      end
    else
      begin
      i:=StrToInt('$0'+c);
      if i<$1000000 then
        if Length(c)=3 then
          c:=c[1]+c[1]+c[2]+c[2]+c[3]+c[3]
        else
          while Length(c)<6 do c:='0'+c
      else
        c:='0';
      end;
  except
    c:='';
  end;
  Result:=c;
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

procedure ClearChart(const key:string);
var
  fn:string;
begin
  SetLength(fn,MAX_PATH);
  SetLength(fn,GetModuleFileName(HInstance,PChar(fn),MAX_PATH));
  DeleteFile(PChar(ExtractFilePath(fn)+'charts\'+key+'.png'));
end;

end.
