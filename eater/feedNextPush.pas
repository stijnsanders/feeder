unit feedNextPush;

interface

uses eaterReg, jsonDoc;

type
  TNextPushFeedProcessor=class(TFeedProcessor)
  private
    FFeedURL:WideString;
    FTagName,FTagHref,FTagSrc,FTagAlt:string;
    FSection:IJSONDocument;
    procedure ProcessArticles(Handler:IFeedHandler;const vArticles:Variant);
    procedure ProcessArtData(Handler:IFeedHandler;const vArticles:Variant);
    procedure ProcessArticle1(Handler:IFeedHandler;const vArticle:Variant);
    function GetFromSection(const Path:string):Variant;
  public
    function Determine(Store: IFeedStore; const FeedURL: WideString;
      var FeedData: WideString; const FeedDataType: WideString): Boolean;
      override;
    procedure ProcessFeed(Handler: IFeedHandler; const FeedData: WideString);
      override;
  end;

implementation

uses SysUtils, Variants, eaterUtils, eaterSanitize, VBScript_RegExp_55_TLB;

{ TNextPushFeedProcessor }

function TNextPushFeedProcessor.Determine(Store: IFeedStore;
  const FeedURL: WideString; var FeedData: WideString;
  const FeedDataType: WideString): Boolean;
var
  i:integer;
begin
  Result:=//Store.CheckLastLoadResultPrefix('NextPush') and
    (Pos(WideString('<script>self.__next_f.push('),FeedData)<>0);
  if Result then
   begin
    FFeedURL:=FeedURL;
    i:=Length(FFeedURL);
    while (i<>0) and (FFeedURL[i]<>'/') do dec(i);
    SetLength(FFeedURL,i);
   end;
end;

procedure TNextPushFeedProcessor.ProcessFeed(Handler: IFeedHandler;
  const FeedData: WideString);

  procedure ProcessQuad(const v:Variant);
  var
    d,d1:IJSONDocument;
    vx:Variant;
    vi,vn:integer;

    itemid,itemurl:string;
    pubDate:TDateTime;
    title,content:WideString;
    tags:Variant;

  begin
    //assert VarIsArray(v)
    //assert VarArrayLowBound(v,1)=0
    vn:=VarArrayHighBound(v,1);
    if (vn>0) and (VarType(v[vn])=varBoolean) and (v[vn]=false) then
      for vi:=VarArrayLowBound(v,1) to vn-1 do
        ProcessQuad(v[vi])
    else
    if (vn=3) and (TVarData(v[3]).VType=varUnknown) then //VarArrayHighBound(v,1)=3
     begin
      d:=JSON(v[3]);
      vx:=d['children'];
      if VarIsArray(vx) then
       begin
        if not(VarIsNull(d['href'])) and (vn=4) then
         begin
          FTagSrc:='';
          FTagAlt:='';
         end;

        //assert VarArrayLowBound(vx,1)=0 //see jsonDoc
        vn:=VarArrayHighBound(vx,1)+1;
        if (vn=4) and VarIsStr(vx[0]) then
          ProcessQuad(vx)
        else
          for vi:=0 to vn-1 do
            if VarIsArray(vx[vi]) then ProcessQuad(vx[vi]);

        if not(VarIsNull(d['href'])) and (vn=4) then
         begin

          if VarIsNull(d['title']) then
           begin
            d1:=JSON(vx[3]);
            if not(VarIsNull(d1['title'])) then
             begin
              itemid:='';//?
              itemurl:=FFeedURL+d['href'];
              pubDate:=UtcNow;//?
              if Handler.CheckNewPost(itemid,itemurl,pubDate) then
               begin
                //d['aria-title']?
                title:=HTMLEncode(d1['title']);

                if FTagHref='' then content:='' else
                 begin
                  content:='<p><i><a href="'+HTMLEncode(FFeedURL+FTagHref)+'">'
                    +HTMLEncode(FTagName)+'</a></i></p>';
                  FTagName:='';
                  FTagHref:='';
                 end;

                content:=
                  '<img class="postthumb" referrerpolicy="no-referrer" src="'+
                  HTMLEncode(d1['src'])+'" /><br />'#13#10+content;
                Handler.RegisterPost(title,content);
               end;
             end;
           end
          else
           begin
            itemid:='';
            itemurl:=FFeedURL+d['href'];
            pubDate:=UtcNow;//?
            if Handler.CheckNewPost(itemid,itemurl,pubDate) then
             begin
              title:=HTMLEncode(d['title']);
              content:='';//?
              if FTagSrc<>'' then
                content:=
                  '<img class="postthumb" referrerpolicy="no-referrer" src="'+
                  HTMLEncode(FTagSrc)+'" alt="'+
                  HTMLEncode(FTagAlt)+'" /><br />'#13#10+content;
              Handler.RegisterPost(title,content);
             end;
           end;
         end;

       end
      else
      if not(VarIsNull(d['href'])) and VarIsStr(vx) then
       begin
        FTagName:=vx;
        FTagHref:=d['href'];
       end
      else
      if not(VarIsNull(d['src'])) and VarIsNull(vx) then
       begin
        //if FTagSrc<>'' then raise?
        FTagSrc:=d['src'];
        FTagAlt:=VarToStr(d['alt']);
       end;

      //else?
      vx:=d['event'];
      if VarIsNull(vx) then vx:=d['summary'];
      if VarType(vx)=varUnknown then //if IsJSON(vx) then
       begin
        //ProcessArticle(JSON(vx));
        d:=JSON(vx);
        itemid:=d['id'];
        if VarIsNull(d['slug']) then d['slug']:=itemid;
        itemurl:=FFeedURL
          +'article/'//?
          +d['slug'];
        pubDate:=ConvDate1(d['start']);
        if Handler.CheckNewPost(itemid,itemurl,pubDate) then
         begin

          title:=HTMLEncode(d['title']); //SanitizeTitle?
          content:=HTMLEncode(VarToStr(d['description']));

          d1:=JSON(d['fallbackMedia']);
          if d1<>nil then
           begin
            content:=
              '<img class="postthumb" referrerpolicy="no-referrer" src="'+
              HTMLEncode(d1['url'])+'" alt="'+HTMLEncode(d1['caption'])+
              '" /><br />'#13#10+content;
           end;

          d1:=JSON;
          vx:=d['interests'];
          if VarIsArray(vx) then
           begin
            //assert VarArrayLowBound(vx,1) = 0 //see jsonDoc
            vn:=VarArrayHighBound(vx,1)+1;
            tags:=VarArrayCreate([0,vn-1],varOleStr);
            for vi:=0 to vn-1 do
             begin
              d1:=JSON(vx[vi]);
              tags[vi]:=d1['name']//:=d['slug'];
             end;
            Handler.PostTags('catgory',tags);
           end;

          Handler.RegisterPost(title,content);
         end;
       end;
      vx:=d['featuredArticles'];
      if VarIsArray(vx) then ProcessArticles(Handler,vx);
      vx:=d['subMenuArticles'];
      if VarIsArray(vx) then ProcessArticles(Handler,vx);
      vx:=d['article'];
      if not(VarIsNull(vx)) then ProcessArticle1(Handler,vx);
      ProcessArtData(Handler,d['topStories']);
      ProcessArtData(Handler,d['editorials']);
     end;
  end;

var
  re1:RegExp;
  mc:MatchCollection;
  m:Match;
  mi,wi,vi:integer;
  d,d1,d2:IJSONDocument;
  dParsed:boolean;
  w:WideString;
  v:Variant;
begin
  inherited;
  re1:=CoRegExp.Create;
  re1.Pattern:='<script>self\.__next_f\.push\((.+?)\)</script>';
  re1.Global:=true;
  mc:=re1.Execute(FeedData) as MatchCollection;

  FTagName:='';
  FTagHref:='';

  d:=JSON;
  for mi:=0 to mc.Count-1 do
   begin
    m:=mc.Item[mi] as Match;
    d.Parse('{"_":'+(m.SubMatches as SubMatches).Item[0]+'}');
    //assert d['_'][0]=1
    w:=d['_'][1];

    //SaveUTF16('xmls\0000.json',w);

    wi:=1;
    while (wi<8) and (wi<Length(w)) and (w[wi]<>':') do inc(wi);
    if (Copy(w,wi,7)=':[["$",') then //?
     begin
      dParsed:=false;
      try
        d.Parse('{"_"'+Copy(w,wi,Length(w)-wi+1)+'}');
        dParsed:=true;
      except
        on EJSONDecodeException do ;//ignore
      end;
      if dParsed then
       begin
        FSection:=d;
        v:=d['_'];
        for vi:=VarArrayLowBound(v,1) to VarArrayHighBound(v,1) do
          if VarIsArray(v[vi]) then ProcessQuad(v[vi]);
       end;
     end
    else
    if Copy(w,wi,6)=':["$",' then
     begin
      dParsed:=false;
      try
        d.Parse('{"_"'+Copy(w,wi,Length(w)-wi+1)+'}');
        dParsed:=true;
      except
        on EJSONDecodeException do ;//ignore
      end;
      if dParsed then
       begin
        FSection:=d;
        ProcessQuad(d['_']);
        d1:=JSON(JSON(d['_'][3])['data']);
        if d1<>nil then
         begin
          d2:=JSON(d1['topArticles']);
          if d2<>nil then ProcessArticles(Handler,d2['articles']);
          d2:=JSON(d1['allArticles']);
          if d2<>nil then ProcessArticles(Handler,d2['articles']);
          d2:=JSON(d1['topHeadlines']);
          if d2<>nil then ProcessArticles(Handler,JSON(d2['data'])['articles']);
         end;
        end;
     end;
   end;

  FSection:=nil;
  Handler.ReportSuccess('NextPush');
end;

procedure TNextPushFeedProcessor.ProcessArtData(Handler: IFeedHandler;
  const vArticles: Variant);
var
  vi:integer;
  d,d1:IJSONDocument;
  itemid,itemurl,title,content:WideString;
  pubDate:TDateTime;
  v:Variant;
begin
  if VarIsArray(vArticles) then
    for vi:=VarArrayLowBound(vArticles,1) to VarArrayHighBound(vArticles,1) do
     begin
      d:=JSON(vArticles[vi]);
      pubDate:=UtcNow;//?
      itemid:=d['uuid'];
      itemurl:=JSON(d['canonicalUrl'])['url'];
      if Handler.CheckNewPost(itemid,itemurl,pubDate) then
       begin
        title:=SanitizeTitle(d['title']);
        content:=HTMLEncode(d['summary']);//'description'?
        d1:=JSON(d['author']);//authors?
        if d1<>nil then
         begin
          content:='<div class="postcreator" style="padding:0.2em;float:right;color:silver;">'+
            HTMLEncode(d1['displayName'])+'</div>'#13#10+content;
         end;
        //d['tags']?
        d1:=JSON(d['thumbnail']);
        if d1<>nil then
         begin
          v:=d1['carmotMysterioImages'];
          if VarIsArray(v) then
           begin
            d1:=JSON(v[0]);
            content:=
              '<img class="postthumb" referrerpolicy="no-referrer" src="'+
              HTMLEncode(d1['url'])+
              '" /><br />'#13#10+content;
           end;
         end;
        Handler.RegisterPost(title,content);
       end;
     end;
end;

procedure TNextPushFeedProcessor.ProcessArticles(Handler:IFeedHandler;
  const vArticles:Variant);
var
  iArticle:integer;
  d:IJSONDocument;
  dd:int64;
  itemid,itemurl,title,content:WideString;
  pubDate:TDateTime;
  vx:Variant;
begin
  for iArticle:=VarArrayLowBound(vArticles,1) to VarArrayHighBound(vArticles,1) do
   begin
    d:=JSON(vArticles[iArticle]);
    vx:=d['articles'];
    if VarIsArray(vx) then//if not VarIsNull(vx) then
      ProcessArticles(Handler,vx)
    else
     begin
      itemid:=VarToStr(d['id']);//'urlSafeTitle'?
      itemurl:=FFeedURL+d['url'];
      dd:=d['publishedAt'];
      pubDate:=dd/MSecsPerDay+UnixDateDelta;
      if Handler.CheckNewPost(itemid,itemurl,pubDate) then
       begin
        title:=SanitizeTitle(d['title']);
        content:=HTMLEncode(VarToStr(d['teaser']));

        if d['isMultipleAuthors']=false then
          content:='<div class="postcreator" style="padding:0.2em;float:right;color:silver;">'+
            HTMLEncode(VarToStr(d['authorFirstName'])+' '+VarToStr(d['authorLastName']))+'</div>'#13#10+content;
        //else?

        if not(VarIsNull(d['headlineImagePath'])) then
          content:='<img class="postthumb" referrerpolicy="no-referrer" src="'+
            HTMLEncode(d['headlineImagePath'])+'" alt="'+
            HTMLEncode(VarToStr(d['headlineImageText']))+'" /><br />'#13#10+content;

        //sectionUrlSafeName for Handler.PostTags()?

        Handler.RegisterPost(title,content);
       end;
     end;
   end;
end;

procedure TNextPushFeedProcessor.ProcessArticle1(Handler: IFeedHandler;
  const vArticle: Variant);
var
  d,d1:IJSONDocument;
  itemid,itemurl,title,content,s:WideString;
  pubDate:TDateTime;
  v:Variant;
begin
  if TVarData(vArticle).VType<>varUnknown then
    Exit;

  d:=JSON(vArticle);
  itemid:=VarToStr(d['id']);
  if itemid='' then itemid:=VarToStr(d['uuid']);
  itemurl:=VarToStr(d['url']);//FFeedURL+d['slug'];
  if (itemurl='') and not(VarIsNull(d['canonicalUrl'])) then
    itemurl:=JSON(d['canonicalUrl'])['url'];
  try
    if not(VarIsNull(d['published_at'])) then
      pubDate:=ConvDate1(d['published_at'])
    else
      pubDate:=UtcNow;
  except
    pubDate:=UtcNow;
  end;
  if Handler.CheckNewPost(itemid,itemurl,pubDate) then
   begin
    title:=SanitizeTitle(d['title']);//'neta_title'
    content:=HTMLEncode(VarToStr(d['excerpt']));
    if content='' then HTMLEncode(VarToStr(d['summary']));

    s:=VarToStr(d['meta_description']);
    if s<>'' then
      content:='<div class="postdesc" style="margin-left:1.5em;color:grey;">'
        +HTMLEncode(s)+'</div>'#13#10+content;

    d1:=JSON(d['author']);
    if d1<>nil then
     begin
      s:=VarToStr(d1['name']);
      if s='' then s:=VarToStr(d1['displayName']);
      if s<>'' then
        content:='<div class="postcreator" style="padding:0.2em;float:right;color:silver;">'+
          HTMLEncode(s)+'</div>'#13#10+content;
     end;

    d1:=JSON(d['thumbnails_without_watermark']);
    if d1=nil then d1:=JSON(d['thumbnails']);
    if d1<>nil then s:=d1['origin'] else s:=VarToStr(d['image']);
    if (s='') and VarIsStr(d['thumbnail']) then
     begin
      d1:=JSON(GetFromSection(d['thumbnail']));
      v:=d1['carmotMysterioImages'];
      if VarIsArray(v) then
       begin
        d1:=JSON(v[VarArrayHighBound(v,1)]);
        s:=d1['url'];
       end;
     end;
    if s<>'' then
      content:=
        '<img class="postthumb" referrerpolicy="no-referrer" src="'+
        HTMLEncode(s)+'" alt="'+HTMLEncode(VarToStr(d['caption']))+//'alt_text'?
        '" /><br />'#13#10+content;

    //d['tags']?

    Handler.RegisterPost(title,content);
   end;
end;

function TNextPushFeedProcessor.GetFromSection(const Path: string): Variant;
var
  i,j,k,l:integer;
  s:string;
  procedure Fail(const Msg:string);
  begin
    raise Exception.Create(Msg);//+'@'+IntToStr(i)+':'+Path...
  end;
begin
  l:=Length(Path);
  i:=1;
  Result:=Null;
  while (i<=l) do
   begin
    j:=i;
    while (j<=l) and (Path[j]<>':') do inc(j);
    s:=Copy(Path,i,j-i);
    if s[1]='$' then
     begin
      if FSection=nil then Fail('Section data not available');
      Result:=FSection['_'];
     end
    else
    if s='props' then
     begin
      if not(VarIsArray(Result)) then Fail('quad expected');
      Result:=Result[3];
     end
    else
    if s='children' then
      Result:=JSON(Result)['children']
    else
    if s='thumbnail' then
      Result:=JSON(Result)['thumbnail']
    else
    if TryStrToInt(s,k) then
     begin
      if not(VarIsArray(Result)) then Fail('array expected');
      Result:=Result[k];
     end;
    i:=j+1;//':'
   end;
      //TODO d['thumbnail'])
      //parse string like '$107:props:children:props:children:0:props:children:props:thumbnail'

end;


initialization
  RegisterFeedProcessor(TNextPushFeedProcessor.Create);
end.
