unit feedInstagram;

interface

uses eaterReg;

type
  TInstagramFeedProcessor=class(TFeedProcessor)
  private
    rt:WideString;
  public
    function Determine(Store:IFeedStore;const FeedURL:WideString;
      var FeedData:WideString;const FeedDataType:WideString):boolean; override;
    procedure ProcessFeed(Handler:IFeedHandler;const FeedData:WideString); override;
  end;

implementation

uses SysUtils, ComObj, ActiveX, eaterUtils, Variants, jsonDoc, MSXML2_TLB;

const
  Base64Codes:array[0..63] of AnsiChar=
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

  YoutubePrefix1='https://www.youtube.com/channel/';
  YoutubePrefix2='https://www.youtube.com/feeds/videos.xml?channel_id=';

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
  //p:TJPEGImage;
  //m:TMemoryStream;
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

  {
  m:=TMemoryStream.Create;
  try
    m.Write(d[1],Length(d));
    m.Position:=0;
    p:=TJPEGImage.Create;
    try
      p.LoadFromStream(m);
      p.DIBNeeded;

      //???
      p.CompressionQuality:=75;

      p.Compress;
      m.Size:=0;
      p.SaveToStream(m);
    finally
      p.Free;
    end;

    m.Position:=0;
    SetLength(d,m.Size);
    //Move(m.Memory^,d[1],m.Size);
    m.Read(d[1],m.Size);
  finally
    m.Free;
  end;
  }

  Result:=Base64Encode(d);
end;

{ TInstagramFeedProcessor }

function TInstagramFeedProcessor.Determine(Store:IFeedStore;const FeedURL:WideString;
      var FeedData:WideString;const FeedDataType:WideString):boolean;
begin
  rt:=FeedDataType;
  Result:=StartsWith(FeedURL,'https://www.instagram.com/');
end;

procedure TInstagramFeedProcessor.ProcessFeed(Handler: IFeedHandler;
  const FeedData: WideString);
var
  jnodes,jcaption,jthumbs:IJSONDocArray;
  jdoc,jdoc1,jd1,jn0,jn1,jc0,jc1:IJSONDocument;
  i,j,c:integer;
  itemid,itemurl,s:string;
  pubDate:TDateTime;
  title,content:WideString;
  r:ServerXMLHTTP60;
begin
  jnodes:=JSONDocArray;
  jdoc:=JSON(['user{'
    ,'edge_felix_video_timeline{','edges',jnodes,'}'
    ,'edge_owner_to_timeline_media{','edges',jnodes,'}'
    ,'edge_saved_media{','edges',jnodes,'}'
    ,'edge_media_collections{','edges',jnodes,'}'
    ]);

  c:=0;
  if rt='application/json' then
   begin

    jdoc1:=JSON(['graphql',jdoc]);
    try
      jdoc1.Parse(FeedData);
    except
      on EJSONDecodeException do
        ;//ignore "data past end"
    end;

    //if SaveData then
    //  SaveUTF16('xmls\'+Format('%.4d',[feedid])+'.json',jdoc.AsString);

    jd1:=JSON(jdoc['user']);
    if jd1<>nil then
      Handler.UpdateFeedName('Instagram: '+VarToStr(jd1['full_name'])+' (@'+VarToStr(jd1['username'])+')');

    jcaption:=JSONDocArray;
    jthumbs:=JSONDocArray;
    jn1:=JSON(['edge_media_to_caption{','edges',jcaption,'}','thumbnail_resources',jthumbs]);
    jn0:=JSON(['node',jn1]);
    jc1:=JSON();
    jc0:=JSON(['node',jc1]);
    for i:=0 to jnodes.Count-1 do
     begin
      jnodes.LoadItem(i,jn0);
      inc(c);

      itemid:=VarToStr(jn1['id']);
      if itemid='' then raise Exception.Create('edge node without ID');
      itemurl:='https://www.instagram.com/p/'+VarToStr(jn1['shortcode'])+'/';
      pubDate:=int64(jn1['taken_at_timestamp'])/SecsPerDay+UnixDateDelta;//is UTC?

      content:=VarToStr(jn1['title'])+' ';
      for j:=0 to jcaption.Count-1 do
       begin
        jcaption.LoadItem(j,jc0);
        content:=content+VarToStr(jc1['text'])+#13#10;
       end;

      if Length(content)<200 then title:=content else title:=Copy(content,1,99)+'...';

      if Handler.CheckNewPost(itemid,itemurl,pubdate) then
       begin
        content:=HTMLEncode(content);
        //if jn1['is_video']=true then content:=#$25B6+content;
        if jn1['is_video']=true then title:=#$25B6+title;

        if jthumbs.Count=0 then s:='' else
          s:=VarToStr(JSON(jthumbs.GetJSON(jthumbs.Count-1))['src']);
        if s='' then s:=VarToStr(jn1['thumbnail_src']);
        if s='' then s:=VarToStr(jn1['display_url']);

        if s<>'' then
         begin
          r:=CoServerXMLHTTP60.Create;
          r.open('GET',s,false,EmptyParam,EmptyParam);
          r.send(EmptyParam);
          //if r.status<>200 then raise?
          content:=
            '<a href="'+HTMLEncode(itemurl)+'"><img src="data:image/jpeg;base64,'+
              UTF8ToWideString(Base64EncodeStream_JPEG(IUnknown(r.responseStream) as IStream))+
              '" border="0" /></a><br />'#13#10+
            content;

          r:=nil;
         end;

        jd1:=JSON(jn1['location']);
        if jd1<>nil then
          content:='<i>'+HTMLEncode(jd1['name'])+'</i><br />'#13#10+content;

        //TODO: likes, views, owner?

        Handler.RegisterPost(title,content);
       end;

     end;
   end;

  if c=0 then //if rt<>'application/json'?
   begin
    {
    proxiesTC:=GetTickCount;
    inc(proxiesIndex);
    if proxiesIndex>=proxies.Count then
      InstagramBadTC:=GetTickCount
    else
      InstagramTC:=GetTickCount-InstagramTimeoutMS-InstagramTimeoutRandomPaddingMS;
    feedlastmod:='';
    feedresult:=Format('Instagram ? (s:%d, p:%d/%d)',
      [InstagramSuccess,proxiesIndex+1,proxies.Count]);
    }
    Handler.ReportFailure('Instagram ?');
   end
  else
   begin
    //inc(InstagramSuccess);
    Handler.ReportSuccess('Instagram');
   end;

end;

initialization
  RegisterFeedProcessor(TInstagramFeedProcessor.Create);
end.
