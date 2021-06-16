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

uses SysUtils, eaterSanitize, jsonDoc, Variants, eaterUtils;

{ TWPv2FeedProcessor }

function TWPv2FeedProcessor.Determine(Store:IFeedStore;const FeedURL:WideString;
      var FeedData:WideString;const FeedDataType:WideString):boolean;
begin
  Result:=
    (FeedDataType='application/json') and (Pos(WideString('/wp/v2/'),FeedURL)<>0)
    and (FeedData<>'') and (Copy(FeedData,1,1)='[');
    //and ((Copy(rw,1,7)='[{"id":') or (rw='[]'))
end;

procedure TWPv2FeedProcessor.ProcessFeed(Handler: IFeedHandler;
  const FeedData: WideString);
var
  jnodes:IJSONDocArray;
  jdoc,jn0:IJSONDocument;
  i:integer;
  itemid,itemurl:string;
  title,content:WideString;
  v:Variant;
  pubDate:TDateTime;
begin
  //TODO: if rw='[]' and '/wp/v2/posts' switch to '/wp/v2/articles'? episodes? media?
  jnodes:=JSONDocArray;
  jdoc:=JSON(['items',jnodes]);
  jdoc.Parse('{"items":'+FeedData+'}');
  jn0:=JSON;
  for i:=0 to jnodes.Count-1 do
   begin
    jnodes.LoadItem(i,jn0);
    itemid:=VarToStr(jn0['id']);//'slug'?
    if itemid='' then itemid:=VarToStr(JSON(jn0['guid'])['rendered']);
    itemurl:=VarToStr(jn0['link']);
    title:=VarToStr(JSON(jn0['title'])['rendered']);
    try
      v:=jn0['date_gmt'];
      if VarIsNull(v) then v:=jn0['date'];//modified(_gmt)?
      pubDate:=ConvDate1(VarToStr(v));
    except
      pubDate:=UtcNow;
    end;
    if Handler.CheckNewPost(itemid,itemurl,pubdate) then
     begin
      //'excerpt'?
      content:=VarToStr(JSON(jn0['content'])['rendered']);

      SanitizeWPImgData(content);

      Handler.RegisterPost(title,content);
     end;
   end;
  Handler.ReportSuccess('WPv2');
end;

initialization
  RegisterFeedProcessor(TWPv2FeedProcessor.Create);
end.
