unit feedFusion;

interface

uses eaterReg;

type
  TFusionFeedProcessor=class(TFeedProcessor)
  public
    function Determine(Store: IFeedStore; const FeedURL: WideString;
      var FeedData: WideString; const FeedDataType: WideString): Boolean;
      override;
    procedure ProcessFeed(Handler: IFeedHandler; const FeedData: WideString);
      override;
  end;

implementation

uses eaterSanitize, jsonDoc, Variants, eaterUtils;

{ TFusionFeedProcessor }

function TFusionFeedProcessor.Determine(Store: IFeedStore;
  const FeedURL: WideString; var FeedData: WideString;
  const FeedDataType: WideString): Boolean;
begin
  Result:=Store.CheckLastLoadResultPrefix('Fusion') and
    FindPrefixAndCrop(FeedData,'Fusion.globalContent=');
end;

procedure TFusionFeedProcessor.ProcessFeed(Handler: IFeedHandler;
  const FeedData: WideString);
var
  jnodes:IJSONDocArray;
  jdoc,jd1,jn0,jn1:IJSONDocument;
  p1,p2,itemid,itemurl:string;
  pubDate:TDateTime;
  title,content:WideString;
  v:Variant;
  i:integer;
begin
  jnodes:=JSONDocArray;
  jd1:=JSON;
  jdoc:=JSON(
    ['result',JSON(['articles',jnodes,'section',jd1])
    ,'arcResult',JSON(['articles',jnodes])
    ,'sophiResult',JSON(['articles',jnodes])
    ]);
  try
    jdoc.Parse(FeedData);
  except
    on EJSONDecodeException do
      ;//ignore "data past end"
  end;
  Handler.UpdateFeedName(VarToStr(jd1['title']));
  jn0:=JSON;
  p1:='';
  p2:='';
  for i:=0 to jnodes.Count-1 do
   begin
    jnodes.LoadItem(i,jn0);

    itemid:=jn0['id'];
    itemurl:=jn0['canonical_url'];
    try
      pubDate:=ConvDate1(VarToStr(jn0['display_time']));//published_time?
    except
      pubDate:=UtcNow;
    end;
    title:=jn0['title'];
    v:=jn0['subtitle'];
    if not(VarIsNull(v)) then title:=title+' '#$2014' '+v;
    content:=HTMLEncode(jn0['description']);

    if Handler.CheckNewPost(itemid,itemurl,pubDate) then
     begin
      jn1:=JSON(jn0['thumbnail']);
      if jn1<>nil then
        content:='<img class="postthumb" src="'+HTMLEncode(jn1['url'])+
          '" alt="'+HTMLEncode(VarToStr(jn1['caption']))+
          '" /><br />'#13#10+content;
      Handler.RegisterPost(title,content);
     end;
   end;
  Handler.ReportSuccess('Fusion');
end;

initialization
  RegisterFeedProcessor(TFusionFeedProcessor.Create);
end.
