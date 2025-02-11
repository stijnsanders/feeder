unit feedNextData;

interface

uses eaterReg, jsonDoc;

type
  TNextDataFeedProcessor=class(TFeedProcessor)
  private
    FFeedURL:WideString;
    procedure ProcessArticle(Handler:IFeedHandler;jdata:IJSONDocument);
    procedure ProcessCompositions(Handler:IFeedHandler;jcompos:IJSONDocArray);
  public
    function Determine(Store: IFeedStore; const FeedURL: WideString;
      var FeedData: WideString; const FeedDataType: WideString): Boolean;
      override;
    procedure ProcessFeed(Handler: IFeedHandler; const FeedData: WideString);
      override;
  end;

implementation

uses SysUtils, Variants, eaterUtils, eaterSanitize, sha3, base64;

{ TNextDataFeedProcessor }

function TNextDataFeedProcessor.Determine(Store: IFeedStore;
  const FeedURL: WideString; var FeedData: WideString;
  const FeedDataType: WideString): Boolean;
begin
  Result:=Store.CheckLastLoadResultPrefix('NextData') and
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
  jimg,jbody,jcats,jcredits:IJSONDocArray;
  je:IJSONEnumerator;
  ci,cj,ck:integer;
  itemid,itemurl,p1:string;
  pubDate:TDateTime;
  title,content:WideString;
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
      ])
    ])]);
  try
    jdoc.Parse(FeedData);
  except
    on EJSONDecodeException do
      ;//ignore "data past end"
  end;

  //SaveUTF16('xmls\0000.json',jdoc.AsString);

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
  ci,ai:integer;
  jc,jm:IJSONDocArray;
  jn1,jn2:IJSONDocument;
  je:IJSONEnumerator;
  itemid,itemurl:string;
  pubDate:TDateTime;
  title,content:WideString;
  v:Variant;
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
            content:=HTMLEncode(VarToStr(jn2['variant']))
          else
            content:=HTMLEncode(jn2['text']);//?
          Handler.PostTags('tag',VarArrayOf([content]));
          title:=SanitizeTitle(JSON(jn1['title'])['text']);
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

initialization
  RegisterFeedProcessor(TNextDataFeedProcessor.Create);
end.
