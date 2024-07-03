unit feedJSON;

interface

uses eaterReg, jsonDoc;

type
  TJsonFeedProcessor=class(TFeedProcessor)
  public
    function Determine(Store:IFeedStore;const FeedURL:WideString;
      var FeedData:WideString;const FeedDataType:WideString):boolean; override;
    procedure ProcessFeed(Handler: IFeedHandler; const FeedData: WideString);
      override;
  end;

  TJsonDataProcessor=class(TFeedProcessor)
  private
    FURL:string;
    FParseData:IJSONDocument;
    function f(d:IJSONDocument;const n:WideString):Variant;
  public
    function Determine(Store:IFeedStore;const FeedURL:WideString;
      var FeedData:WideString;const FeedDataType:WideString):boolean; override;
    procedure ProcessFeed(Handler: IFeedHandler; const FeedData: WideString);
      override;
  end;

implementation

uses SysUtils, Classes, Variants, ComObj, ActiveX, eaterUtils, MSXML2_TLB,
  eaterSanitize;

{ Base64* }

const
  Base64Codes:array[0..63] of AnsiChar=
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

function Base64Encode(const x:UTF8String):UTF8String;
var
  i,j,l:cardinal;
begin
  l:=Length(x);
  i:=(l div 3);
  if (l mod 3)<>0 then inc(i);
  SetLength(Result,i*4);
  i:=1;
  j:=0;
  while (i+2<=l) do
   begin
    inc(j);Result[j]:=Base64Codes[  byte(x[i  ]) shr 2];
    inc(j);Result[j]:=Base64Codes[((byte(x[i  ]) and $03) shl 4)
                                or (byte(x[i+1]) shr 4)];
    inc(j);Result[j]:=Base64Codes[((byte(x[i+1]) and $0F) shl 2)
                                or (byte(x[i+2]) shr 6)];
    inc(j);Result[j]:=Base64Codes[  byte(x[i+2]) and $3F];
    inc(i,3);
   end;
  if i=l then
   begin
    inc(j);Result[j]:=Base64Codes[  byte(x[i  ]) shr 2];
    inc(j);Result[j]:=Base64Codes[((byte(x[i  ]) and $03) shl 4)];
    inc(j);Result[j]:='=';
    inc(j);Result[j]:='=';
   end
  else if i+1=l then
   begin
    inc(j);Result[j]:=Base64Codes[  byte(x[i  ]) shr 2];
    inc(j);Result[j]:=Base64Codes[((byte(x[i  ]) and $03) shl 4)
                                or (byte(x[i+1]) shr 4)];
    inc(j);Result[j]:=Base64Codes[((byte(x[i+1]) and $0F) shl 2)];
    inc(j);Result[j]:='=';
   end;
end;

function Base64EncodeStream_JPEG(const s:IStream):UTF8String;
var
  d:UTF8String;
  i,j:integer;
  l:FixedUInt;
begin
  i:=1;
  j:=0;
  l:=1;
  while l<>0 do
   begin
    inc(j,$10000);
    SetLength(d,j);
    OleCheck(s.Read(@d[i],$10000,@l));
    inc(i,l);
   end;
  SetLength(d,i-1);
  Result:=Base64Encode(d);
end;

{ TJsonFeedProcessor }

function TJsonFeedProcessor.Determine(Store:IFeedStore;const FeedURL:WideString;
      var FeedData:WideString;const FeedDataType:WideString):boolean;
begin
  Result:=FeedDataType='application/json';
  //TODO: check content for "item":[{...?
end;

procedure TJsonFeedProcessor.ProcessFeed(Handler: IFeedHandler;
  const FeedData: WideString);
var
  jnodes:IJSONDocArray;
  jdoc,jn0,jn1:IJSONDocument;
  feedname,itemid,itemurl:string;
  title,content:WideString;
  pubDate:TDateTime;
  i,j,n1,n2:integer;
  v,v1:Variant;
begin
  jnodes:=JSONDocArray;
  jdoc:=JSON(['items',jnodes]);
  if (FeedData<>'') and (FeedData[1]='[') then
    jdoc.Parse('{"items":'+FeedData+'}')
  else
    jdoc.Parse(FeedData);
  //if jdoc['version']='https://jsonfeed.org/version/1' then
  if feedname='News' then feedname:=VarToStr(jdoc['description']);//NPR?
  if Length(feedname)>200 then feedname:=Copy(feedname,1,197)+'...';
  Handler.UpdateFeedName(feedname);
  //jdoc['home_page_url']?
  //jdoc['feed_url']?
  jn0:=JSON;
  for i:=0 to jnodes.Count-1 do
   begin
    jnodes.LoadItem(i,jn0);
    itemid:=VarToStr(jn0['id']);
    itemurl:=VarToStr(jn0['url']);
    if itemurl='' then itemurl:=VarToStr(jn0['externalUrl']);
    try
      jn1:=JSON(jn0['articleDates']);//'onTimeDate'?
      if jn1=nil then
        pubDate:=ConvDate1(VarToStr(jn0['date_published']))
      else
        pubDate:=ConvDate1(VarToStr(jn1['publicationDate']));
    except
      pubDate:=UtcNow;
    end;
    if Handler.CheckNewPost(itemid,itemurl,pubDate) then
     begin
      title:=VarToStr(jn0['title']);
      if VarIsNull(jn0['content_html']) then
        content:=HTMLEncode(VarToStr(jn0['content_text']))
      else
        content:=VarToStr(jn0['content_html']);
      if content='' then
        content:=HTMLEncode(VarToStr(jn0['content']));

      v:=jn0['tags'];
      if VarIsArray(v) and (VarArrayHighBound(v,1)>=VarArrayLowBound(v,1)) then
        if VarIsStr(v[0]) then
          Handler.PostTags('tag',jn0['tags'])
        else
         begin
          n1:=VarArrayLowBound(v,1);//0
          n2:=VarArrayHighBound(v,1);
          v1:=VarArrayCreate([n1,n2],varOleStr);
          for j:=n1 to n2 do
           begin
            jn1:=JSON(v[j]);
            v1[j]:=jn1['title'];
           end;
          Handler.PostTags('tag',v1);
         end;

      if not(VarIsNull(jn0['description'])) then
        content:='<div style="color:#666666;">'+HTMLEncode(jn0['description'])+'</div>'#13#10+content;

      //TODO: jn0['attachments']

      jn1:=JSON(jn0['author']);
      if jn1<>nil then
       begin
        content:='<div class="postcreator" style="padding:0.2em;float:right;color:silver;">'+
          HTMLEncode(jn1['name'])+'</div>'#13#10+content;
        //TODO: jn1['url']? jn1['avatar']?
       end;

      if not VarIsNull(jn0['image']) then
        content:='<img class="postthumb" referrerpolicy="no-referrer" src="'+
          HTMLEncode(jn0['image'])+'" /><br />'#13#10+content
      else
      if not VarIsNull(jn0['imageUrls']) then
        content:='<img class="postthumb" referrerpolicy="no-referrer" src="'+
          HTMLEncode('https:'+jn0['imageUrls'][0])+'" /><br />'#13#10+content;


      Handler.RegisterPost(title,content);
     end;
   end;
  Handler.ReportSuccess('JSONfeed');
end;

{ TJsonDataProcessor }

function TJsonDataProcessor.Determine(Store: IFeedStore;
  const FeedURL: WideString; var FeedData: WideString;
  const FeedDataType: WideString): boolean;
var
  i:integer;
  fn:string;
  sl:TStringList;
begin
  FParseData:=nil;//default
  Result:=false;//default

  if FeedDataType='application/json' then
   begin
    fn:='feeds/'+URLToFileName(string(FeedURL))+'.json';

    if FileExists(fn) then
     begin
      FParseData:=JSON;
      sl:=TStringList.Create;
      try
        sl.LoadFromFile(fn);
        FParseData.Parse(sl.Text);
      finally
        sl.Free;
      end;
      Result:=true;
     end
    else
      Result:=StartsWith(StripWhiteSpace(FeedData),'{"data":[');

    if Result then
     begin
      FURL:=FeedURL;
      i:=9;//Length('https://')+1;
      while (i<=Length(FURL)) and (FURL[i]<>'/') do inc(i);
      if (i<=Length(FURL)) and (FURL[i]='/') then
        SetLength(FURL,i-1);
     end;
   end;
end;

function TJsonDataProcessor.f(d:IJSONDocument;const n:WideString):Variant;
var
  i,l:integer;
  v:Variant;
  p:IJSONDocument;
begin
  v:=FParseData[n];
  //if VarIsNull(v)?
  if VarIsArray(v) then
   begin
    i:=VarArrayLowBound(v,1);
    l:=VarArrayHighBound(v,1);
    //assert i<=l
    Result:=Null;//default
    p:=nil;
    while i<=l do
     begin
      if p=nil then p:=d else p:=JSON(Result);
      Result:=p[v[i]];
      inc(i);
     end;
   end
  else
    Result:=d[v];
end;

procedure TJsonDataProcessor.ProcessFeed(Handler: IFeedHandler;
  const FeedData: WideString);
var
  jitems:IJSONDocArray;
  jdoc,j0,j1:IJSONDocument;
  itemid,itemurl,s:string;
  title,content:WideString;
  pubDate:TDateTime;
  i:integer;
  r:ServerXMLHTTP60;
begin
  if FParseData=nil then
   begin

    //TODO: convert into a parsedata JSON

    jitems:=JSONDocArray;
    jdoc:=JSON(['data',jitems]);
    jdoc.Parse(FeedData);
    //Handler.UpdateFeedName(?
    j0:=JSON;
    for i:=0 to jitems.Count-1 do
     begin
      jitems.LoadItem(i,j0);
      itemid:=j0['id'];
      itemurl:=FURL+j0['page_url'];
      try
        //s:=j0['public_at']?
        s:=j0['updated_at'];
        if s='' then s:=j0['created_at'];
        pubDate:=StrToInt64(s)/MSecsPerDay+UnixDateDelta;//UTC?
      except
        pubDate:=UtcNow;
      end;
      if Handler.CheckNewPost(itemid,itemurl,pubDate) then
       begin
        title:=VarToStr(j0['title']);
        content:=HTMLEncode(j0['description']);
        //if j0['breaking'] then title:=':fire:'+title;//?

        j1:=JSON(j0['categories']);
        if j1<>nil then Handler.PostTags('category',VarArrayOf([j1['name']]));

        j1:=JSON(j0['thumbnails']);
        if j1<>nil then
         begin
          {
          content:='<img class="postthumb" referrerpolicy="no-referrer'+
            '" src="'+HTMLEncodeQ(FURL+j1['middle'])+
            '" alt="'+HTMLEncodeQ(VarToStr(j1['alt']))+
            '" /><br />'#13#10+content;
          }

          s:=FURL+j1['middle'];
          r:=CoServerXMLHTTP60.Create;
          r.open('GET',s,false,EmptyParam,EmptyParam);
          r.send(EmptyParam);
          if r.status=200 then
            content:=
              '<img class="postthumb" src="data:image/jpeg;base64,'+
                UTF8ToWideString(Base64EncodeStream_JPEG(IUnknown(r.responseStream) as IStream))+
                '" alt="'+HTMLEncodeQ(VarToStr(j1['alt']))+
                '" /><br />'#13#10+
              content;
          //else <img?

          r:=nil;

         end;

        //'videos'?

        Handler.RegisterPost(title,content);
       end;
     end;
   end
  else
   begin
    jitems:=JSONDocArray;
    jdoc:=JSON([FParseData['list'],jitems]);
    jdoc.Parse(FeedData);
    if not(VarIsNull(FParseData['feedname'])) then
      Handler.UpdateFeedName(f(jdoc,'feedname'));
    j0:=JSON;
    for i:=0 to jitems.Count-1 do
     begin
      jitems.LoadItem(i,j0);
      itemid:=f(j0,'id');
      if VarIsNull(FParseData['url']) then
        itemurl:=FURL+f(j0,'relUrl')
      else
        itemurl:=f(j0,'url');
      try
        //TODO: more?
        pubDate:=ConvDate1(f(j0,'pubDate'));
      except
        pubDate:=UtcNow;
      end;
      if Handler.CheckNewPost(itemid,itemurl,pubDate) then
       begin
        title:=SanitizeTitle(f(j0,'title'));
        content:=f(j0,'content');
        if FParseData['contentHtmlEncode']=true then
          content:=HTMLEncode(content);
        if not(VarIsNull(FParseData['postthumb'])) then
         begin
          if VarIsNull(FParseData['postthumbalt']) then
            s:=''
          else
            s:=f(j0,'postthumbalt');
          content:='<img class="postthumb" referrerpolicy="no-referrer" src="'+
            HTMLEncode(f(j0,'postthumb'))+'" alt="'+
            HTMLEncode(s)+'" /><br />'#13#10+content;
         end;
        //TODO: categories
        //TODO: author
        Handler.RegisterPost(title,content);
       end;
     end;
   end;
  Handler.ReportSuccess('JSONdata');
end;

initialization
  RegisterFeedProcessor(TJsonDataProcessor.Create);
  RegisterFeedProcessor(TJsonFeedProcessor.Create);
end.
