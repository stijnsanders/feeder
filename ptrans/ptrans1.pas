unit ptrans1;

interface

procedure DoTrans;

implementation

uses SysUtils, SQLiteData, LibPQData, Classes;

procedure DoTrans;
var
  db1:TPostgresConnection;
  db2:TSQLiteConnection;
  sl:TStringList;

  qr:TPostgresCommand;
  id,id1,c:integer;
begin
  sl:=TStringList.Create;
  sl.LoadFromFile('feeder.ini');
  db1:=TPostgresConnection.Create(sl.Text);
  sl.Free;
  db2:=TSQLiteConnection.Create('..\..\..\feeder.db');

  db1.BeginTrans;

  id1:=0;
  c:=0;
  qr:=TPostgresCommand.Create(db1,'select * from "Feed" order by id',[]);
  while qr.Read do
   begin
    id:=qr.GetInt('id');
    if id1<id then id1:=id;
    Write(#13'Feed:'+IntToStr(id));
    db2.Insert('Feed',
      ['id',qr['id']
      ,'name',qr['name']
      ,'url',qr['url']
      ,'created',qr.GetDate('created')
      ,'flags',qr['flags']
      ,'loadlast',qr.GetDate('loadlast')
      ,'result',qr['result']
      ,'loadcount',qr['loadcount']
      ,'itemcount',qr['itemcount']
      ,'regime',qr['regime']
      ]);
    inc(c);
   end;
  Writeln(#13'Feeds:'+IntToStr(c));

  db1.CommitTrans;
  db1.BeginTrans;

  id1:=0;
  c:=0;
  qr:=TPostgresCommand.Create(db1,'select * from "Post" order by id',[]);
  while qr.Read do
   begin
    id:=qr.GetInt('id');
    if id1<id then id1:=id;
    Write(#13'Post:'+IntToStr(id));
    db2.Insert('Post',
      ['id',qr['id']
      ,'feed_id',qr['feed_id']
      ,'guid',qr['guid']
      ,'title',qr['title']
      ,'content',qr['content']
      ,'url',qr['url']
      ,'pubdate',qr.GetDate('pubdate')
      ,'created',qr.GetDate('created')
      ]);
    inc(c);
   end;
  Writeln(#13'Posts:'+IntToStr(c));

  db1.CommitTrans;
  db1.BeginTrans;

  id1:=0;
  c:=0;
  qr:=TPostgresCommand.Create(db1,'select * from "User" order by id',[]);
  while qr.Read do
   begin
    id:=qr.GetInt('id');
    if id1<id then id1:=id;
    Write(#13'User:'+IntToStr(id));
    db2.Insert('User',
      ['id',qr['id']
      ,'login',qr['login']
      ,'name',qr['name']
      ,'email',qr['email']
      ,'timezone',qr['timezone']
      ,'created',qr.GetDate('created')
      ]);
    inc(c);
   end;
  Writeln(#13'Users:'+IntToStr(c));

  id1:=0;
  c:=0;
  qr:=TPostgresCommand.Create(db1,'select * from "UserLogon" order by id',[]);
  while qr.Read do
   begin
    id:=qr.GetInt('id');
    if id1<id then id1:=id;
    Write(#13'UserLogon:'+IntToStr(id));
    db2.Insert('UserLogon',
      ['id',qr['id']
      ,'user_id',qr['user_id']
      ,'key',qr['key']
      ,'created',qr.GetDate('created')
      ,'last',qr.GetDate('last')
      ,'address',qr['address']
      ,'useragent',qr['useragent']
      ]);
    inc(c);
   end;
  Writeln(#13'UserLogons:'+IntToStr(c));

  id1:=0;
  c:=0;
  qr:=TPostgresCommand.Create(db1,'select * from "Subscription" order by id',[]);
  while qr.Read do
   begin
    id:=qr.GetInt('id');
    if id1<id then id1:=id;
    Write(#13'Subscription:'+IntToStr(id));
    db2.Insert('Subscription',
      ['id',qr['id']
      ,'user_id',qr['user_id']
      ,'feed_id',qr['feed_id']
      ,'label',qr['label']
      ,'category',qr['category']
      ,'color',qr['color']
      ,'readwidth',qr['readwidth']
      ,'created',qr.GetDate('created')
      ]);
    inc(c);
   end;
  Writeln(#13'Subscriptions:'+IntToStr(c));

  id1:=0;
  c:=0;
  qr:=TPostgresCommand.Create(db1,'select * from "UserPost" order by id',[]);
  while qr.Read do
   begin
    id:=qr.GetInt('id');
    if id1<id then id1:=id;
    Write(#13'UserPost:'+IntToStr(id));
    db2.Insert('UserPost',
      ['id',qr['id']
      ,'user_id',qr['user_id']
      ,'post_id',qr['post_id']
      ]);
    inc(c);
   end;
  Writeln(#13'UserPosts:'+IntToStr(c));

  db1.CommitTrans;

end;

end.
