unit feedWPv2;

interface

uses eaterReg;

type
  TWPv2FeedProcessor=class(TFeedProcessor)
  public
    function Determine(Store:IFeedStore;const FeedURL:WideString;
      var FeedData:WideString;const FeedDataType:WideString):boolean; override;
    procedure ProcessFeed(Handler: IFeedHandler; const FeedData: WideString);
      override;
  end;

implementation

uses SysUtils, eaterSanitize, jsonDoc, Variants, eaterUtils, MSXML2_TLB;

{ TWPv2FeedProcessor }

function TWPv2FeedProcessor.Determine(Store:IFeedStore;const FeedURL:WideString;
      var FeedData:WideString;const FeedDataType:WideString):boolean;
var
  i,l:integer;
begin
  Result:=false;//default
  if (FeedDataType='application/json') and (Pos(WideString('/wp/v2/'),FeedURL)<>0) then
   begin
    i:=1;
    l:=Length(FeedData);
    while (i<=l) and (FeedData[i]<' ') do inc(i);
    Result:=(i<=l) and (FeedData[i]='[');
    //'[{"id":'?
   end;
end;

procedure TWPv2FeedProcessor.ProcessFeed(Handler: IFeedHandler;
  const FeedData: WideString);
var
  jnodes,jmedia,jl1:IJSONDocArray;
  jdoc,jn0,jn1:IJSONDocument;
  node_i,n:integer;
  itemid,itemurl,mediaurl,h1,h2:string;
  title,content,md:WideString;
  v:Variant;
  pubDate:TDateTime;
  r:ServerXMLHTTP60;
begin
  //TODO: if rw='[]' and '/wp/v2/posts' switch to '/wp/v2/articles'? episodes? media?
  jnodes:=JSONDocArray;
  jmedia:=JSONDocArray;
  jdoc:=JSON(['items',jnodes]);
  jdoc.Parse('{"items":'+FeedData+'}');
  jn0:=JSON(['_links',JSON(['wp:featuredmedia',jmedia,'wp:attachment',jmedia  ])]);
  r:=nil;
  for node_i:=0 to jnodes.Count-1 do
   begin
    jnodes.LoadItem(node_i,jn0);
    itemid:=VarToStr(jn0['id']);//'slug'?
    if itemid='' then itemid:=VarToStr(JSON(jn0['guid'])['rendered']);
    itemurl:=VarToStr(jn0['link']);
    try
      v:=jn0['date_gmt'];
      if VarIsNull(v) then v:=jn0['date'];//modified(_gmt)?
      pubDate:=ConvDate1(VarToStr(v));
    except
      pubDate:=UtcNow;
    end;
    if Handler.CheckNewPost(itemid,itemurl,pubdate) then
     begin
      title:=VarToStr(JSON(jn0['title'])['rendered']);
      //'excerpt'?
      content:=VarToStr(JSON(jn0['content'])['rendered']);

      SanitizeWPImgData(content);

      if jmedia.Count<>0 then
       begin
        jn1:=JSON;
        jmedia.LoadItem(0,jn1);
        mediaurl:=VarToStr(jn1['href']);
        if mediaurl<>'' then
         begin
          if r=nil then r:=CoServerXMLHTTP60.Create;
          r.open('GET',mediaurl,false,EmptyParam,EmptyParam);
          r.send(EmptyParam);
          md:=r.responseText;
          if (r.status=200) and (md<>'') then
           begin
            n:=1;
            while (n<=Length(md)) and (md[n]<=' ') do inc(n);
            if md[n]='[' then
             begin
              jl1:=JSONDocArray;
              jn1:=JSON(['x',jl1]);
              jn1.Parse('{"x":'+md+'}');
              if jl1.Count<>0 then jn1:=JSON(jl1[0]) else jn1:=nil;
             end
            else
             begin
              jn1:=JSON;
              jn1.Parse(md);
             end;
            if jn1=nil then mediaurl:='' else mediaurl:=VarToStr(jn1['source_url']);
            if mediaurl<>'' then
             begin
              if Copy(content,1,3)='<p>' then h1:=#13#10 else h1:='<br />'#13#10;
              h2:='';
              jn1:=JSON(jn1['media_details']);
              if jn1<>nil then jn1:=JSON(jn1['image_meta']);
              if jn1<>nil then h2:=' alt="'+HTMLEncodeQ(VarToStr(jn1['caption']))+'"';
              content:='<img class="postthumb" referrerpolicy="no-referrer" src="'+
                HTMLEncodeQ(mediaurl)+'"'+h2+' />'+h1+content;
             end;
           end;
         end;
       end;

      Handler.RegisterPost(title,content);
     end;
   end;
  Handler.ReportSuccess('WPv2');
end;

initialization
  RegisterFeedProcessor(TWPv2FeedProcessor.Create);
end.
