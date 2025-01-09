unit feedFusion;

interface

uses eaterReg;

type
  TFusionFeedProcessor=class(TFeedProcessor)
  private
    FURLPrefix:WideString;
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
var
  i,l:integer;
begin
  Result:=Store.CheckLastLoadResultPrefix('Fusion') and
    FindPrefixAndCrop(FeedData,'Fusion.globalContent=','');
  if Result then
   begin
    l:=Length(FeedURL);
    i:=1;
    while (i<=l) and (FeedURL[i]<>':') do inc(i);
    inc(i);//
    if (i<=l) and (FeedURL[i]='/') then inc(i);
    if (i<=l) and (FeedURL[i]='/') then inc(i);
    while (i<=l) and (FeedURL[i]<>'/') do inc(i);
    FURLPrefix:=Copy(FeedURL,1,i-1);
   end;
end;

procedure TFusionFeedProcessor.ProcessFeed(Handler: IFeedHandler;
  const FeedData: WideString);
var
  jnodes:IJSONDocArray;
  jdoc,jd1,je1,jn0,jn1,jn2:IJSONDocument;
  jd0,je0,jw0:IJSONEnumerator;
  p1,itemid,itemurl:string;
  pubDate:TDateTime;
  title,content:WideString;
  v,vNodes,vSections:Variant;
  iNode,iSection:integer;
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
  //SaveUTF16('xmls\0000.json',jdoc.AsString);
  //if jnodes.Count<>0 then
   begin
    Handler.UpdateFeedName(VarToStr(jd1['title']));
    jn0:=JSON;
    for iNode:=0 to jnodes.Count-1 do
     begin
      jnodes.LoadItem(iNode,jn0);

      itemid:=jn0['id'];
      itemurl:=VarToStr(jn0['canonical_url']);
      try
        pubDate:=ConvDate1(VarToStr(jn0['display_time']));//published_time?
      except
        pubDate:=UtcNow;
      end;
      if (itemurl<>'') and (Handler.CheckNewPost(itemid,itemurl,pubDate)) then
       begin
        title:=SanitizeTitle(jn0['title']);
        v:=jn0['subtitle'];
        if not(VarIsNull(v)) then title:=title+' '#$2014' '+v;
        content:=HTMLEncode(jn0['description']);

        jn1:=JSON(jn0['thumbnail']);
        if jn1<>nil then
          content:='<img class="postthumb" referrerpolicy="no-referrer'+
            '" src="'+HTMLEncodeQ(jn1['url'])+
            '" alt="'+HTMLEncodeQ(VarToStr(jn1['caption']))+
            '" /><br />'#13#10+content;

        Handler.RegisterPost(title,content);
       end;
     end;
   end;
  //else
   begin
    content:=FeedData;
    if FindPrefixAndCrop(content,'Fusion.contentCache=','') then
     begin
      jdoc:=JSON;
      try
        jdoc.Parse(content);
      except
        on EJSONDecodeException do
          ;//ignore "data past end"
      end;
      jd0:=JSONEnum(jdoc);
      while jd0.Next do
        if false then //jd0.Key='site-service-hierarchy' then
         begin
          jd1:=JSON(jd0.Value);//jd1:=JSON(jdoc['site-service-hierarchy']);
          //if jd1<>nil then jd1:=JSON(jd1['{"hierarchy":"default"}']);
          je0:=JSONEnum(jd1);
          if je0.Next then jd1:=JSON(je0.Value);
          if jd1<>nil then jd1:=JSON(jd1['data']);
          if jd1<>nil then handler.UpdateFeedName(jd1['name']);
         end
        else
        if Copy(jd0.Key,1,5)='site-' then
          //ignore
        else
         begin
          je0:=JSONEnum(JSON(jd0.Value));
          while je0.Next do
           begin
            vNodes:=Null;//default
            je1:=JSON(je0.Value);
            if je1<>nil then je1:=JSON(je1['data']);
            if je1<>nil then
              if VarIsNull(je1['content_elements']) then
               begin
                je1:=JSON(je1['result']);
                if je1<>nil then vNodes:=je1['articles'];
               end
              else
                vNodes:=je1['content_elements'];
            if not VarIsNull(vNodes) then
            for iNode:=VarArrayLowBound(vNodes,1) to VarArrayHighBound(vNodes,1) do
             begin
              jn0:=JSON(vNodes[iNode]);
              itemid:=VarToStr(jn0['id'])+VarToStr(jn0['_id']);
              if itemid='' then
               begin
                itemurl:='';//jn0['canonical_url']
                pubDate:=0.0;
               end
              else
               begin
                title:='';//see below
                if VarIsNull(jn0['canonical_url']) then
                 begin
                  jw0:=JSONEnum(jn0['websites']);
                  if jw0.Next then
                    itemurl:=JSON(jw0.Value)['website_url']
                  else
                    itemurl:='';//raise?
                  jw0:=nil;
                  if itemurl='' then
                   begin
                    itemurl:=VarToStr(JSON(JSON(jn0['taxonomy'])['primary_section'])['_id']);
                    title:=#$D83D#$DD17#$2009;
                   end;
                  if itemurl<>'' then itemurl:=FURLPrefix+itemurl;
                 end
                else
                  itemurl:=FURLPrefix+jn0['canonical_url'];
                try
                  p1:=VarToStr(jn0['display_date']);
                  if p1='' then p1:=VarToStr(jn0['publish_date']);
                  if p1='' then p1:=VarToStr(jn0['created_date']);
                  if p1='' then p1:=VarToStr(jn0['display_time']);
                  if p1='' then p1:=VarToStr(jn0['publish_time']);
                  if p1='' then p1:=VarToStr(jn0['created_time']);
                  if p1='' then pubDate:=UtcNow else pubDate:=ConvDate1(p1);
                except
                  pubDate:=UtcNow;
                end;
               end;

              if not((itemid='') and (itemurl='')) and
                Handler.CheckNewPost(itemid,itemurl,pubDate) then
               begin

                if VarIsStr(jn0['title']) then
                  title:=title+SanitizeTitle(VarToStr(jn0['title']))
                else
                 begin
                  jn1:=JSON(jn0['headlines']);
                  if jn1=nil then
                    title:=title+SanitizeTitle(VarToStr(jn0['headline']))//fallback
                  else
                    title:=title+SanitizeTitle(VarToStr(jn1['basic']));
                 end;

                if VarIsStr(jn0['description']) then
                  content:=HTMLEncode(VarToStr(jn0['description']))
                else
                 begin
                  jn1:=JSON(jn0['subheadlines']);
                  if jn1=nil then jn1:=JSON(jn0['subheadline']);
                  if jn1=nil then jn1:=JSON(jn0['description']);
                  if jn1=nil then
                    content:=HTMLEncode(VarToStr(jn0['subheadline']))//fallback
                  else
                    content:=HTMLEncode(VarToStr(jn1['basic']));
                 end;

                //JSON(jn1['label'])['promo_label']?

                //['lead_art']?
                //['source']['authors']?

                //TODO: sections -> Handler.PostTags()
                jn1:=JSON(jn0['taxonomy']);
                if jn1=nil then vSections:=Null else vSections:=jn1['sections'];
                if VarIsArray(vSections) then
                 begin
                  v:=VarArrayCreate([VarArrayLowBound(vSections,1),VarArrayHighBound(vSections,1)],varOleStr);
                  for iSection:=VarArrayLowBound(vSections,1) to VarArrayHighBound(vSections,1) do
                   begin
                    jn2:=JSON(vSections[iSection]);
                    v[iSection]:=jn2['name'];
                   end;
                  Handler.PostTags('category',v);//'section'?
                 end;

                jn1:=JSON(jn0['promo_items']);
                if jn1<>nil then jn1:=JSON(jn1['basic']);
                if jn1=nil then jn1:=JSON(jn0['thumbnail']);
                if jn1<>nil then
                  content:='<img class="postthumb" referrerpolicy="no-referrer'+
                    '" src="'+HTMLEncodeQ(jn1['url'])+
                    '" alt="'+HTMLEncodeQ(VarToStr(jn1['caption']))+
                    '" /><br />'#13#10+content;

                Handler.RegisterPost(title,content);
               end;
             end;
           end;
          je0:=nil;
         end;
      jd0:=nil;
     end;
   end;
  Handler.ReportSuccess('Fusion');
end;

initialization
  RegisterFeedProcessor(TFusionFeedProcessor.Create);
end.
