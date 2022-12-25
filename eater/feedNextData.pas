unit feedNextData;

interface

uses eaterReg;

type
  TNextDataFeedProcessor=class(TFeedProcessor)
  private
    FFeedURL:WideString;
  public
    function Determine(Store: IFeedStore; const FeedURL: WideString;
      var FeedData: WideString; const FeedDataType: WideString): Boolean;
      override;
    procedure ProcessFeed(Handler: IFeedHandler; const FeedData: WideString);
      override;
  end;

implementation

uses jsonDoc, eaterUtils, eaterSanitize, Variants;

{ TNextDataFeedProcessor }

function TNextDataFeedProcessor.Determine(Store: IFeedStore;
  const FeedURL: WideString; var FeedData: WideString;
  const FeedDataType: WideString): Boolean;
begin
  Result:=Store.CheckLastLoadResultPrefix('NextData') and
    FindPrefixAndCrop(FeedData,'<script id="__NEXT_DATA__" type="application/json">');
  if Result then FFeedURL:=FeedURL;
end;

procedure TNextDataFeedProcessor.ProcessFeed(Handler: IFeedHandler;
  const FeedData: WideString);
var
  jdoc,jd1,jn0,jn1:IJSONDocument;
  jcontent,jimg,jbody,jcats:IJSONDocArray;
  je:IJSONEnumerator;
  ci,cj:integer;
  itemid,itemurl,p1:string;
  pubDate:TDateTime;
  title,content:WideString;
  tags:Variant;
begin
  jd1:=JSON;
  jcontent:=JSONDocArray;
  jdoc:=JSON(['props',JSON(['pageProps',JSON(['contentState',jd1,
    'data',JSON(
      ['defaultFeedItems',jcontent
      //,'birthdays',?
      //series,episodes?
      ,'highlightedContent',jcontent])])])]);
  try
    jdoc.Parse(FeedData);
  except
    on EJSONDecodeException do
      ;//ignore "data past end"
  end;
  //feedname?

  //old style
  je:=JSONEnum(jd1);
  while je.Next do
   begin
    jn0:=JSON(je.Value);
    if jn0<>nil then
     begin
      itemid:=VarToStr(jn0['_id']);
      itemurl:=VarToStr(jn0['canonical_url']);
     end;
    if (jn0<>nil) and (itemid<>'') and (itemurl<>'') then
     begin
      try
        pubDate:=ConvDate1(VarToStr(jn0['display_date']));//publish_date?
      except
        pubDate:=UtcNow;
      end;
      if Handler.CheckNewPost(itemid,itemurl,pubDate) then
       begin
        title:=JSON(jn0['headlines'])['basic'];

        jn1:=JSON(jn0['description']);
        if jn1=nil then content:='' else content:=HTMLEncode(jn1['basic']);

        p1:='';//default;
        jn1:=JSON(jn0['promo_items']);
        if jn1<>nil then
          begin
           jn1:=JSON(jn1['basic']);
           if jn1<>nil then p1:=VarToStr(jn1['url']);
          end;
        if p1<>'' then
          content:=
            '<img class="postthumb" referrerpolicy="no-referrer" src="'+
            HTMLEncode(JSON(JSON(jn0['promo_items'])['basic'])['url'])+
            '" /><br />'#13#10+content;

        Handler.RegisterPost(title,content);
       end;
     end;
   end;

  //new style
  try
    jn1:=JSON(JSON(JSON(JSON(JSON(
      jdoc['props'])['pageProps'])['seo'])['seomatic'])['metaTitleContainer']);
    Handler.UpdateFeedName(JSON(jn1['title'])['title']);
  except
    //silent
  end;
  jimg:=JSONDocArray;
  jbody:=JSONDocArray;
  jcats:=JSONDocArray;
  jn0:=JSON(['image',jimg,'body',jbody,'feedCategories',jcats]);
  jn1:=JSON;
  for ci:=0 to jcontent.Count-1 do
   begin
    jcontent.LoadItem(ci,jn0);
    itemid:=jn0['id'];
    itemurl:=FFeedURL+jn0['slug'];
    try
      p1:=VarToStr(jn0['dateUpdated']);
      if p1='' then p1:=VarToStr(jn0['postDate']);
      pubDate:=ConvDate1(p1);
    except
      pubDate:=UtcNow;
    end;
    if Handler.CheckNewPost(itemid,itemurl,pubDate) then
     begin
      title:=SanitizeTitle(jn0['title']);
      if jbody.Count=0 then
        content:=VarToStr(jn0['excerpt'])
      else
       begin
        content:='';
        for cj:=0 to jbody.Count-1 do
         begin
          jbody.LoadItem(cj,jn1);
          if not(VarIsNull(jn1['intro'])) then
            content:=content+'<span style="color:#666666;">'+
              VarToStr(jn1['intro'])+'</span>'#13#10;
          if not(VarIsNull(jn1['text'])) then
            content:=content+VarToStr(jn1['text'])+#13#10;
         end;
       end;

      if jimg.Count<>0 then
       begin
        jimg.LoadItem(0,jn1);
        content:=
          '<img class="postthumb" referrerpolicy="no-referrer" src="'+
          HTMLEncode(JSON(jn1['heroOptimized'])['src'])+
          '" /><br />'#13#10+content;
       end;

      if jcats.Count<>0 then
       begin
        tags:=VarArrayCreate([0,jcats.Count-1],varOleStr);
        for cj:=0 to jcats.Count-1 do
         begin
          jcats.LoadItem(cj,jn1);
          tags[cj]:=jn1['title'];
         end;
        Handler.PostTags('category',tags);
       end;

      Handler.RegisterPost(title,content);
     end;
   end;

  Handler.ReportSuccess('NextData');
end;

initialization
  RegisterFeedProcessor(TNextDataFeedProcessor.Create);
end.
