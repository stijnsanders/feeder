unit feedNextPush;

interface

uses eaterReg, jsonDoc;

type
  TNextPushFeedProcessor=class(TFeedProcessor)
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

uses SysUtils, Variants, eaterUtils, eaterSanitize, VBScript_RegExp_55_TLB;

{ TNextPushFeedProcessor }

function TNextPushFeedProcessor.Determine(Store: IFeedStore;
  const FeedURL: WideString; var FeedData: WideString;
  const FeedDataType: WideString): Boolean;
begin
  Result:=//Store.CheckLastLoadResultPrefix('NextPush') and
    (Pos(WideString('<script>self.__next_f.push('),FeedData)<>0);
  if Result then FFeedURL:=FeedURL;
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
    if (VarType(v[vn])=varBoolean) and (v[vn]=false) then
      for vi:=VarArrayLowBound(v,1) to vn-1 do
        ProcessQuad(v[vi])
    else
     begin
      //assert VarArrayHighBound(v,1)=3
      d:=JSON(v[3]);
      vx:=d['children'];
      if VarIsArray(vx) then
       begin
        //assert VarArrayLowBound(vx,1)=0 //see jsonDoc
        vn:=VarArrayHighBound(vx,1)+1;
        if (vn=4) and VarIsStr(vx[0]) then
          ProcessQuad(vx)
        else
          for vi:=0 to vn-1 do
            if VarIsArray(vx[vi]) then ProcessQuad(vx[vi]);
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
     end;
  end;

var
  re1:RegExp;
  mc:MatchCollection;
  m:Match;
  mi,wi,vi:integer;
  d:IJSONDocument;
  w:WideString;
  v:Variant;
begin
  inherited;
  re1:=CoRegExp.Create;
  re1.Pattern:='<script>self\.__next_f\.push\((.+?)\)</script>';
  re1.Global:=true;
  mc:=re1.Execute(FeedData) as MatchCollection;

  d:=JSON;
  for mi:=0 to mc.Count-1 do
   begin
    m:=mc.Item[mi] as Match;
    d.Parse('{"_":'+(m.SubMatches as SubMatches).Item[0]+'}');
    //assert d['_'][0]=1
    w:=d['_'][1];
    wi:=1;
    while (wi<8) and (wi<Length(w)) and (w[wi]<>':') do inc(wi);
    if Copy(w,wi,7)=':[["$",' then //?
      try
        d.Parse('{"_":'+Copy(w,wi+1,Length(w)-wi)+'}');
        v:=d['_'];
        for vi:=VarArrayLowBound(v,1) to VarArrayHighBound(v,1) do
          if VarIsArray(v[vi]) then ProcessQuad(v[vi]);
      except
        on EJSONDecodeException do ;//ignore
      end;
   end;

  Handler.ReportSuccess('NextPush');
end;

initialization
  RegisterFeedProcessor(TNextPushFeedProcessor.Create);
end.
