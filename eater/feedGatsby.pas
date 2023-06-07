unit feedGatsby;

interface

uses eaterReg, jsonDoc;

type
  TGatsbyPageDataProcessor=class(TFeedProcessor)
  private
    FFeedURL,FStaticURL,FURLPrefix:WideString;
    procedure ProcessEntity(Handler: IFeedHandler; Post: IJSONDocument);
  public
    function Determine(Store: IFeedStore; const FeedURL: WideString;
      var FeedData: WideString; const FeedDataType: WideString): Boolean;
      override;
    procedure ProcessFeed(Handler: IFeedHandler; const FeedData: WideString);
      override;
  end;

implementation

uses SysUtils, Variants, eaterUtils, eaterSanitize;

const
  //GatsbyPageDataSuffix='/page-data/index/page-data.json';
  GatsbyPageDataSuffix='/page-data.json';

{ TGatsbyPageDataProcessor }

function TGatsbyPageDataProcessor.Determine(Store: IFeedStore;
  const FeedURL: WideString; var FeedData: WideString;
  const FeedDataType: WideString): Boolean;
var
  i:integer;
begin
  //detect '<div id="___gatsby"': see FindFeedURL
  Result:=(FeedDataType='application/json') and (Copy(FeedURL,
    Length(FeedURL)-Length(GatsbyPageDataSuffix)+1,Length(GatsbyPageDataSuffix))=
    GatsbyPageDataSuffix);
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
  lPosts:=JSONDocArray;
  dPost:=JSON;
  d:=JSON(['result{','data{','allWpTghpTaxonomyIssue{','nodes',lTaxNodes,'}}',
    'pageContext{','node{','data{','content{','mainContent',lPosts,'metaTags',dPost,'}}}}']);
  d.Parse(FeedData);

  if lTaxNodes.Count<>0 then
   begin
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
   end
  else

  if lPosts.Count<>0 then
   begin
    Handler.UpdateFeedName(VarToStr(dPost['title']));//'description'?
    if Copy(FFeedURL,9,4)='www.' then
      FStaticURL:='https://static.'+Copy(FFeedURL,13,Length(FFeedURL)-13)
    else
      FStaticURL:='https://static.'+Copy(FFeedURL,9,Length(FFeedURL)-9);
    dPost:=JSON;
    for iPost:=0 to lPosts.Count-1 do
     begin
      lPosts.LoadItem(iPost,dPost);
      ProcessEntity(Handler,JSON(dPost['entity']));
     end;
   end;

  Handler.ReportSuccess('Gatsby')
end;

procedure TGatsbyPageDataProcessor.ProcessEntity(Handler: IFeedHandler;
  Post: IJSONDocument);
const
  varArrayDoc=varArray or varUnknown;
var
  e:IJSONEnumerator;
  v:Variant;
  i:integer;
  itemid,itemurl,imgurl:string;
  pubDate:TDateTime;
  title,content:WideString;
  dImg:IJSONDocument;
begin
  if VarIsNull(Post['bundle']) then
   begin
    //assert not(VarIsNull(Post['type']))
    e:=JSONEnum(Post);
    while e.Next do
     begin
      v:=e.Value;
      case VarType(v) of
        varUnknown:
         begin
          dImg:=JSON(v);
          if dImg<>nil then dImg:=JSON(dImg['entity']);
          if dImg<>nil then ProcessEntity(Handler,dImg);
         end;
        varArrayDoc:
          for i:=VarArrayLowBound(v,1) to VarArrayHighBound(v,1) do
            ProcessEntity(Handler,JSON(JSON(v[i])['entity']));
      end;
     end;
   end
  else
   begin
    //Post['bundle']='article'?'page'?
    itemid:=VarToStr(Post['id']);
    itemurl:=JSON(Post['url'])['path'];
    if (itemurl<>'') and (itemurl[1]='/') then itemurl:=Copy(itemurl,2,Length(itemurl)-1);
    itemurl:=FFeedURL+itemurl;
    dImg:=JSON(Post['publishDate']);
    if dImg=nil then
      pubDate:=UnixDateDelta+Post['created']/SecsPerDay
    else
      pubDate:=ConvDate1(dImg['date']);
    if Handler.CheckNewPost(itemid,itemurl,pubDate) then
     begin
      title:=SanitizeTitle(Post['title']);
      dImg:=JSON(Post['promoSummary']);
      if dImg=nil then
        content:=HTMLEncode(VarToStr(Post['subHeadline']))
      else
        content:=dImg['value'];
      if VarIsArray(Post['promoImage']) then
       begin
        dImg:=JSON(JSON(Post['promoImage'][0])['entity']);
        imgurl:=JSON(dImg['mediaImage'])['url'];
        if (imgurl<>'') and (imgurl[1]='/') then imgurl:=FStaticURL+imgurl;
        content:='<img class="postthumb" referrerpolicy="no-referrer" src="'+
          HTMLEncode(imgurl)+
          '" alt="'+HTMLEncode(VarToStr(dImg['caption']))+
          '" /><br />'+content;
        //TODO: 'contributor'?
       end;

      //primaryTaxonomy into Handler.PostTags?

      Handler.RegisterPost(title,content);
     end;
   end;
end;

initialization
  RegisterFeedProcessor(TGatsbyPageDataProcessor.Create);
end.
