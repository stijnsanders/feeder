unit fCommon;

interface

function NameFromFeedURL(const url:string):string;
function ShowLabel(const Lbl,LblColor:string):string;
function ColorPicker(const ValColor:string):string;

implementation

uses SysUtils;

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

function ShowLabel(const Lbl,LblColor:string):string;
var
  c:string;
  i,j,k:integer;
begin
  if Length(LblColor)<>6 then c:='EEEEEE' else c:=LblColor;
  try
    i:=StrToInt('$0'+c);
  except
    i:=$EEEEEE;
  end;
  k:=(i and $FF);
  j:=k;
  i:=i shr 8;
  k:=i and $FF;
  inc(j,k*4);
  i:=i shr 8;
  k:=i and $FF;
  inc(j,k*3);
  if j<=770 then c:=c+';color:#DDDDDD;';
  Result:='<div class="label" style="background-color:#'+c+';">'+HTMLEncode(Lbl)+'</div>';
end;

function ColorPicker(const ValColor:string):string;
var
  i,j,c:integer;
const
  hex:array[0..15] of char='0123456789ABCDEF';
begin
  try
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
    if j=i then Result:=Result+' selected="1"';
    Result:=Result+'>'+hex[i]+hex[i]+'</option>';
    inc(i,3);
   end;
  Result:=Result+'</select>&nbsp;G:<select id="c1g" onchange="doColorSelect(true);">';
  i:=0;
  j:=((c shr 8) and $FF) shr 4;
  while i<$10 do
   begin
    Result:=Result+'<option';
    if j=i then Result:=Result+' selected="1"';
    Result:=Result+'>'+hex[i]+hex[i]+'</option>';
    inc(i,3);
   end;
  Result:=Result+'</select>&nbsp;B:<select id="c1b" onchange="doColorSelect(true);">';
  i:=0;
  j:=(c and $FF) shr 4;
  while i<$10 do
   begin
    Result:=Result+'<option';
    if j=i then Result:=Result+' selected="1"';
    Result:=Result+'>'+hex[i]+hex[i]+'</option>';
    inc(i,3);
   end;
  Result:=Result+'</select><script>doColorSelect(false);</script>';
end;

end.
