unit feedRSSinJSON;

interface

uses eaterReg;

type
  TRssInJsonFeedProcessor=class(TFeedProcessor)
    function Determine(Store:IFeedStore;const FeedURL:WideString;
      var FeedData:WideString;const FeedDataType:WideString):boolean; override;
    procedure ProcessFeed(Handler:IFeedHandler;const FeedData:WideString); override;
  end;

implementation

uses eaterUtils, jsonDoc, Variants;

{ TRssInJsonFeedProcessor }

function TRssInJsonFeedProcessor.Determine(Store:IFeedStore;const FeedURL:WideString;
  var FeedData:WideString;const FeedDataType:WideString):boolean;
begin
  Result:=(FeedDataType='application/json') and
    StartsWith(StripWhiteSpace(Copy(FeedData,1,20)),'{"rss":{');
end;

procedure TRssInJsonFeedProcessor.ProcessFeed(Handler: IFeedHandler;
  const FeedData: WideString);
var
  jnodes:IJSONDocArray;
  jdoc,jn0,jc0,jc1:IJSONDocument;
  i:integer;
  itemid,itemURL:string;
  title,content:WideString;
  pubDate:TDateTime;
begin
  jnodes:=JSONDocArray;
  jc1:=JSON(['item',jnodes]);
  jc0:=JSON(['channel',jc1]);
  jdoc:=JSON(['rss',jc0]);
  jdoc.Parse(FeedData);
  //jc0['version']='2.0'?
  Handler.UpdateFeedName(VarToStr(jc1['title']));
  //jc1['link']
  jn0:=JSON;
  for i:=0 to jnodes.Count-1 do
   begin
    jnodes.LoadItem(i,jn0);
    itemid:=VarToStr(jn0['guid']);
    itemurl:=VarToStr(jn0['link']);
    try
      pubDate:=ConvDate2(VarToStr(jn0['pubDate']));
    except
      pubDate:=UtcNow;
    end;
    if Handler.CheckNewPost(itemid,itemurl,pubdate) then
     begin
      title:=VarToStr(jn0['title']);
      //TODO xmlns...=http://purl.org/rss/1.0/modules/content/ "...:encoded"?
      if not VarIsNull(jn0['content']) then
        content:=VarToStr(jn0['content'])
      else
      if not VarIsNull(jn0['description']) then
        content:=VarToStr(jn0['description'])
      else
        content:='';
      Handler.RegisterPost(title,content);
     end;
   end;
  Handler.ReportSuccess('RSS-in-JSON');
end;

initialization
  RegisterFeedProcessor(TRssInJsonFeedProcessor.Create);
end.
