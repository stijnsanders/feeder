unit eater1;

interface

uses SysUtils;

procedure DoUpdateFeeds;

//TODO: from ini
const
  FeederDBPath='..\feeder.db';
  OldPostsDays=732;

implementation

uses Classes, Windows, DataLank, MSXML2_TLB, Variants, VBScript_RegExp_55_TLB;

var
  OldPostsCutOff:TDateTime;
  SaveData:boolean;
  FeedID:integer;

function ConvDate1(const x:string):TDateTime;
var
  dy,dm,dd,th,tm,ts,tz:word;
  i,l:integer;
  procedure nx(var xx:word;yy:integer);
  var
    ii:integer;
  begin
    xx:=0;
    for ii:=0 to yy-1 do
      if (i<=l) and (x[i] in ['0'..'9']) then
       begin
        xx:=xx*10+(byte(x[i]) and $F);
        inc(i);
       end;
  end;
begin
  i:=1;
  l:=Length(x);
  nx(dy,4); inc(i);//':'
  nx(dm,2); inc(i);//':'
  nx(dd,2); inc(i);//'T'
  nx(th,2); inc(i);//':'
  nx(tm,2); inc(i);//':'
  nx(ts,2);
  tz:=0;
  //TODO: timezone
  Result:=EncodeDate(dy,dm,dd)+EncodeTime(th,tm,ts,tz);
end;

function ConvDate2(const x:string):TDateTime;
var
  dy,dm,dd,th,tm,ts,tz:word;
  i,l:integer;
  procedure nx(var xx:word;yy:integer);
  var
    ii:integer;
  begin
    xx:=0;
    for ii:=0 to yy-1 do
      if (i<=l) and (x[i] in ['0'..'9']) then
       begin
        xx:=xx*10+(byte(x[i]) and $F);
        inc(i);
       end;
  end;
begin
  i:=1;
  l:=Length(x);
  //TODO: timezone
  while (i<=l) and not(x[i] in ['0'..'9']) do inc(i);
  nx(dd,2);
  inc(i);//' '
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
  inc(i,4);
  nx(dy,4); inc(i);//' '
  nx(th,2); inc(i);//':'
  nx(tm,2); inc(i);//':'
  nx(ts,2);
  tz:=0;
  //TODO: timezone
  Result:=EncodeDate(dy,dm,dd)+EncodeTime(th,tm,ts,tz);
end;

var
  rh0,rh1,rh2,rh3,rh4,rh5,rh6,rh7:IRegExp2;

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
  rh6.Pattern:='&lt;(i|b|u|s|em|strong)&gt;(.+?)&lt;/\1&gt;';
  rh6.Global:=true;
  rh6.IgnoreCase;
  rh7:=CoRegExp.Create;
  rh7.Pattern:='&amp;(#x?[0-9a-f]+?|[0-9]+?);';
  rh7.Global:=true;
  rh7.IgnoreCase:=true;
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
end;

procedure DoFeed(db:TDataConnection;id:integer;const url:string);
var
  r:ServerXMLHTTP60;
  doc:DOMDocument60;
  xl,xl1:IXMLDOMNodeList;
  x,y:IXMLDOMElement;
  itemid,itemurl:string;
  title,content:WideString;
  pubDate:TDateTime;
  b:boolean;
  rc,c1,c2,pid:integer;
  procedure regItem;
  var
    qr:TQueryResult;
    b:boolean;
  begin
    if pubDate<OldPostsCutOff then b:=false else
     begin
      qr:=TQueryResult.Create(db,'select id from Post where feed_id=? and guid=?',[id,itemid]);
      try
        b:=qr.EOF;
      finally
        qr.Free;
      end;
     end;
    inc(c1);
    if b then
     begin
      inc(c2);
      pid:=db.Insert('Post',
        ['feed_id',id
        ,'guid',itemid
        ,'title',SanitizeTitle(title)
        ,'content',content
        ,'url',itemurl
        ,'pubdate',pubDate
        ,'created',Now
        ],'id');
      db.Execute('insert into UserPost (user_id,post_id)'+
        ' select S.user_id,? from Subscription S where S.feed_id=?',[pid,id]);
     end;
  end;
begin
  Write(IntToStr(id)+':'+url);

  r:=CoServerXMLHTTP60.Create;
  b:=true;
  rc:=0;
  itemurl:=url;
  while b do
   begin
    b:=false;
    r.open('GET',itemurl,false,EmptyParam,EmptyParam);
    r.setRequestHeader('Accept','application/rss+xml, application/atom+xml, application/xml, text/xml');
    r.setRequestHeader('Cache-Control','max-age=0');
    if Pos('tumblr.com',itemurl)<>0 then
     begin
      r.setRequestHeader('User-Agent','Mozilla/5.0 (Windows NT 10.0; Win64; x'+
        '64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.99 Safar'+
        'i/537.36');
      r.setRequestHeader('Cookie','_ga=GA1.2.23714421.1433010142; rxx=2kenj37'+
        'frug.zcwv3sm&v=1; __utma=189990958.23714421.1433010142.1515355375.15'+
        '15513281.39; tmgioct=5b490b2e517e660612702270; pfg=324066a0306b92f0b'+
        '5346487b1309edb56a909231a6bc33a78f47993e4b695ef%23%7B%22eu_resident%'+
        '22%3A1%2C%22gdpr_is_acceptable_age%22%3A1%2C%22gdpr_consent_core%22%'+
        '3A1%2C%22gdpr_consent_first_party_ads%22%3A1%2C%22gdpr_consent_third'+
        '_party_ads%22%3A1%2C%22gdpr_consent_search_history%22%3A1%2C%22exp%2'+
        '2%3A1563049750%2C%22vc%22%3A%22%22%7D%238216174849');
     end
    else
      r.setRequestHeader('User-Agent','FeedEater/1.0');
    r.send(EmptyParam);
    if r.status=301 then //moved permanently
     begin
      itemurl:=r.getResponseHeader('Location');
      b:=true;
      inc(rc);
      if rc=8 then
        raise Exception.Create('max redirects exceeded');
     end;
   end;
  if r.status<>200 then
    raise Exception.Create('HTTP:'+IntToStr(r.status)+' '+r.statusText);

  if itemurl<>url then
    db.Update('Feed',['id',id,'url',itemurl]);

  //doc:=r.responseXML as DOMDocument40;

  c1:=0;
  c2:=0;
  doc:=CoDOMDocument60.Create;
  doc.async:=false;
  doc.validateOnParse:=false;
  doc.resolveExternals:=false;

  //SaveFile(id,#$FE#$FF+r.responseText);

  if doc.loadXML(r.responseText) then
   begin
    if SaveData then
      doc.save('xmls\'+Format('%.4d',[id])+'.xml');

    db.BeginTrans;
    try

      //atom
      if doc.documentElement.nodeName='feed' then
       begin
        doc.setProperty('SelectionNamespaces','xmlns:atom=''http://www.w3.org/2005/Atom''');

        xl:=doc.documentElement.selectNodes('atom:entry');
        x:=xl.nextNode as IXMLDOMElement;
        while x<>nil do
         begin
          itemid:=x.selectSingleNode('atom:id').text;
          if Copy(itemid,1,4)='http' then
            itemurl:=itemid
          else
           begin
            xl1:=x.selectNodes('atom:link');
            y:=xl1.nextNode as IXMLDOMElement;
            if y=nil then
              itemurl:=itemid
            else
              itemurl:=y.getAttribute('href');//default
            while y<>nil do
             begin
              //'rel'?
              if y.getAttribute('type')='text/html' then
                itemurl:=y.getAttribute('href');
              y:=xl1.nextNode as IXMLDOMElement;
             end;
           end;
          title:=x.selectSingleNode('atom:title').text;
          y:=x.selectSingleNode('atom:content') as IXMLDOMElement;
          if y=nil then
            y:=x.selectSingleNode('atom:summary') as IXMLDOMElement;
          if y=nil then content:='' else content:=y.text;
          try
            y:=x.selectSingleNode('atom:updated') as IXMLDOMElement;
            if y=nil then
              y:=x.selectSingleNode('atom:published') as IXMLDOMElement;
            if y=nil then pubDate:=Now else pubDate:=ConvDate1(y.text);
          except
            pubDate:=Now;
          end;
          regItem;

          x:=xl.nextNode as IXMLDOMElement;
         end;
       end
      else

      //RSS
      if doc.documentElement.nodeName='rss' then
       begin
        doc.setProperty('SelectionNamespaces','xmlns:content="http://purl.org/rss/1.0/modules/content/"');

        xl:=doc.documentElement.selectNodes('channel/item');
        x:=xl.nextNode as IXMLDOMElement;
        while x<>nil do
         begin
          y:=x.selectSingleNode('guid') as IXMLDOMElement;
          if y=nil then y:=x.selectSingleNode('link') as IXMLDOMElement;
          itemid:=y.text;
          itemurl:=x.selectSingleNode('link').text;
          title:=x.selectSingleNode('title').text;
          y:=x.selectSingleNode('content:encoded') as IXMLDOMElement;
          if y=nil then
            y:=x.selectSingleNode('content') as IXMLDOMElement;
          if y=nil then
            y:=x.selectSingleNode('description') as IXMLDOMElement;
          if y=nil then content:='' else content:=y.text;
          try
            y:=x.selectSingleNode('pubDate') as IXMLDOMElement;
            if y=nil then pubDate:=Now else pubDate:=ConvDate2(y.text);
          except
            pubDate:=Now;
          end;
          regItem;

          x:=xl.nextNode as IXMLDOMElement;
         end;
       end
      else

      //RDF
      if doc.documentElement.nodeName='rdf:RDF' then
       begin
        doc.setProperty('SelectionNamespaces','xmlns:rss=''http://purl.org/rss/1.0/'''+
         ' xmlns:dc=''http://purl.org/dc/elements/1.1/''');

        xl:=doc.documentElement.selectNodes('rss:item');
        x:=xl.nextNode as IXMLDOMElement;
        while x<>nil do
         begin
          itemid:=x.getAttribute('rdf:about');
          itemurl:=x.selectSingleNode('rss:link').text;
          title:=x.selectSingleNode('rss:title').text;
          y:=x.selectSingleNode('rss:description') as IXMLDOMElement;
          if y=nil then content:='' else content:=y.text;
          try
            y:=x.selectSingleNode('rss:pubDate') as IXMLDOMElement;
            if y=nil then
             begin
              y:=x.selectSingleNode('dc:date') as IXMLDOMElement;
              if y=nil then pubDate:=Now else pubDate:=ConvDate1(y.text);
             end
            else pubDate:=ConvDate2(y.text);
          except
            pubDate:=Now;
          end;
          regItem;

          x:=xl.nextNode as IXMLDOMElement;
         end;
       end
      else

      //unknown
        ;//raise?

      db.CommitTrans;
    except
      db.RollbackTrans;
      raise;
    end;
    Writeln(Format(' [%d/%d]',[c2,c1]));

   end
  else
    Writeln(ErrOutput,'[XML:'+IntToStr(id)+']'+doc.parseError.Reason);
end;

procedure DoUpdateFeeds;
var
  db:TDataConnection;
  qr:TQueryResult;
  i,j:integer;
  s:string;
  w,w1:WideString;
begin
  SaveData:=false;
  FeedID:=0;

  for i:=1 to ParamCount do
   begin
    s:=ParamStr(i);
    if s='/s' then SaveData:=true
    else
    if Copy(s,1,2)='/f' then FeedID:=StrToInt(Copy(s,3,99))
    else
      raise Exception.Create('Unknown parameter #'+IntToStr(i));
   end;

  SanitizeInit; 
  db:=TDataConnection.Create(FeederDBPath);
  try
    db.BusyTimeout:=30000;

    db.BeginTrans;
    try

      Write('Clean-up old...');
      OldPostsCutOff:=Now-OldPostsDays;
      i:=db.Execute('delete from UserPost where post_id in (select id from Post where pubdate<?)',[OldPostsCutOff]);
      j:=db.Execute('delete from Post where pubdate<?',[OldPostsCutOff]);
      Writeln(Format(' [%d,%d]',[j,i]));

      Write('Clean-up unused...');
      db.Execute('delete from UserPost where post_id in (select P.id from Post P where P.feed_id in (select F.id from Feed F where not exists (select S.id from Subscription S where S.feed_id=F.id)))');
      j:=db.Execute('delete from Post where feed_id in (select F.id from Feed F where not exists (select S.id from Subscription S where S.feed_id=F.id))');
      i:=db.Execute('delete from Feed where not exists (select S.id from Subscription S where S.feed_id=Feed.id)');
      Writeln(Format(' [%d,%d]',[j,i]));

//TRANSITIONAL
if SaveData then
begin
      qr:=TQueryResult.Create(db,'select id, title from Post where title like ''%&%'' or title like ''%<%'' or title like ''%>%''');
      try
        while qr.Read do
         begin
          w1:=qr.GetStr('title');
          w:=SanitizeTitle(w1);
          if w<>w1 then
           begin
            i:=qr.GetInt('id');
            db.Execute('update Post set title=? where id=?',[w,i]);
            Writeln(Format('%d:%s',[i,w]));
           end;
         end;
      finally
        qr.Free;
      end;
end;

      db.CommitTrans;
    except
      db.RollbackTrans;
      raise;
    end;


    qr:=TQueryResult.Create(db,'select * from Feed where ? in (0,id)',[FeedID]);
    try
      while qr.Read do
        try
          DoFeed(db,qr.GetInt('id'),qr.GetStr('url'));
        except
          on e:Exception do
            Writeln(ErrOutput,'['+e.ClassName+']'+e.Message);
        end;
    finally
      qr.Free;
    end;

  finally
    db.Free;
  end;
end;

end.
