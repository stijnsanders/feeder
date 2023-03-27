unit feedGatsby;

interface

uses eaterReg;

type
  TGatsbyPageDataProcessor=class(TFeedProcessor)
  private
    FFeedURL,FURLPrefix:WideString;
  public
    function Determine(Store: IFeedStore; const FeedURL: WideString;
      var FeedData: WideString; const FeedDataType: WideString): Boolean;
      override;
    procedure ProcessFeed(Handler: IFeedHandler; const FeedData: WideString);
      override;
  end;

implementation

{ TGatsbyPageDataProcessor }

uses Variants, eaterUtils, jsonDoc, eaterSanitize;

function TGatsbyPageDataProcessor.Determine(Store: IFeedStore;
  const FeedURL: WideString; var FeedData: WideString;
  const FeedDataType: WideString): Boolean;
const
  //PageDataSuffix='/page-data/index/page-data.json';
  PageDataSuffix='/page-data.json';
var
  i:integer;
begin
  //detect '<div id="___gatsby"': see FindFeedURL
  Result:=(FeedDataType='application/json') and (Copy(FeedURL,
    Length(FeedURL)-Length(PageDataSuffix)+1,Length(PageDataSuffix))=
    PageDataSuffix);
  if Result then
   begin
    FFeedURL:=FeedURL;
    i:=9;//Length('https://')+1;
    while (i<=Length(FFeedURL)) and (FFeedURL[i]<>'/') do inc(i);
    if (i<=Length(FFeedURL)) and (FFeedURL[i]='/') then
      SetLength(FFeedURL,i);
    FURLPrefix:=FFeedURL+'issue/';//?
   end;
end;

procedure TGatsbyPageDataProcessor.ProcessFeed(Handler: IFeedHandler;
  const FeedData: WideString);
var
  d,dTaxNode,dPost,dCat,dImg:IJSONDocument;
  lTaxNodes,lPosts,lCats:IJSONDocArray;
  iTaxNode,iPost,iCat:integer;
  itemid,itemurl:string;
  pubDate:TDateTime;
  title,content:WideString;
  vCats:Variant;
begin
  inherited;
  lTaxNodes:=JSONDocArray;
  d:=JSON(['result{','data{','allWpTghpTaxonomyIssue{','nodes',lTaxNodes]);
  d.Parse(FeedData);
  try
    Handler.UpdateFeedName(
      JSON(JSON(JSON(JSON(d['result'])['data'])['wpPage'])['seo'])['title']);
  except
    //ignore
  end;

  lPosts:=JSONDocArray;
  dTaxNode:=JSON(['posts{','nodes',lPosts]);
  lCats:=JSONDocArray;
  dPost:=JSON(['categories{','nodes',lCats]);
  dCat:=JSON;
  for iTaxNode:=0 to lTaxNodes.Count-1 do
   begin
    lTaxNodes.LoadItem(iTaxNode,dTaxNode);
    //dTaxNode['name']?
    for iPost:=0 to lPosts.Count-1 do
     begin
      lPosts.LoadItem(iPost,dPost);
      itemid:=dPost['slug'];
      itemurl:=FURLPrefix+itemid;
      pubDate:=ConvDate1(dPost['date']);
      if handler.CheckNewPost(itemid,itemurl,pubDate) then
       begin
        title:=SanitizeTitle(dPost['title']);
        content:=dPost['excerpt'];

        dImg:=JSON(dPost['featuredImage']);
        if dImg<>nil then
         begin
          dImg:=JSON(dImg['node']);
          //TODO: from dImg['srcSet']?
          content:='<img class="postthumb" referrerpolicy="no-referrer'+
            '" src="'+HTMLEncodeQ(FFeedURL+dImg['publicUrl'])+
            '" alt="'+HTMLEncode(VarToStr(dImg['altText']))+
            '" /><br />'#13#10+content;
         end;

        if lCats.Count<>0 then
         begin
          vCats:=VarArrayCreate([0,lCats.Count-1],varOleStr);
          for iCat:=0 to lCats.Count-1 do
           begin
            lCats.LoadItem(iCat,dCat);
            vCats[iCat]:=dCat['name'];//'slug'?
           end;
          Handler.PostTags('category',vCats);
         end;

        Handler.RegisterPost(title,content);
       end;
     end;
   end;
  Handler.ReportSuccess('Gatsby')
end;

initialization
  RegisterFeedProcessor(TGatsbyPageDataProcessor.Create);
end.
