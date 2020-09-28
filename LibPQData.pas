unit LibPQData;
{

  LibPQData: thin LibPQ wrapper to connect to a PostgreSQL server.

  https://github.com/stijnsanders/DataLank

ATTENTION:

Include following files in the folder that contains the executable,
or in a folder included in the default DLL search path.
They are provided with the Windows PostgreSQL server install.

  libpq.dll
  libssl-1_1.dll
  libcrypto-1_1.dll
  libiconv-2.dll
  libintl-8.dll

}

interface

//debugging: prevent step-into from debugging TQueryResult calls:
{$D-}
{$L-}

{xxxxx$DEFINE LIBPQDATA_TRANSFORMQM}

uses SysUtils, LibPQ;

type
  TPostgresConnection=class(TObject)
  private
    FDB:PGConn;
    procedure Exec(const SQL:UTF8String);
  public
    constructor Create(const ConnectionInfo: WideString);
    destructor Destroy; override;
    procedure BeginTrans;
    procedure CommitTrans;
    procedure RollbackTrans;
    function Execute(const SQL: WideString;
      const Values: array of Variant): integer;
    function Insert(const TableName: UTF8String; const Values: array of Variant;
      const PKFieldName: UTF8String=''): int64;
    procedure Update(const TableName: UTF8String; const Values:array of Variant);
  end;

  TPostgresCommand=class(TObject)
  private
    FFirstRead:boolean;
    function GetValue(Idx:Variant):Variant;
    function IsEof:boolean;
    function GetCount:integer;
  protected
    FDB:PGConn;
    FRecordSet:PGResult;
    FTuple:integer;
  public
    constructor Create(Connection: TPostgresConnection; const SQL: WideString;
      const Values: array of Variant);
    destructor Destroy; override;
    procedure Reset;
    function Read:boolean;
    property Fields[Idx:Variant]:Variant read GetValue; default;
    property EOF: boolean read IsEof;
    property Count: integer read GetCount;
    function GetInt(const Idx:Variant):integer;
    function GetStr(const Idx:Variant):WideString;
    function GetDate(const Idx:Variant):TDateTime;
    function GetInterval(const Idx:Variant):TDateTime;
    function IsNull(const Idx:Variant):boolean;
  end;

  EPostgres=class(Exception);
  EQueryResultError=class(Exception);

function RefCursor(const CursorName:WideString):Variant;

implementation

uses Variants;

//hardcoded object ID's (defined by \include\server\catalog\pg_type.h)
const
  Oid_bool = 16; //boolean, 'true'/'false'
  Oid_bytea = 17; //variable-length string, binary values escaped
  Oid_int8 = 20; //~18 digit integer, 8-byte storage
  Oid_int2 = 21; //-32 thousand to 32 thousand, 2-byte storage
  Oid_int4 = 23; //-2 billion to 2 billion integer, 4-byte storage
  Oid_text = 25; //variable-length string, no limit specified
  Oid_xml = 142; //XML content
  Oid_float4 = 700; //single-precision floating point number, 4-byte storage
  Oid_float8 = 701; //double-precision floating point number, 8-byte storage
  Oid_unknown = 705; //(used with varNull below)
  Oid_money = 790; //monetary amounts, $d,ddd.cc
  Oid_bpchar = 1042; //char(length), blank-padded string, fixed storage length
  Oid_varchar = 1043; //varchar(length), non-blank-padded string, variable storage length
  Oid_date = 1082; //date
  Oid_time = 1083; //time of day
  Oid_timestamp = 1114; //date and time
  Oid_timestamptz = 1184; //date and time with time zone
  Oid_interval = 1186;
  Oid_numeric = 1700; //numeric(precision, decimal), arbitrary precision number
  Oid_refcursor = 1790; //reference to cursor (portal name)
  Oid_uuid = 2950; //UUID datatype

var
  RefCursorCatch:Variant;//see initialization

function RefCursor(const CursorName:WideString):Variant;
begin
  //assert: caller does transaction!
  //package a bespoke array with a reference to secret fixed thing,
  //see AddParam that check this when VarType=varArray or varVariant
  Result:=VarArrayCreate([0,1],varVariant);
  Result[0]:=VarArrayRef(RefCursorCatch);
  Result[1]:=CursorName;
end;

function AddParam(const v: Variant; var vt: Oid; var vs: UTF8String;
  var vv: pointer; var vl: integer; var vf: integer): boolean;
var
  ods:Char;
  rds:PChar;
  d:TDateTime;
const
  NullStr:AnsiString=#0;
begin
  rds:=@{$IF Declared(FormatSettings)}FormatSettings.{$IFEND}DecimalSeparator;
  Result:=true;//default
  //TODO: varArray
  case VarType(v) of
    varEmpty,varNull:
     begin
      vt:=Oid_unknown;
      vs:='';
      vv:=nil;
      vl:=0;
      vf:=0;
     end;
    varSmallint,varShortInt,varByte,varWord:
     begin
      vt:=Oid_int2;
      vs:=UTF8String(VarToStr(v));//IntToStr?
      vv:=@vs[1];
      vl:=Length(vs);
      vf:=0;
     end;
    varInteger,varLongWord:
     begin
      vt:=Oid_int4;
      vs:=UTF8String(VarToStr(v));//IntToStr?
      vv:=@vs[1];
      vl:=Length(vs);
      vf:=0;
     end;
    varInt64,$15{varUInt64}:
     begin
      vt:=Oid_int8;
      vs:=UTF8Encode(VarToWideStr(v));//IntToStr64?
      vv:=@vs[1];
      vl:=Length(vs);
      vf:=0;
     end;
    varSingle:
     begin
      ods:=rds^;
      rds^:='.';
      try
        vt:=Oid_float4;
        vs:=UTF8String(FloatToStr(v));
        vv:=@vs[1];
        vl:=Length(vs);
        vf:=0;
      finally
        rds^:=ods;
      end;
     end;
    varDouble,$E{varDecimal}:
     begin
      ods:=rds^;
      rds^:='.';
      try
        vt:=Oid_float8;
        vs:=UTF8String(FloatToStr(v));
        vv:=@vs[1];
        vl:=Length(vs);
        vf:=0;
      finally
        rds^:=ods;
      end;
     end;
    varCurrency:
     begin
      ods:=rds^;
      rds^:='.';
      try
        vt:=Oid_money;
        vs:=UTF8String(FloatToStr(v));
        vv:=@vs[1];
        vl:=Length(vs);
        vf:=0;
      finally
        rds^:=ods;
      end;
     end;
    varDate:
     begin
      d:=VarToDateTime(v);
      vt:=Oid_timestamp;//?
      if d=0.0 then
       begin
        vs:='';
        vv:=nil;
        vl:=0;
       end
      else
       begin
        vs:=UTF8String(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz',d));
        vv:=@vs[1];
        vl:=Length(vs);
       end;
      vf:=0;
     end;
    varOleStr,varString,$0102{varUString}:
     begin
      vt:=Oid_varchar;//?Oid_text?
      vs:=UTF8Encode(VarToWideStr(v));
      if vs='' then vv:=@NullStr[1] else vv:=@vs[1];
      vl:=Length(vs);
      vf:=0;
     end;
    {
    varDispatch,varUnknown:
     begin
      //check is XML doc?
      vt:=Oid_xml;
      vs:=UTF8Encode((IUnknown(v) as IXMLDOMNode).xml);
      vv:=@vs[1];
      vl:=Length(vs);
      vf:=0;
     end;
    }
    varBoolean:
     begin
      vt:=Oid_bool;
      if v then vs:='t' else vs:='f';
      vv:=@vs[1];
      vl:=1;//Length(vs);
      vf:=0;
     end;
    //varVariant...
    //varRecord?
    varStrArg:
     begin
      vt:=Oid_uuid;
      vs:=UTF8Encode(VarToWideStr(v));
      vv:=@vs[1];
      vl:=Length(vs);
      vf:=0;
     end;
    //varObject?
    //varUStrArg?
    //varAny?
    //varUString?
    varArray or varVariant:
      if (VarArrayLowBound(v,1)=0) and (VarArrayHighBound(v,1)=1)
        and (TVarData(v[0]).VPointer=@TVarData(RefCursorCatch).VArray) then
       begin
        vt:=Oid_refcursor;
        vs:=UTF8Encode(VarToWideStr(v[1]));
        vv:=@vs[1];
        vl:=Length(vs);
        vf:=0;
       end
      else
        Result:=false;
    else
      Result:=false;
  end;
end;

{$IF not Declared(UTF8ToWideString)}
function UTF8ToWideString(const s: UTF8String): WideString;
begin
  Result:=UTF8Decode(s);
end;
{$IFEND}

{$IFDEF LIBPQDATA_TRANSFORMQM}
function PrepSQL(const SQL: UTF8String): PAnsiChar;
var
  s:UTF8String;
  i,j,k,l:integer;
begin
  i:=1;
  j:=1;
  k:=0;
  l:=Length(SQL);
  SetLength(s,l*2);
  while (i<=l) do
   begin
    while (i<=l) and (SQL[i]<>'?') do
     begin
      s[j]:=SQL[i];
      inc(i);
      inc(j);
     end;
    if i<=l then
     begin
      s[j]:='$';
      inc(i);
      inc(j);
      inc(k);
      if k<10 then
       begin
        s[j]:=AnsiChar(k or $30);
        inc(j);
       end
      else
      if k<100 then
       begin
        s[j]:=AnsiChar((k div 10) or $30);
        inc(j);
        s[j]:=AnsiChar((k mod 10) or $30);
        inc(j);
       end
      else
        raise EPostgres.Create('Maximum number of question marks exceeded');
     end;
   end;
  SetLength(s,j-1);
  Result:=@s[1];
end;
{$ELSE}
function PrepSQL(const SQL: UTF8String): PAnsiChar; inline;
begin
  Result:=@SQL[1];
end;
{$ENDIF}

procedure SendQuery(DB: PGConn; const SQL: UTF8String;
  const Values: array of Variant);
var
  i:integer;
  pn:integer;
  pt:array of Oid;
  ps:array of UTF8String;
  pv:array of pointer;
  pl:array of integer;
  pf:array of integer;
begin
  pn:=Length(Values);
  if pn=0 then
   begin
    if PQsendQuery(DB,PrepSQL(SQL))=0 then
      raise EPostgres.Create(UTF8ToWideString(PQerrorMessage(DB)));
   end
  else
   begin
    SetLength(pt,pn);
    SetLength(ps,pn);
    SetLength(pv,pn);
    SetLength(pl,pn);
    SetLength(pf,pn);

    for i:=0 to pn-1 do
      if not AddParam(Values[i],pt[i],ps[i],pv[i],pl[i],pf[i]) then
        raise Exception.Create('Unsupported Parameter Type: #'+IntToStr(i+1));

    if PQsendQueryParams(DB,PrepSQL(SQL),pn,@pt[0],@pv[0],@pl[0],@pf[0],0)=0 then
      raise EPostgres.Create(UTF8ToWideString(PQerrorMessage(DB)));
   end;
end;

{ TPostgresConnection }

constructor TPostgresConnection.Create(const ConnectionInfo: WideString);
var
  s,e:UTF8String;
begin
  inherited Create;
  s:=UTF8Encode(ConnectionInfo);
  FDB:=PQconnectdb(@s[1]);
  if FDB.Handle=nil then
    raise EPostgres.Create('Connect failed');
  e:=PQerrorMessage(FDB);
  if e<>'' then
    raise EPostgres.Create(UTF8ToWideString(e));
end;

destructor TPostgresConnection.Destroy;
begin
  if FDB.Handle<>nil then
   begin
    PQfinish(FDB);
    FDB.Handle:=nil;
   end;
  inherited;
end;

procedure TPostgresConnection.Exec(const SQL: UTF8String);
var
  r:PGResult;
  e:UTF8String;
begin
  r:=PQexec(FDB,@SQL[1]);
  if r.Handle=nil then
    raise EPostgres.Create('Exec error '+UTF8ToWideString(PQerrorMessage(FDB)));
  try
    e:=PQresultErrorMessage(r);
    if e<>'' then
      raise EPostgres.Create(UTF8ToWideString(e));
  finally
    PQclear(r);
  end;
end;

procedure TPostgresConnection.BeginTrans;
begin
  Exec('begin');
  //TODO: support savepoints
end;

procedure TPostgresConnection.CommitTrans;
begin
  Exec('commit');
end;

procedure TPostgresConnection.RollbackTrans;
begin
  Exec('rollback');
end;

function TPostgresConnection.Execute(const SQL: WideString;
  const Values: array of Variant): integer;
var
  r:PGResult;
  s,e:UTF8String;
  i:integer;
begin
  try
    SendQuery(FDB,UTF8Encode(SQL),Values);

    Result:=0;//see below
    r:=PQgetResult(FDB);
    if r.Handle=nil then
      e:=PQerrorMessage(FDB)
    else
      e:=PQresultErrorMessage(r);
    if e<>'' then
      raise EPostgres.Create(UTF8ToWideString(e));

    while r.Handle<>nil do
     begin
      s:=PQcmdTuples(r);
      if s<>'' then
        if TryStrToInt(string(s),i) then inc(Result,i) else
          raise EPostgres.Create('Unexpected Tuples Response: "'+
            UTF8ToWideString(s)+'"');
      PQclear(r);
      r:=PQgetResult(FDB);
      if r.Handle<>nil then
       begin
        e:=PQresultErrorMessage(r);
        if e<>'' then
          raise EPostgres.Create(UTF8ToWideString(e));
       end;
     end;
  except
    on e:Exception do
     begin
      r:=PQgetResult(FDB);
      while r.Handle<>nil do
       begin
        PQclear(r);
        r:=PQgetResult(FDB);
       end;
      raise;
     end;
  end;
end;

function TPostgresConnection.Insert(const TableName: UTF8String;
  const Values: array of Variant; const PKFieldName: UTF8String=''): int64;
var
  r:PGResult;
  i,l:integer;
  pn:integer;
  pt:array of Oid;
  ps:array of UTF8String;
  pv:array of pointer;
  pl:array of integer;
  pf:array of integer;
  sql1,sql2,e:UTF8String;
begin
  sql1:='';
  sql2:='';
  l:=Length(Values);
  if (l and 1)<>0 then
    raise EQueryResultError.Create('Insert('''+string(TableName)+''') requires an even number of values');

  pn:=l div 2;
  SetLength(pt,pn);
  SetLength(ps,pn);
  SetLength(pv,pn);
  SetLength(pl,pn);
  SetLength(pf,pn);
  pn:=0;//re-count, see below
  i:=1;

  while i<l do
   begin
    if not VarIsNull(Values[i]) then
     begin
      sql1:=sql1+','+UTF8Encode(VarToWideStr(Values[i-1]));
      if not AddParam(Values[i],pt[pn],ps[pn],pv[pn],pl[pn],pf[pn]) then
        raise Exception.Create('Unsupported Parameter Type: TableName="'+string(TableName)+'" #'+IntToStr((i div 2)+1));
      inc(pn);
      sql2:=sql2+',$'+UTF8String(IntToStr(pn));
     end;
    inc(i,2);
   end;

  //TODO: check TableName,Values[i*2] on sql-safe!

  sql1[1]:='(';
  sql2[1]:='(';
  if PKFieldName='' then
    sql2:=sql2+')'
  else
    sql2:=sql2+') returning '+PKFieldName;

  sql1:='insert into "'+TableName+'" '+sql1+') values '+sql2;
  if PQsendQueryParams(FDB,@sql1[1],pn,@pt[0],@pv[0],@pl[0],@pf[0],0)=0 then
    raise EPostgres.Create(UTF8ToWideString(PQerrorMessage(FDB)));

  r:=PQgetResult(FDB);
  if r.Handle=nil then
    e:=PQerrorMessage(FDB)
  else
    e:=PQresultErrorMessage(r);
  if e<>'' then
    raise EPostgres.Create(UTF8ToWideString(e));

  if PQntuples(r)=0 then
    Result:=-1
  else
   begin
    e:=PQgetvalue(r,0,0);
    if e='' then Result:=-1 else Result:=StrToInt64(string(e));
   end;

  while r.Handle<>nil do
   begin
    PQclear(r);
    r:=PQgetResult(FDB);
   end;
end;

procedure TPostgresConnection.Update(const TableName: UTF8String; const Values: array of Variant);
var
  r:PGResult;
  i,l:integer;
  pn:integer;
  pt:array of Oid;
  ps:array of UTF8String;
  pv:array of pointer;
  pl:array of integer;
  pf:array of integer;
  sql1,sql2,e:UTF8String;
begin
  sql1:='';
  sql2:='';
  l:=Length(Values);
  if (l and 1)<>0 then
    raise EQueryResultError.Create('Update('''+string(TableName)+''') requires an even number of values');

  pn:=l div 2;
  SetLength(pt,pn);
  SetLength(ps,pn);
  SetLength(pv,pn);
  SetLength(pl,pn);
  SetLength(pf,pn);
  pn:=0;//re-count, see below
  i:=1;
  while i<l do
   begin
    if not VarIsNull(Values[i]) then
     begin
      if not AddParam(Values[i],pt[pn],ps[pn],pv[pn],pl[pn],pf[pn]) then
        raise Exception.Create('Unsupported Parameter Type: TableName="'+string(TableName)+'" #'+IntToStr((i div 2)+1));
      inc(pn);
      if pn=1 then
        sql2:=' where '+UTF8Encode(VarToWideStr(Values[i-1]))+'=$1'//'+IntToStr(i)
      else
        sql1:=sql1+','+UTF8Encode(VarToWideStr(Values[i-1]))+'=$'+UTF8String(IntToStr(pn));
     end;
    inc(i,2);
   end;

  sql1[1]:=' ';
  sql1:='update "'+TableName+'" set'+sql1+sql2;
  if PQsendQueryParams(FDB,@sql1[1],pn,@pt[0],@pv[0],@pl[0],@pf[0],0)=0 then
    raise EPostgres.Create(UTF8ToWideString(PQerrorMessage(FDB)));

  r:=PQgetResult(FDB);
  if r.Handle=nil then
    e:=PQerrorMessage(FDB)
  else
    e:=PQresultErrorMessage(r);
  if e<>'' then
    raise EPostgres.Create(UTF8ToWideString(e));
  while r.Handle<>nil do
   begin
    PQclear(r);
    r:=PQgetResult(FDB);
   end;
end;

{ TPostgresCommand }

constructor TPostgresCommand.Create(Connection: TPostgresConnection;
  const SQL: WideString; const Values: array of Variant);
var
  e:UTF8String;
  r:PGResult;
begin
  inherited Create;
  //TODO: check PQisbusy?
  try
    FDB:=Connection.FDB;
    SendQuery(FDB,UTF8Encode(SQL),Values);
    //PQsetSingleRowMode(QueryDbConLive); //TODO!!
    FTuple:=0;
    FRecordSet:=PQgetResult(FDB);
    if FRecordSet.Handle=nil then
      e:=PQerrorMessage(FDB)
    else
      e:=PQresultErrorMessage(FRecordSet);
    if e<>'' then
      raise EPostgres.Create(UTF8ToWideString(e));
    FFirstRead:=true;
  except
    if FRecordSet.Handle<>nil then
      PQclear(FRecordSet);
    r:=PQgetResult(FDB);
    while r.Handle<>nil do
     begin
      PQclear(r);
      r:=PQgetResult(FDB);
     end;
    raise;
  end;
end;

destructor TPostgresCommand.Destroy;
begin
  while FRecordSet.Handle<>nil do
   begin
    PQclear(FRecordSet);
    FRecordSet:=PQgetResult(FDB);
   end;
  inherited;
end;

function TPostgresCommand.Read: boolean;
begin
  if (FRecordSet.Handle=nil) or (PQntuples(FRecordSet)=FTuple) then Result:=false else
   begin
    if FFirstRead then FFirstRead:=false else
     begin
      {if streaming then
       begin
        if FRecordSet<>nil then PQclear(FRecordSet);
        FRecordSet:=PQgetResult(FRecordSet);
       end
      else
      }
      inc(FTuple);
     end;
    Result:=not((FRecordSet.Handle=nil) or (PQntuples(FRecordSet)=FTuple));
   end;
end;

procedure TPostgresCommand.Reset;
begin
  FFirstRead:=true;
  if FTuple<>0 then FTuple:=0;
end;

function TPostgresCommand.GetInt(const Idx: Variant): integer;
var
  i:integer;
  s:UTF8String;
begin
  if IsEOF then raise EQueryResultError.Create('Reading past EOF.');
  if VarIsNumeric(Idx) then i:=Idx else
   begin
    s:=UTF8String(VarToStr(Idx));
    i:=PQfnumber(FRecordSet,@s[1]);
   end;
  if i=-1 then
    raise EQueryResultError.Create('GetInt: Field not found: '+VarToStr(Idx));
  if PQgetisnull(FRecordSet,FTuple,i)=0 then
    Result:=StrToInt(string(PQgetvalue(FRecordSet,FTuple,i)))
  else
    Result:=0;//?
end;

function TPostgresCommand.GetStr(const Idx: Variant): WideString;
var
  i:integer;
  s:UTF8String;
begin
  if IsEOF then raise EQueryResultError.Create('Reading past EOF.');
  if VarIsNumeric(Idx) then i:=Idx else
   begin
    s:=UTF8String(VarToStr(Idx));
    i:=PQfnumber(FRecordSet,@s[1]);
   end;
  if i=-1 then
    raise EQueryResultError.Create('GetStr: Field not found: '+VarToStr(Idx));
  if PQgetisnull(FRecordSet,FTuple,i)=0 then
    Result:=UTF8ToWideString(PQgetvalue(FRecordSet,FTuple,i))
  else
    Result:='';//?
end;

function TPostgresCommand.GetDate(const Idx: Variant): TDateTime;
var
  i,l,f:integer;
  dy,dm,dd,th,tm,ts,tz:word;
  s:UTF8String;
  function Next:word;
  begin
    Result:=0;
    while (i<=l) and (s[i] in ['0'..'9']) do
     begin
      Result:=Result*10+(byte(s[i]) and $F);
      inc(i);
     end;
  end;
begin
  if IsEOF then raise EQueryResultError.Create('Reading past EOF.');
  if VarIsNumeric(Idx) then i:=Idx else
   begin
    s:=UTF8String(VarToStr(Idx));
    i:=PQfnumber(FRecordSet,@s[1]);
   end;
  if i=-1 then
    raise EQueryResultError.Create('GetDate: Field not found: '+VarToStr(Idx));
  if PQgetisnull(FRecordSet,FTuple,i)=0 then
   begin
    s:=PQgetvalue(FRecordSet,FTuple,i);
    i:=1;
    l:=Length(s);
    dy:=Next;
    inc(i);//'-'
    dm:=Next;
    inc(i);//'-'
    dd:=Next;
    inc(i);//' '
    th:=Next;
    inc(i);//':'
    tm:=Next;
    inc(i);//':'
    ts:=Next;
    inc(i);//'.'
    tz:=0;//Next;//more precision than milliseconds here, encode floating:

    f:=24*60*60;
    Result:=0.0;
    while (i<=l) and (s[i] in ['0'..'9']) do
     begin
      f:=f*10;
      Result:=Result+(byte(s[i]) and $F)/f;
      inc(i);
     end;

    //assert i>l
    Result:=EncodeDate(dy,dm,dd)+EncodeTime(th,tm,ts,tz)+Result;
   end
  else
    Result:=0;//Now?
end;

function TPostgresCommand.GetInterval(const Idx: Variant): TDateTime;
var
  i,dd,l,f:integer;
  th,tm,ts,tz:word;
  s:UTF8String;
  function Next:word;
  begin
    Result:=0;
    while (i<=l) and (s[i] in ['0'..'9']) do
     begin
      Result:=Result*10+(byte(s[i]) and $F);
      inc(i);
     end;
  end;
begin
  if IsEOF then raise EQueryResultError.Create('Reading past EOF.');
  if VarIsNumeric(Idx) then i:=Idx else
   begin
    s:=UTF8String(VarToStr(Idx));
    i:=PQfnumber(FRecordSet,@s[1]);
   end;
  if i=-1 then
    raise EQueryResultError.Create('GetDate: Field not found: '+VarToStr(Idx));
  if PQgetisnull(FRecordSet,FTuple,i)=0 then
   begin
    s:=PQgetvalue(FRecordSet,FTuple,i);
    i:=1;
    l:=Length(s);
    dd:=Next;
    if s[i]=' ' then//' days '
     begin
      inc(i);
      if (i<=l) and (s[i]='d') then inc(i) else i:=l+1;
      if (i<=l) and (s[i]='a') then inc(i) else i:=l+1;
      if (i<=l) and (s[i]='y') then inc(i) else i:=l+1;
      if (i<=l) and (s[i]='s') then inc(i) else i:=l+1;
      if (i<=l) and (s[i]=' ') then inc(i) else i:=l+1;
      th:=Next;
     end
    else
     begin
      th:=dd;
      dd:=0;
     end;
    while th>=24 do
     begin
      inc(dd);
      dec(th,24);
     end;
    inc(i);//':';
    tm:=Next;
    inc(i);//':'
    ts:=Next;
    inc(i);//'.'
    tz:=0;//Next;//more precision than milliseconds here, encode floating:

    f:=24*60*60;
    Result:=0.0;
    while (i<=l) and (s[i] in ['0'..'9']) do
     begin
      f:=f*10;
      Result:=Result+(byte(s[i]) and $F)/f;
      inc(i);
     end;

    //assert i>l
    Result:=dd+EncodeTime(th,tm,ts,tz)+Result;
   end
  else
    Result:=0;
end;

function TPostgresCommand.GetValue(Idx: Variant): Variant;
var
  i:integer;
  s:UTF8String;
  ods:char;
  rds:PChar;
begin
  if IsEOF then raise EQueryResultError.Create('Reading past EOF.');
  rds:=@{$IF Declared(FormatSettings)}FormatSettings.{$IFEND}DecimalSeparator;
  if VarIsNumeric(Idx) then i:=Idx else
   begin
    s:=UTF8String(VarToStr(Idx));
    i:=PQfnumber(FRecordSet,@s[1]);
   end;
  if i=-1 then
    raise EQueryResultError.Create('Field not found: '+VarToStr(Idx));
  if PQgetisnull(FRecordSet,FTuple,i)=0 then
   begin
    s:=PQgetvalue(FRecordSet,FTuple,i);
    case PQftype(FRecordset,i) of
      Oid_bool:Result:=s='t';
      //Oid_bytea
      Oid_int8:Result:=StrToInt64(string(s));
      Oid_int2:Result:=Word(StrToInt(string(s)));
      Oid_int4:Result:=StrToInt(string(s));
      {
      Oid_xml:
       begin
        d:=CreateComObject(CLASS_DOMDocument60) as DOMDocument60;
        d.async:=false;
        d.preserveWhiteSpace:=true;//?
        if not d.loadXML(UTF8ToWideString(s)) then
           raise EQueryResultError.Create('Field holds invalid XML: '+VarToStr(Idx)+' '+d.parseError.reason);
        Result:=d;
       end;
      }
      Oid_float4,Oid_float8,Oid_numeric:
       begin
        ods:=rds^;
        rds^:='.';
        try
          Result:=StrToFloat(string(s));
        finally
          rds^:=ods;
        end;
       end;
      Oid_money:
       begin
        ods:=rds^;
        rds^:='.';
        try
          Result:=StrToCurr(string(s));
        finally
          rds^:=ods;
        end;
       end;
      Oid_bpchar,Oid_varchar,Oid_text:Result:=UTF8ToWideString(s);
      //Oid_date
      //Oid_time
      Oid_timestamp:Result:=GetDate(Idx);
      Oid_interval:Result:=GetInterval(Idx);
      //Oid_timestamptz
      //Oid_uuid
      else
        raise EQueryResultError.Create('Unsupported result type oid='+
          IntToStr(PQftype(FRecordset,i))+': '+VarToStr(Idx));
    end;
   end
  else
    Result:=Null;
end;

function TPostgresCommand.IsNull(const Idx: Variant): boolean;
var
  i:integer;
  s:UTF8String;
begin
  if IsEOF then raise EQueryResultError.Create('Reading past EOF.');
  if VarIsNumeric(Idx) then i:=Idx else
   begin
    s:=UTF8String(VarToStr(Idx));
    i:=PQfnumber(FRecordSet,@s[1]);
   end;
  if i=-1 then
    raise EQueryResultError.Create('IsNull: Field not found: '+VarToStr(Idx));
  Result:=PQgetisnull(FRecordSet,FTuple,i)<>0;
end;

function TPostgresCommand.IsEof: boolean;
begin
  Result:=(FRecordSet.Handle=nil) or (PQntuples(FRecordSet)=FTuple);
end;

function TPostgresCommand.GetCount: integer;
begin
  if FRecordSet.Handle=nil then Result:=-1 else Result:=PQntuples(FRecordSet);
end;

initialization
  //something fixed invalid, see function RefCursor
  RefCursorCatch:=VarArrayCreate([0,0],varError);
end.
