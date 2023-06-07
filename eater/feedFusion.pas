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
    FindPrefixAndCrop(FeedData,'Fusion.globalContent=');
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
  jdoc,jd1,je1,jn0,jn1:IJSONDocument;
  jd0,je0,jw0:IJSONEnumerator;
  p1,p2,itemid,itemurl:string;
  pubDate:TDateTime;
  title,content:WideString;
  v,vNodes:Variant;
  inode:integer;
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
  if jnodes.Count<>0 then
    for inode:=0 to jnodes.Count-1 do
     begin
      jnodes.LoadItem(inode,jn0);

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
     end
  else
   begin
    content:=FeedData;
    if FindPrefixAndCrop(content,'Fusion.contentCache=') then
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
        if jd0.Key='site-service-hierarchy' then
         begin
          //first of site-service-content?
          jd1:=JSON(jd0.Value);//jd1:=JSON(jdoc['site-service-hierarchy']);
          if jd1<>nil then jd1:=JSON(jd1['{"hierarchy":"default"}']);
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
            je1:=JSON(je0.Value);
            if je1<>nil then je1:=JSON(je1['data']);
            if je1=nil then vNodes:=Null else vNodes:=je1['content_elements'];
            if not VarIsNull(vNodes) then
            for inode:=VarArrayLowBound(vNodes,1) to VarArrayHighBound(vNodes,1) do
             begin
              jn0:=JSON(vNodes[inode]);
              itemid:=jn0['_id'];
              if VarIsNull(jn0['canonical_url']) then
               begin
                jw0:=JSONEnum(jn0['websites']);
                if jw0.Next then
                  itemurl:=FURLPrefix+JSON(jw0.Value)['website_url']
                else
                  itemurl:='';//else raise?
               end
              else
                itemurl:=FURLPrefix+jn0['canonical_url'];
              try
                p1:=VarToStr(jn0['display_date']);
                if p1='' then p1:=VarToStr(jn0['publish_date']);
                if p1='' then p1:=VarToStr(jn0['created_date']);
                if p1='' then pubDate:=UtcNow else pubDate:=ConvDate1(p1);
              except
                pubDate:=UtcNow;
              end;

              if Handler.CheckNewPost(itemid,itemurl,pubDate) then
               begin

                jn1:=JSON(jn0['headlines']);
                if jn1=nil then
                  title:=SanitizeTitle(VarToStr(jn0['headline']))//fallback
                else
                  title:=SanitizeTitle(VarToStr(jn1['basic']));
                v:=jn0['subtitle'];
                if not(VarIsNull(v)) then title:=title+' '#$2014' '+v;

                jn1:=JSON(jn0['subheadlines']);
                if jn1=nil then
                  content:=HTMLEncode(jn0['description'])//fallback
                else
                  content:=HTMLEncode(jn1['basic']);

                //TODO: labels -> Handler.PostTags()

                jn1:=JSON(jn0['promo_items']);
                if jn1<>nil then jn1:=JSON(jn1['basic']);
                if jn1<>nil then
                  content:='<img class="postthumb" referrerpolicy="no-referrer'+
                    '" src="'+HTMLEncodeQ(jn1['url'])+
                    '" alt="'+HTMLEncodeQ(VarToStr(jn1['caption']))+
                    '" /><br />'#13#10+content;

                Handler.RegisterPost(title,content);
               end;
             end;
           end;
         end;
     end;
   end;
  Handler.ReportSuccess('Fusion');
end;

initialization
  RegisterFeedProcessor(TFusionFeedProcessor.Create);
end.
