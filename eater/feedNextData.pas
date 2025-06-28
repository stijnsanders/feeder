unit feedNextData;

interface

uses eaterReg, jsonDoc;

type
  TNextDataFeedProcessor=class(TFeedProcessor)
  private
    FFeedURL:WideString;
    procedure ProcessArticle(Handler:IFeedHandler;jdata:IJSONDocument);
    procedure ProcessCompositions(Handler:IFeedHandler;jcompos:IJSONDocArray);
    procedure ProcessCompArt(Handler:IFeedHandler;jdata:IJSONDocument);
  public
    function Determine(Store: IFeedStore; const FeedURL: WideString;
      var FeedData: WideString; const FeedDataType: WideString): Boolean;
      override;
    procedure ProcessFeed(Handler: IFeedHandler; const FeedData: WideString);
      override;
  end;

implementation

uses SysUtils, Variants, eaterUtils, eaterSanitize, sha3, base64, whr;

{ TNextDataFeedProcessor }

function TNextDataFeedProcessor.Determine(Store: IFeedStore;
  const FeedURL: WideString; var FeedData: WideString;
  const FeedDataType: WideString): Boolean;
begin
  Result:=//Store.CheckLastLoadResultPrefix('NextData') and
    FindPrefixAndCrop(FeedData,'<script id="__NEXT_DATA__" type="application/json"','>');
  if not(Result) and StartsWith(FeedData,'{"pageProps":') then
   begin
    FeedData:='{"props":'+FeedData+'}';
    Result:=true;
   end;
  if Result then FFeedURL:=FeedURL;
end;

procedure TNextDataFeedProcessor.ProcessFeed(Handler: IFeedHandler;
  const FeedData: WideString);
var
  jdoc,jd1,jd2,jn0,jn1:IJSONDocument;
  jcontent,jzones,jarticles,jcompos,jevents,jblocks,jitems,
  jContArt,jCompArt,
  jimg,jbody,jcats,jcredits:IJSONDocArray;
  je:IJSONEnumerator;
  ci,cj,ck,cl:integer;
  itemid,itemurl,p1:string;
  pubDate:TDateTime;
  title,content,p2:WideString;
  tags,v:Variant;
begin
  jd1:=JSON;
  jcontent:=JSONDocArray;
  jzones:=JSONDocArray;
  jarticles:=JSONDocArray;
  jcompos:=JSONDocArray;
  jevents:=JSONDocArray;
  jitems:=JSONDocArray;
  jblocks:=JSONDocArray;
  jContArt:=JSONDocArray;
  jCompArt:=JSONDocArray;
  jn0:=JSON(
    ['homepageBuilder',jarticles
    //,'heroArticle',jarticles
    ,'stickyArticle',jarticles
    ,'featuredArticles',jarticles
    ]);
  jdoc:=JSON(['props',JSON(['pageProps',
    JSON(
      ['contentState',jd1
      ,'data',JSON(
        ['heroHome',jcontent
        ,'defaultFeedItems',jcontent
        //birthdays,series,episodes,popuplarCategories?
        ,'highlightedContent',jcontent
        ,'compositions',jcompos
        ,'blocks',jblocks
        ])
      ,'pageData',JSON(['zones',jzones])
      ,'entry',jn0
      ,'latestArticles',jarticles
      ,'events',jevents
      ,'breakingStories',jevents
      ,'globalContent',JSON(['items',jitems])
      ,'articles',jContArt
      ,'content{','components',jCompArt,'}'
      ])
    ])]);
  try
    jdoc.Parse(FeedData);
  except
    on EJSONDecodeException do
      ;//ignore "data past end"
  end;

  SaveUTF16('xmls\0000.json',jdoc.AsString);

  //props.pageProps.contentState
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

  //props.pageProps.data.*[]
  if jcontent.Count<>0 then
   begin
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
      itemurl:=FFeedURL+'feed/'+itemid+'-'+jn0['slug']+'/';
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
              content:=content+'<div class="intro">'+
                VarToStr(jn1['intro'])+'</div>'#13#10;
            if not(VarIsNull(jn1['text'])) then
              content:=content+VarToStr(jn1['text'])+#13#10;
           end;
         end;

        if jimg.Count<>0 then
         begin
          jimg.LoadItem(0,jn1);
          jd1:=JSON(jn1['heroOptimized']);
          if jd1=nil then jd1:=JSON(jn1['coverOptimized']);
          if jd1<>nil then content:=
            '<img class="postthumb" referrerpolicy="no-referrer" src="'+
            HTMLEncode(jd1['src'])+
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
   end;

  //homepagebuilder
  if jarticles.Count<>0 then
   begin
    if (FFeedURL<>'') and (FFeedURL[Length(FFeedURL)]<>'/') then
      FFeedURL:=FFeedURL+'/';
    try
      jn1:=JSON(JSON(jn0['seomatic'])['metaTitleContainer']);
      Handler.UpdateFeedName(JSON(jn1['title'])['title']);
    except
      //silent
    end;
    //ProcessArticle(Handler,JSON(jn0['heroArticle']));
    //ProcessArticle(Handler,JSON(jn0['stickyArticle']));
    jn1:=JSON(['cards',jcontent]);
    jd2:=JSON;
    for ci:=0 to jarticles.Count-1 do
     begin
      jarticles.LoadItem(ci,jn1);
      if jcontent.Count=0 then
       begin
        v:=jn1['article'];
        if VarIsArray(v) then
          for cj:=VarArrayLowBound(v,1) to VarArrayHighBound(v,1) do
            ProcessArticle(Handler,JSON(v[cj]))
        else
         begin
          jd1:=JSON(v);
          if jd1=nil then
            ProcessArticle(Handler,jn1)
          else
            ProcessArticle(Handler,jd1);
         end;
       end
      else
        for cj:=0 to jcontent.Count-1 do
         begin
          jcontent.LoadItem(cj,jd2);
          ProcessArticle(Handler,jd2);
         end;
     end;
   end;

  //zones
  if jzones.Count<>0 then
   begin
    if (FFeedURL<>'') and (FFeedURL[Length(FFeedURL)]<>'/') then
      FFeedURL:=FFeedURL+'/';
    try
      Handler.UpdateFeedName(JSON(JSON(JSON(JSON(
        jdoc['props'])['pageProps'])['pageData'])['pageMetas'])['title']);
    except
      //ignore
    end;
    jn0:=JSON(['blocks',jcontent]);
    jarticles:=JSONDocArray;
    jn1:=JSON(['articles',jarticles]);
    jimg:=JSONDocArray;
    jbody:=JSONDocArray;
    jd1:=JSON(['media',jimg,'body',jbody]);
    jd2:=JSON;
    for ci:=0 to jzones.Count-1 do
     begin
      jzones.LoadItem(ci,jn0);
      for cj:=0 to jcontent.Count-1 do
       begin
        jcontent.LoadItem(cj,jn1);
        //if not(VarIsNull(jcontent['articleUrl']))?
        for ck:=0 to jarticles.Count-1 do
         begin
          jarticles.LoadItem(ck,jd1);
          itemid:=jd1['id'];//?
          itemurl:=FFeedURL+jd1['url'];
          pubDate:=int64(jd1['pubDate'])/SecsPerDay+UnixDateDelta;
          if Handler.CheckNewPost(itemid,itemurl,pubDate) then
           begin
            title:=SanitizeTitle(jd1['title']);
            content:=jd1['chapo'];//??!!
            //TODO: if jbody.Count<>0?
            if jimg.Count<>0 then
             begin
              jimg.LoadItem(0,jd2);
              content:=
                '<img class="postthumb" referrerpolicy="no-referrer" src="'+
                HTMLEncode(jd2['source'])+ //jd2['default']?
                '" /><br />'#13#10+content;
                //alt=" 'title'? 'credit'?
             end;
            //TODO: 'destinations' Handler.PostTags?
            Handler.RegisterPost(title,content);
           end;
         end;
       end;
     end;
   end;

  //compositions
  if jcompos.Count<>0 then
   begin
    try
      jn0:=JSON(JSON(JSON(JSON(
        jdoc['props'])['pageProps'])['data'])['pageProperties']);
      jn1:=JSON(jn0['seo']);
      if not VarIsNull(jn1['title']) then
        Handler.UpdateFeedName(jn1['title'])
      else
       begin
        jn1:=JSON(jn0['title']);
        Handler.UpdateFeedName(jn1['text']);
       end;
    except
      //silent
    end;
    ProcessCompositions(Handler,jcompos);
   end;

  //events
  if jevents.Count<>0 then
   begin
    jd1:=JSON(JSON(jdoc['props'])['pageProps']);
    //Handler.UpdateFeedName(jd1['edition'])?
    jd2:=JSON(jd1['topStory']);
    if jd2<>nil then jevents.AddJSON(jd2.AsString);
    jd2:=JSON(JSON(jd1['storyWidgetInfo'])['article']);
    if jd2<>nil then jevents.AddJSON(jd2.AsString);
    jcats:=JSONDocArray;
    jd1:=JSON(['interests',jcats]);
    for ci:=0 to jevents.Count-1 do
     begin
      jevents.LoadItem(ci,jd1);
      //itemid:=jd1['id'];
      itemid:=VarToStr(jd1['title']);
      if itemid='' then itemid:=jd1['id'] else
        itemid:=UTF8ToString(base64encode(SHA3_256(UTF8Encode(itemid))));
      if VarIsNull(jd1['slug']) then
        itemurl:=FFeedURL+'article/'+jd1['id']
      else
        itemurl:=FFeedURL+'article/'+jd1['slug'];
      try
        pubDate:=ConvDate1(jd1['start']);
      except
        pubDate:=UtcNow;
      end;
      if Handler.CheckNewPost(itemid,itemurl,pubDate) then
       begin
        title:=SanitizeTitle(jd1['title']);
        content:=VarToStr(jd1['summary']);
        if content='' then //?
          content:=VarToStr(jd1['description']);

        if content<>'' then content:='<p>'+HTMLEncode(content)+'</p>';        

        //TODO: 'place'
        //TODO: 'sources'

        jd2:=JSON(jd1['latestMedia']);
        if jd2=nil then jd2:=JSON(jd1['fallbackMedia']);
        //if jd2['isVideo']=false? 'nsfw'?
        if jd2<>nil then
          content:=
            '<img class="postthumb" referrerpolicy="no-referrer" src="'+HTMLEncode(jd2['url'])+
            '" title="'+HTMLEncode(VarToStr(jd2['caption']))+'" /><br />'#13#10+content;

        if jcats.Count<>0 then
         begin
          tags:=VarArrayCreate([0,jcats.Count-1],varOleStr);
          jn1:=JSON;
          for cj:=0 to jcats.Count-1 do
           begin
            jcats.LoadItem(cj,jn1);
            //TODO: jn1['type']='topic'? 'person'? 'place'?
            tags[cj]:=jn1['name'];
           end;
          Handler.PostTags('category',tags);
         end;

        Handler.RegisterPost(title,content);
       end;
     end;
   end;

  //props.pageProps.globalContent.items
  if jitems.Count<>0 then
   begin
    try
      Handler.UpdateFeedName(JSON(JSON(JSON(JSON(
        jdoc['props'])['pageProps'])['globalContent'])['site_data'])['site_description']);
    except
      //ignore
    end;
    jbody:=JSONDocArray;
    jcredits:=JSONDocArray;
    jn0:=JSON(['content_elements',jbody,'credits',JSON(['by',jcredits])]);
    jd2:=JSON;
    for ci:=0 to jitems.Count-1 do
     begin
      jitems.LoadItem(ci,jn0);
      itemid:=jn0['_id'];
      itemurl:=jn0['canonical_url'];
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
        title:=SanitizeTitle(jn1['basic']);

        content:='';
        for cj:=0 to jbody.Count-1 do
         begin
          jbody.LoadItem(cj,jd2);
          if jd2['type']='image' then
           begin
            content:=content+'<p><img class="postthumb" referrerpolicy="no-referrer" src="'+
            HTMLEncode(jd2['url'])+
            '" title="'+HTMLEncode(jd2['caption'])+'" /><br />'#13#10;
           end
          else
          if jd2['type']='text' then
            content:=content+'<p>'+jd2['content']+'</p>'#13#10
          else
            ;//ignore
         end;

        if jcredits.Count<>0 then
         begin
          p1:='';
          for cj:=0 to jcredits.Count-1 do
           begin
            if p1<>'' then p1:=p1+'<br />';
            p1:=p1+HTMLEncode(JSON(jcredits[cj])['name']);
           end;
          content:='<div class="postcreator" style="padding:0.2em;float:right;color:silver;">'+
            p1+'</div>'#13#10+content;
         end;

        jn1:=JSON(jn0['description']);
        content:='<div style="color:#666666;">'+HTMLEncode(jn1['basic'])+'</div>'#13#10+content;

        //TODO: credits.by[].name

        Handler.RegisterPost(title,content);
       end;
     end;
   end;

  //blocks
  if jblocks.Count<>0 then
   begin
    //Handler.UpdateFeedName?
    jitems:=JSONDocArray;
    jarticles:=JSONDocArray;
    jn0:=JSON(['items',jitems]);
    jn1:=JSON(['items',jarticles]);
    for ci:=0 to jblocks.Count-1 do
     begin
      jblocks.LoadItem(ci,jn0);
      cj:=0;
      while cj<jitems.Count do
       begin
        jitems.LoadItem(cj,jn1);
        p1:=jn1['__typename'];
        if (p1='TopicsCollectionBlock') or (p1='LocationCollectionBlock') then
         begin
          for ck:=0 to jarticles.Count-1 do
           jitems.AddJSON(jarticles.GetJSON(ck));
         end
        else
         begin
          //if jn1['__typename']='Article'?
          itemid:=jn1['id'];
          itemurl:=jn1['url'];
          pubDate:=int64(jn1['displayDate'])/SecsPerDay+UnixDateDelta;
          if Handler.CheckNewPost(itemid,itemurl,pubDate) then
           begin
            title:=HTMLEncode(jn1['headline']);
            content:='<p>'+HTMLEncode(jn1['subhead'])+'</p>';
            //primaryTag?
            jd1:=JSON(jn1['image']);
            if jd1<>nil then
             begin
              content:=
                '<img class="postthumb" referrerpolicy="no-referrer" src="'+
                HTMLEncode(jd1['imageUrl'])+
                '" alt="'+
                HTMLEncode(VarToStr(jd1['caption']))+
                '" /><br />'#13#10+content;
             end;
            Handler.RegisterPost(title,content);
           end;
         end;
        inc(cj);
       end;
     end;
   end;

  //'content articles'
  if jContArt.Count<>0 then
   begin
    jd1:=JSON(['content',JSON(['content',jContent])]);
    for ci:=0 to jContArt.Count-1 do
     begin
      jContArt.LoadItem(ci,jd1);
      itemid:=jd1['id'];
      itemurl:=FFeedURL
        +'editorial/'//????!!!
        +jd1['slug'];
      pubDate:=ConvDate1(jd1['date']);//jd1['articleDate']?
      if Handler.CheckNewPost(itemid,itemurl,pubDate) then
       begin
        title:=SanitizeTitle(jd1['title']);
        //assert JSON(jd1['content'])['nodeType']='document'
        content:='';
        for cj:=0 to jContent.Count-1 do
         begin
          jd2:=JSON(['content',jitems]);
          jContent.LoadItem(cj,jd2);
          p1:=jd2['nodeType'];

          if p1='embedded-entry-block' then
           begin
            //assert jItems.Count=0
            jd2:=JSON(jd2['data']);
            jd2:=JSON(jd2['target']);
            //sys.contentType.sys.type='Link'?
            jd2:=JSON(jd2['fields']);
            jn0:=JSON(jd2['image']);
            if jn0<>nil then
             begin
              jn0:=JSON(jn0['fields']);
              content:=content+
                //<div class="?
                '<div style="margin-left:2em;font-size:10pt;">'+
                '<img src="https:'+JSON(jn0['file'])['url']+
                '" referrerpolicy="no-referrer" /><br />'+
                HTMLEncode(VarToStr(jd2['caption']))+'</div>'#13#10;
             end;
           end
          else
          if p1='hr' then
            content:=content+'<hr />'#13#10
          else
          if p1='paragraph' then
           begin
            jn0:=JSON(['marks',jzones]);
            content:=content+'<p>';
            for ck:=0 to jItems.Count-1 do
             begin
              jItems.LoadItem(ck,jn0);
              p1:=jn0['nodeType'];
              if p1='text' then
               begin
                p2:=HTMLEncode(jn0['value']);
                for cl:=0 to jzones.Count-1 do
                 begin
                  p1:=JSON(jzones[cl])['type'];
                  if p1='italic' then p2:='<i>'+p2+'</i>' else
                  if p1='bold' then p2:='<b>'+p2+'</b>' else
                  if p1='underline' then p2:='<u>'+p2+'</u>' else
                  if p1='code' then p2:='<code>'+p2+'</code>' else
                    p2:=p2+'<i style="color:red;">[?'+p1+']</i>';
                 end;
                content:=content+p2;
               end
              else
              if p1='hyperlink' then
               begin
                jn1:=JSON(jn0['content'][0]);
                //Assert jn1['nodeType']='text'
                content:=content+'<a href="'+JSON(jn0['data'])['uri']+'" rel="noreferrer">'
                  +HTMLEncode(jn1['value'])+'</a>';
               end
              else
                content:=content+'<i style="color:red;">[?'+p1+']</i>'#13#10;//ignore
             end;
            content:=content+'<p>'#13#10;
           end
          else
          if p1='heading-1' then
           begin
            jn0:=JSON;
            for ck:=0 to jItems.Count-1 do
             begin
              jItems.LoadItem(ck,jn0);
              p1:=jn0['nodeType'];
              if p1='text' then
               begin
                p2:=jn0['value'];
                if p2<>'' then
                  content:=content+
                    '<h1>'+//? class?
                    HTMLEncode(p2)+'</h1>'#13#10;
               end
              else
                content:=content+'<i style="color:red;">[?'+p1+']</i>'#13#10;//ignore
             end;
           end
          else
          if p1='heading-3' then
           begin
            jn0:=JSON;
            for ck:=0 to jItems.Count-1 do
             begin
              jItems.LoadItem(ck,jn0);
              p1:=jn0['nodeType'];
              if p1='text' then
               begin
                p2:=jn0['value'];
                if p2<>'' then
                  content:=content+
                    '<h3>'+//? class?
                    HTMLEncode(p2)+'</h3>'#13#10;
               end
              else
                content:=content+'<i style="color:red;">[?'+p1+']</i>'#13#10;//ignore
             end;
           end
          else
            content:=content+'<i style="color:red;">[?'+p1+']</i>'#13#10;//ignore?
         end;

        if not HTMLStartsWithImg(content) then
         begin
          jn0:=JSON(jd1['featuredImage']);
          if jn0<>nil then
            content:='<img class="postthumb" referrerpolicy="no-referrer" src="https:'+
              JSON(jn0['file'])['url']+'" /><br />'#13#10+content;
         end;

        v:=jd1['tags'];
        if VarIsArray(v) then Handler.PostTags('tag',v);

        Handler.RegisterPost(title,content);
       end;
     end;
   end;

  //'content articles'
  if jCompArt.Count<>0 then
   begin
    jarticles.Clear;
    jd1:=JSON(
      ['articles',jarticles
      ,'relatedArticles',jarticles
      ,'secondaryStories',jarticles
      ,'tertiaryStories',jarticles
      ]);
    jd2:=JSON;
    for ci:=0 to jCompArt.Count-1 do
     begin
      jCompArt.LoadItem(ci,jd1);
      ProcessCompArt(Handler,JSON(jd1['mainArticle']));
      ProcessCompArt(Handler,JSON(jd1['leadStory']));
      for cj:=0 to jarticles.Count-1 do
       begin
        jarticles.LoadItem(cj,jd2);
        ProcessCompArt(Handler,jd2);
       end;
     end;
   end;

  Handler.ReportSuccess('NextData');
end;

procedure TNextDataFeedProcessor.ProcessArticle(Handler: IFeedHandler;
  jdata: IJSONDocument);
var
  d1:IJSONDocument;
  v:Variant;
  i,i1,i2:integer;
  itemid,itemurl:string;
  pubDate:TDateTime;
  title,content:WideString;
  tags:Variant;
begin
  if (jdata=nil) then itemid:='' else itemid:=VarToStr(jdata['id']);
  if itemid<>'' then
   begin
    itemurl:=VarToStr(jdata['href']);
    if (itemurl='') or (itemurl[1]='/') then itemurl:=Copy(itemurl,2,Length(itemurl)-1);
    itemurl:=FFeedURL+itemurl;

    try
      d1:=JSON(jdata['date']);
      if d1=nil then
        pubDate:=ConvDate1(jdata['dateIso'])
      else
        pubDate:=ConvDate1(d1['iso']);
    except
      pubDate:=UtcNow;
    end;
    if Handler.CheckNewPost(itemid,itemurl,pubDate) then
     begin
      title:=SanitizeTitle(jdata['title']);
      content:=HTMLEncode(jdata['excerpt']);

      //image
      v:=jdata['image'];
      if VarIsArray(v) then d1:=JSON(v[0]) else d1:=nil;
      if d1<>nil then
       begin
        content:=
          '<img class="postthumb" referrerpolicy="no-referrer" src="'+
          HTMLEncode(d1['src'])+
          '" alt="'+HTMLEncode(VarToStr(d1['caption']))+'"'+
          '" /><br />'#13#10+content;
       end;

      v:=jdata['category'];
      if VarIsArray(v) then //if VarType(v) = varArray or varUnknown then
       begin
        d1:=JSON;
        i1:=VarArrayLowBound(v,1);
        i2:=VarArrayHighBound(v,1);
        tags:=VararrayCreate([i1,i2],varOleStr);
        for i:=i1 to i2 do
         begin
          d1:=JSON(v[i]);
          tags[i]:=d1['title'];
         end;
        Handler.PostTags('category',tags);
       end;

      Handler.RegisterPost(title,content);
     end;
   end;
end;

procedure TNextDataFeedProcessor.ProcessCompositions(Handler: IFeedHandler;
  jcompos: IJSONDocArray);
var
  ci,ai,ic2:integer;
  jc,jm,ac1,ac2,ac3:IJSONDocArray;
  jn1,jn2,jd1,jd2,jd3:IJSONDocument;
  je:IJSONEnumerator;
  itemid,itemurl:string;
  pubDate:TDateTime;
  title,content,tag,pd:WideString;
  v:Variant;
  r:TWinHttpRequest;
begin
  jm:=JSONDocArray;
  jc:=JSONDocArray;
  jn1:=JSON(['metadata',jm,'compositions',jc]);
  for ci:=0 to jcompos.Count-1 do
   begin
    jcompos.LoadItem(ci,jn1);
    jn2:=JSON(jn1['layouts']);
    if (jc.Count=0) and (jn2<>nil) then
     begin
      je:=JSONEnum(jn2);
      while je.Next do
       begin
        v:=je.Value;
        if VarIsArray(v) then
         begin
          for ai:=VarArrayLowBound(v,1) to VarArrayHighBound(v,1) do
            jc.Add(JSON(v[ai]));
          ProcessCompositions(Handler,jc);
         end;
        //else raise?
       end;
     end
    else
     begin
      if jc.Count<>0 then
        ProcessCompositions(Handler,jc);
      //else?
      jn2:=JSON(jn1['action']);
      if (jn2<>nil) and not(VarIsNull(jn2['uri'])) and (jm.Count<>0) then
       begin
        itemurl:=jn2['uri'];
        itemid:=itemurl;
        jm.LoadItem(0,jn2);
        pubDate:=int64(jn2['timestamp'])/(SecsPerDay*1000)+UnixDateDelta;
        if Handler.CheckNewPost(itemid,itemurl,pubDate) then
         begin
          jn2:=JSON(jn1['tag']);
          if VarIsNull(jn2['text']) then
            tag:=HTMLEncode(VarToStr(jn2['variant']))
          else
            tag:=HTMLEncode(jn2['text']);//?
          Handler.PostTags('tag',VarArrayOf([tag]));
          title:=SanitizeTitle(JSON(jn1['title'])['text']);

          content:=tag;//default
          r:=TWinHttpRequest.Create;
          try
            r.Open('GET',itemurl);
            r.Send;
            if r.StatusCode=200 then
             begin
              pd:=UTF8ToWideString(r.ResponseData);
              if FindPrefixAndCrop(pd,'<script id="__NEXT_DATA__" type="application/json"','>') then
               begin
                ac1:=JSONDocArray;
                jd1:=JSON(['props{','pageProps{','data{','compositions',ac1]);
                try
                  jd1.Parse(pd);
                except
                  on EJSONDecodeException do ;//ignore
                end;
                ac2:=JSONDocArray;
                ac1.LoadItem(0,JSON(['compositions',ac2]));
                //assert jd2['type']='articleDetail'
                ac3:=JSONDocArray;
                ac2.LoadItem(0,JSON(['compositions',ac3]));
                //assert jd3['type']='articleMain'
                content:='';
                jd2:=JSON;
                for ic2:=0 to ac3.Count-1 do
                 begin
                  ac3.LoadItem(ic2,jd2);
                  //if jd3['type']?
                  if not(VarIsNull(jd2['subtitle'])) then
                    content:=content+'<div style="color:grey">'+JSON(jd2['subtitle'])['html']+'</div>'#13#10
                  else
                  if not(VarIsNull(jd2['title'])) then
                   begin
                    jd3:=JSON(jd2['title']);
                    if not(VarIsNull(jd3['html'])) then
                      content:=content+'<h3>'+jd3['html']+'</h3>'#13#10
                    else
                      content:=content+'<h3>'+HTMLEncode(VarToStr(jd3['text']))+'</h3>'#13#10;
                   end
                  else
                  if not(VarIsNull(jd2['text'])) then
                    content:=content+JSON(jd2['text'])['html']+#13#10
                  else
                    ;//?
                 end;
               end;
             end;
          finally
            r.Free;
          end;

          //TODO: Handler.PostTags(... JSON(jn1['tag'])['text']?
          jn2:=JSON(jn1['image']);
          if jn2<>nil then
            content:=
              '<img class="postthumb" referrerpolicy="no-referrer" src="'+
              HTMLEncode(jn2['url'])+
              //'" alt="'+HTMLEncode(jn2['alt'])+
              '" /><br />'#13#10+content;
              //alt=" 'title'? 'credit'?
          //TODO: 'destinations' Handler.PostTags?
          Handler.RegisterPost(title,content);
         end;
       end;
     end;
   end;
end;

procedure TNextDataFeedProcessor.ProcessCompArt(Handler: IFeedHandler;
  jdata: IJSONDocument);
var
  itemid,itemurl,title,content:string;
  pubdate:TDateTime;
  d:IJSONDocument;
begin
  if (jdata<>nil) and (jdata['type']='ARTICLE_ITEM') then
   begin
    itemid:=jdata['id'];
    itemurl:=FFeedURL+jdata['url'];
    pubdate:=ConvDate1(jdata['datePublished']);
    if Handler.CheckNewPost(itemid,itemurl,pubdate) then
     begin
      title:=SanitizeTitle(jdata['headline']);
      content:=HTMLEncode(jdata['rubric']);
      if not(VarIsNull(jdata['flyTitle'])) then
        content:=content+'<br /><div style="color:silver">'+
          HTMLEncode(jdata['flyTitle'])+'</div>';
      //jdata['section']
      d:=JSON(jdata['image']);
      if d<>nil then
        content:=
          '<img class="postthumb" referrerpolicy="no-referrer" src="'+
          HTMLEncode(d['url'])+
          '" alt="'+HTMLEncode(VarToStr(d['altText']))+'" /><br />'#13#10+content;
      Handler.RegisterPost(title,content);
     end;
   end;
end;

initialization
  RegisterFeedProcessor(TNextDataFeedProcessor.Create);
end.
