unit feedInstagram;

interface

uses eaterReg;

type
  TInstagramFeedProcessor=class(TFeedProcessor)
  public
    function Determine(Store:IFeedStore;const FeedURL:WideString;
      var FeedData:WideString;const FeedDataType:WideString):boolean; override;
    procedure ProcessFeed(Handler:IFeedHandler;const FeedData:WideString); override;
  end;

implementation

uses Windows, SysUtils, ComObj, ActiveX, Variants, jsonDoc, MSXML2_TLB,
  eaterUtils, eaterSanitize, VBScript_RegExp_55_TLB;

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

function ImageDataURL(const ImgURL:string):string;
var
  r:ServerXMLHTTP60;
begin
  r:=CoServerXMLHTTP60.Create;
  r.open('GET',ImgURL,false,EmptyParam,EmptyParam);
  r.send(EmptyParam);
  //if r.status<>200 then raise?
  Result:='data:image/jpeg;base64,'+
    UTF8ToWideString(Base64EncodeStream_JPEG(IUnknown(r.responseStream) as IStream));
end;

{ TInstagramFeedProcessor }

function TInstagramFeedProcessor.Determine(Store:IFeedStore;const FeedURL:WideString;
      var FeedData:WideString;const FeedDataType:WideString):boolean;
begin
  //see also feed load: FFeed.LastMod='profile_id:'+
  Result:=(StartsWith(FeedURL,'https://www.instagram.com/') or
    StartsWith(FeedURL,'https://instagram.com/'));
  //assert FeedDataType='application/json'
end;

procedure TInstagramFeedProcessor.ProcessFeed(Handler: IFeedHandler;
  const FeedData: WideString);
var
  jnodes,jcaption,jthumbs,jlinks,jchildren:IJSONDocArray;
  jdoc,jdoc1,jd1,jn0,jn1,jc0,jc1:IJSONDocument;
  i,j:integer;
  itemid,itemurl,s:string;
  pubDate:TDateTime;
  title,content:WideString;
  r1,r2:RegExp;
begin
  jnodes:=JSONDocArray;
  jdoc:=JSON(['user{'
    ,'edge_felix_video_timeline{','edges',jnodes,'}'
    ,'edge_owner_to_timeline_media{','edges',jnodes,'}'
    ,'edge_saved_media{','edges',jnodes,'}'
    ,'edge_media_collections{','edges',jnodes,'}'
    ]);

  jdoc1:=JSON(['data',jdoc]);
  try
    jdoc1.Parse(FeedData);
  except
    on EJSONDecodeException do
      ;//ignore "data past end"
  end;

  jcaption:=JSONDocArray;
  jthumbs:=JSONDocArray;
  jlinks:=JSONDocArray;
  jchildren:=JSONDocArray;
  jn1:=JSON(
    ['edge_media_to_caption{','edges',jcaption,'}'
    ,'edge_media_to_tagged_user{','edges',jlinks,'}'
    ,'edge_sidecar_to_children{','edges',jchildren,'}'
    ,'thumbnail_resources',jthumbs]);
  jn0:=JSON(['node',jn1]);
  jc1:=JSON();
  jc0:=JSON(['node',jc1]);

  r1:=CoRegExp.Create;
  r1.Pattern:='@([^@#]+?)\b';
  r1.Global:=true;
  r2:=CoRegExp.Create;
  r2.Pattern:='#([^@#]+?)\b';
  r2.Global:=true;

  for i:=0 to jnodes.Count-1 do
   begin
    jnodes.LoadItem(i,jn0);

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
    //TODO: SanitizeTitle?

    if Handler.CheckNewPost(itemid,itemurl,pubdate) then
     begin
      content:=r1.Replace(r2.Replace(HTMLEncode(content)
        ,'<a href="https://instagram.com/explore/tags/$1/">#$1</a>')
        ,'<a href="https://instagram.com/$1/">@$1</a>');
      //if jn1['is_video']=true then content:=#$25B6+content;
      if jn1['is_video']=true then title:=#$25B6+title;

      if jthumbs.Count=0 then s:='' else
        s:=VarToStr(JSON(jthumbs.GetJSON(jthumbs.Count-1))['src']);
      if s='' then s:=VarToStr(jn1['thumbnail_src']);
      if s='' then s:=VarToStr(jn1['display_url']);

      if s<>'' then
       begin
        content:='<a href="'+HTMLEncodeQ(itemurl)+'"><img id="ig1" src="'
          +ImageDataURL(s)+'" border="0" /></a><br />'#13#10
          +content;
       end;

      jd1:=JSON(jn1['location']);
      if jd1<>nil then
        content:='<i>'+HTMLEncode(jd1['name'])+'</i><br />'#13#10+content;

      content:='<p>'+content+'</p>'#13#10;

      if jchildren.Count<>0 then
       begin
{
        content:=content+'<script>'#13#10
          +'var ig1=document.getElementById("id1");'#13#10
          +'</script>'#13#10
          +'<p>';
        for j:=0 to jchildren.Count-1 do
         begin
          jchildren.LoadItem(j,jc0);
          if jc1['is_video']=true then s:=#$25BA else s:=#$25A0;
          content:=content+'<span onclick="ig1.src='''+HTMLEncode(jc1['display_url'])+''';">'+s+'</span> ';
         end;
        content:=content+'</p>'#13#10;
}
        content:=content+'<p>+'+IntToStr(jchildren.Count)+'</p>'#13#10;
       end;


      //TODO: likes, views, owner?

      if jlinks.Count<>0 then
       begin
        content:=content+'<p class="igLinks">'#13#10;
        for j:=0 to jlinks.Count-1 do
         begin
          jlinks.LoadItem(j,jc0);
          jd1:=JSON(jc1['user']);
          content:=content+'<a href="https://instagram.com/'+jd1['username']
            +'/" title="'+HTMLEncodeQ(jd1['full_name'])
            +'"><img src="'+ImageDataURL(jd1['profile_pic_url'])
            +'" alt="'+HTMLEncodeQ(jd1['full_name'])
            +'" referrerpolicy="no-referrer" border="0" /></a>'#13#10;
         end;
        content:=content+'</p>'#13#10;
       end;

SaveUTF16('D:\Data\2021\feeder\eater\xmls\test.html',content);

      Handler.RegisterPost(title,content);
     end;

   end;
  Handler.ReportSuccess('Instagram');
end;

initialization
  RegisterFeedProcessor(TInstagramFeedProcessor.Create);
end.
