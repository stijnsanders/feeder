unit feedJSON;

interface

uses eaterReg;

type
  TJsonFeedProcessor=class(TFeedProcessor)
  public
    function Determine(Store:IFeedStore;const FeedURL:WideString;
      var FeedData:WideString;const FeedDataType:WideString):boolean; override;
    procedure ProcessFeed(Handler: IFeedHandler; const FeedData: WideString);
      override;
  end;

implementation

uses SysUtils, Variants, jsonDoc, eaterUtils;

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
  i:integer;
begin
  jnodes:=JSONDocArray;
  jdoc:=JSON(['items',jnodes]);
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
    jn1:=JSON(jn0['contents']);
    itemid:=VarToStr(jn0['id']);
    itemurl:=VarToStr(jn0['url']);
    title:=VarToStr(jn0['title']);
    try
      pubDate:=ConvDate1(VarToStr(jn0['date_published']));
    except
      pubDate:=UtcNow;
    end;
    if Handler.CheckNewPost(itemid,itemurl,pubDate) then
     begin
      //TODO: if summary<>content?
      {
      if not(VarIsNull(jn0['summary'])) then
       begin
        s:=VarToStr(jn0['summary']);
        if (s<>'') and (s<>title) then
         begin
          if Length(s)>200 then s:=Copy(s,1,197)+'...';
          title:=title+' '#$2014' '+s;
         end;
       end;
      }
      if VarIsNull(jn0['content_html']) then
        content:=HTMLEncode(VarToStr(jn0['content_text']))
      else
        content:=VarToStr(jn0['content_html']);
      Handler.RegisterPost(title,content);
     end;
   end;
  Handler.ReportSuccess('JSONfeed');
end;

initialization
  RegisterFeedProcessor(TJsonFeedProcessor.Create);
end.
