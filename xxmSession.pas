unit xxmSession;

interface

uses xxm, Classes, DataLank;

type
  TXxmSession=class(TObject)
  private
    FID,FKey:WideString;
  public

    Name:AnsiString;
    UserID:integer;

    constructor Create(const ID: WideString; Context: IXxmContext);

    //CSRF protection by posting session cookie value
    function FormProtect:WideString;
    procedure CheckProtect(Context: IXxmContext);

    property ID:WideString read FID;
    property Key:WideString read FKey;

    class function Connection: TDataConnection;
  end;

procedure SetSession(Context: IXxmContext);
procedure AbandonSession;

procedure AuthSession(const Key,Login,Name,Email:WideString);

threadvar
  Session: TXxmSession;

implementation

uses SysUtils, Windows, sha3, base64;

var
  SessionStore:TStringList;

procedure SetSession(Context: IXxmContext);
var
  i:integer;
  sid:WideString;
begin
  if SessionStore=nil then
   begin
    SessionStore:=TStringList.Create;
    SessionStore.Sorted:=true;
    SessionStore.CaseSensitive:=true;
    //SessionStore.Duplicates:=dupError;
   end;
  sid:=Context.SessionID+
    '|'+Context.ContextString(csUserAgent);//TODO: hash
  //TODO: more ways to prevent session hijacking?
  i:=SessionStore.IndexOf(sid);
  //TODO: session expiry!!!
  if (i<>-1) then Session:=SessionStore.Objects[i] as TXxmSession else
   begin
    //as a security measure, disallow  new sessions on a first POST request
    if Context.ContextString(csVerb)='POST' then
      raise Exception.Create('Access denied.');
    Session:=TXxmSession.Create(sid,Context);
    SessionStore.AddObject(sid,Session);
   end;
end;

//call AbandonSession to release session data (e.g. logoff)
procedure AbandonSession;
begin
  SessionStore.Delete(SessionStore.IndexOf(Session.ID));
  FreeAndNil(Session);
end;

procedure AuthSession(const Key,Login,Name,Email:WideString);
var
  i:integer;
  db:TDataConnection;
  qr:TQueryResult;
  s:TXxmSession;
begin
  if SessionStore=nil then
    raise Exception.Create('No sessions to authenticate');
  i:=0;
  while (i<SessionStore.Count) and ((SessionStore.Objects[i] as TXxmSession).Key<>Key) do inc(i);
  if i<SessionStore.Count then
   begin
    s:=SessionStore.Objects[i] as TXxmSession;
    db:=TXxmSession.Connection;
    qr:=TQueryResult.Create(db,'select * from User where login=?',[Login]);
    try
      if qr.EOF then
       begin
        s.UserID:=db.Insert('User',
          ['login',Login
          ,'name',Name
          ,'email',Email
          ,'created',Now
          ],'id');
       end
      else
       begin
        s.UserID:=qr.GetInt('id');
        if qr.GetStr('name')<>Name then
          db.Execute('update User set name=? where id=?',[Name,s.UserID]);
        if qr.GetStr('email')<>Email then
          db.Execute('update User set email=? where id=?',[Email,s.UserID]);
       end;
    finally
      qr.Free;
    end;
   end
  else
    raise Exception.Create('No session with that key "'+Key+'"');
end;

{ TxxmSession }

constructor TXxmSession.Create(const ID: WideString; Context: IXxmContext);
var
  qr:TQueryResult;
  s:string;
begin
  inherited Create;
  FID:=ID;
  FKey:=base64encode(SHA3_224(Format('[feeder]%d:%d:%d:%d:%d[%s]',
    [GetTickCount
    ,GetCurrentThreadID
    ,GetCurrentProcessID
    ,integer(pointer(Self))
    ,integer(pointer(Context))
    ,ID
    ])));
  //TODO: initiate expiry

  //default values
  Name:='';
  UserID:=0;

  s:=Context.Cookie['feederAutoLogon'];
  if s<>'' then
   begin
    qr:=TQueryResult.Create(Connection,'select * from User where autologon=?',[s]);
    try
      //TODO: more checks? hash user-agent?
      if qr.Read then
       begin
        Name:=qr.GetStr('name');
        UserID:=qr.GetInt('id');
       end;
    finally
      qr.Free;
    end;
   end;

end;

function TXxmSession.FormProtect:WideString;
begin
  Result:='<input type="hidden" name="XxmSessionID" value="'+HTMLEncode(FID)+'" />';
end;

procedure TXxmSession.CheckProtect(Context: IXxmContext);
var
  p:IXxmParameter;
  pp:IXxmParameterPost;
begin
  if Context.ContextString(csVerb)='POST' then
   begin
    p:=Context.Parameter['XxmSessionID'];
    if not((p.QueryInterface(IxxmParameterPost,pp)=S_OK) and (p.Value=FID)) then
      raise Exception.Create('Invalid POST source detected.');
   end
  else
    raise Exception.Create('xxmSession.CheckProtect only works on POST requests.');
end;

threadvar
  WorkerThreadConnection: TDataConnection;

class function TXxmSession.Connection: TDataConnection;
var
  s:string;
begin
  if WorkerThreadConnection=nil then
   begin
    SetLength(s,MAX_PATH);
    SetLength(s,GetModuleFileName(HInstance,PChar(s),MAX_PATH));
    WorkerThreadConnection:=TDataConnection.Create(ExtractFilePath(s)+'feeder.db');//TODO: from ini
    WorkerThreadConnection.BusyTimeout:=30000;
   end;
  Result:=WorkerThreadConnection;
end;

initialization
  SessionStore:=nil;//see SetSession
finalization
  FreeAndNil(SessionStore);

end.
