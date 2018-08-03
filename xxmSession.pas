unit xxmSession;

interface

uses xxm, Classes, DataLank;

const
  PublicURL='http://yoy.be/home/feeder/';

type
  TXxmSession=class(TObject)
  private
    FID,FKey:WideString;
  public

    Name:AnsiString;
    UserID:integer;
    TimeBias:TDateTime;

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

uses SysUtils, Windows, sha3, base64, fCommon;

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
  i,tz:integer;
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
          ,'created',UtcNow
          ],'id');
       end
      else
       begin
        s.UserID:=qr.GetInt('id');
        if qr.GetStr('name')<>Name then
         begin
          db.Execute('update User set name=? where id=?',[Name,s.UserID]);
          s.Name:=Name;
         end;
        if qr.GetStr('email')<>Email then
         begin
          db.Execute('update User set email=? where id=?',[Email,s.UserID]);
          //?:=Email;
         end;
        //TODO: central LoadUser(qr)
        tz:=qr.GetInt('timezone');
        s.TimeBias:=(tz div 100)/24.0+(tz mod 100)/1440.0;
       end;
    finally
      qr.Free;
    end;
   end
  else
    raise Exception.Create('No session with that key "'+Key+'", please retry.');
end;

{ TxxmSession }

constructor TXxmSession.Create(const ID: WideString; Context: IXxmContext);
var
  qr:TQueryResult;
  s:string;
  tz:integer;
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
  TimeBias:=0.0;

  s:=Context.Cookie['feederAutoLogon'];
  if s<>'' then
   begin
    Connection.BeginTrans;
    try
      //TODO: more checks? hash user-agent?
      qr:=TQueryResult.Create(Connection,'select U.*, L.id as LogonID from UserLogon L inner join User U on U.id=L.user_id where L.key=?',[s]);
      try
        if qr.Read then
         begin
          UserID:=qr.GetInt('id');
          Name:=qr.GetStr('name');
          //:=qr.GetStr('email');?
          tz:=qr.GetInt('timezone');
          TimeBias:=(tz div 100)/24.0+(tz mod 100)/1440.0;
          Connection.Execute('update UserLogon set last=?,address=?,useragent=? where id=?',
            [UtcNow
            ,Context.ContextString(csRemoteAddress)
            ,Context.ContextString(csUserAgent)
            ,qr.GetInt('LogonID')]);
         end;
      finally
        qr.Free;
      end;
      Connection.CommitTrans;
    except
      Connection.RollbackTrans;
      raise;
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
