unit express1;

interface

procedure BuildExpress;

//TODO: from ini
const
  FeederIniPath='..\..\feeder.ini';

implementation

uses Windows, SysUtils, Classes, DataLank, VBScript_RegExp_55_TLB, fCommon;

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

procedure BuildExpress;
var
  UserID,i,tz,q:integer;
  d0,d1:TDateTime;
  TimeBias:double;
  s,fn,html,c,ClassPrefix:string;
  sl:TStringList;
  db:TDataConnection;
  qr:TQueryResult;
  f:TFileStream;
  w:word;
  rp1,rp2,rp3:IRegExp2;
  DoStyle:boolean;

  function PNext:string;
  begin
    Result:=ParamStr(i);
    inc(i);
  end;

begin

  //defaults
  UserID:=1;
  d0:=Trunc(UtcNow);
  ClassPrefix:='';
  fn:='';
  DoStyle:=true;

  //arguments
  i:=1;
  while i<=ParamCount do
   begin
    s:=PNext;

    try
      if s='-u' then
        UserID:=StrToInt(PNext)
      else
      if s='-dd' then
        d0:=Trunc(UtcNow)-StrToInt(PNext)
      else
      if s='-d' then
        d0:=StrToInt(PNext)
      else
      if s='-cp' then
        ClassPrefix:=PNext
      else
      if s='-o' then
        fn:=PNext
      else
      if s='-nostyle' then
        DoStyle:=false
      else
        raise Exception.Create('Unknown argument "'+s+'"');
    except
      on e:Exception do
       begin
        e.Message:='[Argument"'+s+'"]'+e.Message;
        raise;
       end;
    end;

   end;

  rp1:=CoRegExp.Create;
  rp1.Pattern:='\[([^\]]+?)\]\(([^\)]+?)\)';
  rp1.Global:=true;
  rp2:=CoRegExp.Create;
  rp2.Pattern:='\*\*([^\*]+?)\*\*';
  rp2.Global:=true;
  rp3:=CoRegExp.Create;
  rp3.Pattern:='__([^_]+?)__';
  rp3.Global:=true;

  //db
  sl:=TStringList.Create;
  try
    sl.LoadFromFile(FeederIniPath);
    db:=TDataConnection.Create(sl.Text);
  finally
    sl.Free;
  end;
  try

    qr:=TQueryResult.Create(db,'select timezone from "User" where id=$1',[UserID]);
    try
      tz:=qr.GetInt('timezone');
    finally
      qr.Free;
    end;

    TimeBias:=(tz div 100)/24.0+(tz mod 100)/1440.0;

    html:='';
    q:=0;

    if DoStyle then
      html:='<style type="text/css">'
        +#13#10'DIV.feeder{background-color:#FFFFFF;padding:0.2em;}'
        +#13#10'DIV.label{display:inline;font-size:10pt;padding:2pt;border-radius:4pt;white-space:nowrap;}'
        +#13#10'DIV.date{display:inline;font-size:10pt;background-color:#CCCCCC;padding:2pt;border-radius:4pt;}'
        +#13#10'</style>'
        +#13#10'<div style="feeder">'
        +#13#10#13#10
        ;

    qr:=TQueryResult.Create(db,
      'select P.id, P.guid, P.url, P.created, P.pubdate, P.title, O.opinion, O.created, S.label, S.color'+
      ' from "Opinion" O'+
      ' inner join "Post" P on P.id=O.post_id'+
      ' inner join "Feed" F on F.id=P.feed_id'+
      ' left outer join "Subscription" S on S.feed_id=P.feed_id and S.user_id=$1'+
      ' where O.user_id=$1'+
      ' and O.created>=$2 and O.created<=$3'+
      ' order by O.created',[UserID,d0+TimeBias,d0+1+TimeBias]);
    try
      while qr.Read do
       begin
        inc(q);
        d1:=double(qr['pubdate'])+TimeBias;
        html:=html
          +'<div class="'+ClassPrefix+'date" title="'+FormatDateTime('ddd yyyy-mm-dd hh:nn:ss',d1)+'">'
          +FormatDateTime('mm-dd hh:nn',d1)+'</div>&nbsp;'
          +ShowLabel(qr.GetStr('label'),qr.GetStr('color'),ClassPrefix)
          +'<a name="'+FormatDateTime('yyyy-mm-dd',d0)+'-'+IntToStr(q)+'"></a>&nbsp;'
          +'<a href="'+HTMLEncode(qr.GetStr('url'))+'" rel="noreferrer" target="_blank" style="font-weight:bold;">'
          +qr.GetStr('title')+'</a></div>'
          +'<div style="margin-left:2em;margin-bottom:0.4em;" title="'
          +FormatDateTime('dddd yyyy-mm-dd hh:nn',double(qr['created'])+TimeBias)+'">'
          ;

        c:=HTMLEncode(qr.GetStr('opinion'));

        c:=rp1.Replace(c,'<a href="$2">$1</a>');
        c:=rp2.Replace(c,'<b>$1</b>');
        c:=rp3.Replace(c,'<i>$1</i>');

        html:=html+c+'</div>'#13#10;

       end;
    finally
      qr.Free;
    end;

    if DoStyle then
      html:=html+'</div>'#13#10;

    if q<>0 then
     begin
      if fn='' then fn:=FormatDateTime('yyyy-mm-dd',d0)+'.html';
      f:=TFileStream.Create(fn,fmCreate);
      try
        w:=$FEFF;
        f.Write(w,2);
        f.Write(html[1],Length(html)*2);
      finally
        f.Free;
      end;
     end;

  finally
    db.Free;
  end;
end;

end.
