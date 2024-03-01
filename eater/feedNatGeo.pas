unit feedNatGeo;

interface

uses eaterReg;

type
  TNatGeoProcessor=class(TFeedProcessor)
  private
    FFeedURL:WideString;
  public
    function Determine(Store:IFeedStore;const FeedURL:WideString;
      var FeedData:WideString;const FeedDataType:WideString):boolean; override;
    procedure ProcessFeed(Handler: IFeedHandler; const FeedData: WideString);
      override;
  end;

implementation

uses SysUtils, jsonDoc, eaterSanitize, Variants, eaterUtils, MSXML2_TLB;

{ TNatGeoProcessor }

function TNatGeoProcessor.Determine(Store: IFeedStore;
  const FeedURL: WideString; var FeedData: WideString;
  const FeedDataType: WideString): boolean;
begin
  Result:=Store.CheckLastLoadResultPrefix('NatGeo') and
    FindPrefixAndCrop(FeedData,'window\[''__natgeo__''\]=');
  if Result then FFeedURL:=FeedURL;
end;

procedure TNatGeoProcessor.ProcessFeed(Handler: IFeedHandler;
  const FeedData: WideString);
var
  jfrms,jmods,jtiles,jctas:IJSONDocArray;
  jdoc,jfrm,jmod,jtile,jdata,j0,j1:IJSONDocument;
  itemid,itemurl:string;
  pubDate:TDateTime;
  data,title,content:WideString;
  frm_i,mod_i,tile_i,tag_i:integer;
  tags,v:Variant;
  r:ServerXMLHTTP60;
  SkipRemaining:boolean;
begin
  jfrms:=JSONDocArray;
  j1:=JSON;
  jdoc:=JSON(['page{','meta',j1,'content{','hub{','frms',jfrms,'}}}']);
  try
    jdoc.Parse(FeedData);
  except
    on EJSONDecodeException do
      ;//ignore "data past end"
  end;

  itemid:=VarToStr(j1['title']);
  if itemid<>'' then Handler.UpdateFeedName(itemid);

  jmods:=JSONDocArray;
  jfrm:=JSON(['mods',jmods]);

  jtiles:=JSONDocArray;
  jmod:=JSON(['tiles',jtiles]);

  jctas:=JSONDocArray;
  jtile:=JSON(['ctas',jctas]);

  jdata:=JSON;
  SkipRemaining:=false;
  r:=CoServerXMLHTTP60.Create;

  for frm_i:=0 to jfrms.Count-1 do
   begin
    jfrms.LoadItem(frm_i,jfrm);
    for mod_i:=0 to jmods.Count-1 do
     begin
      jmods.LoadItem(mod_i,jmod);
      for tile_i:=0 to jtiles.Count-1 do
       begin
        jtiles.LoadItem(tile_i,jtile);
        if jctas.Count>0 then
         begin

{
          //itemid:=jtile['cId'];
          itemurl:=JSON(jctas[0])['url'];
          itemid:=itemurl;//???!!!
          pubDate:=UtcNow;//???!!!
          if (jtile['cmsType']<>'SeriesTile') and
            Handler.CheckNewPost(itemid,itemurl,pubDate) then
           begin
            title:=SanitizeTitle(jtile['title']);
            content:=HTMLEncode(jtile['description']);//'abstract'?

            v:=jtile['tags'];
            if not(VarIsNull(v)) then
             begin
              tags:=VarArrayCreate([VarArrayLowBound(v,1),VarArrayHighBound(v,1)],varOleStr);
              for tag_i:=VarArrayLowBound(v,1) to VarArrayHighBound(v,1) do
                if VarType(v[tag_i])=varUnknown then
                  tags[tag_i]:=JSON(v[tag_i])['name']
                else
                  tags[tag_i]:=VarToStr(v[tag_i]);
              Handler.PostTags('tag',tags);
             end;

            j1:=JSON(jtile['img']);
            content:='<img class="postthumb" referrerpolicy="no-referrer" src="'+
              HTMLEncodeQ(j1['src'])+
              '" alt="'+HTMLEncodeQ(VarToStr(j1['dsc']))+'" /><br />'#13#10+
              content;

            Handler.RegisterPost(title,content);
           end;
}

          itemid:='';//see below
          itemurl:=JSON(jctas[0])['url'];
          if SkipRemaining then
           begin
            //just do CheckNewPost pro forma for total load items count
            Handler.CheckNewPost(itemid,itemurl,0.0);
           end
          else
          if (jtile['cmsType']<>'SeriesTile') then
           begin
            r.open('GET',itemurl,false,EmptyParam,EmptyParam);
            r.send(EmptyParam);
            if r.status=200 then data:=r.responseText else data:='';
            if FindPrefixAndCrop(data,'window\[''__natgeo__''\]=') then
             begin
              try
                jdata.Parse(data);
              except
                on EJSONDecodeException do
                  ;//ignore "data past end"
              end;
              j0:=JSON(JSON(jdata['page'])['content']);
              j1:=JSON(j0['article']);
              if j1=nil then j1:=JSON(j0['prismarticle']);
              j1:=JSON(j1['meta']);
              itemid:=j1['id'];
              try
                pubDate:=ConvDate1(j1['mdfdDt']);
              except
                pubDate:=UtcNow;
              end;
              if Handler.CheckNewPost(itemid,itemurl,pubDate) then
               begin

                //assert itemurl=j1['cnnicl']
                title:=SanitizeTitle(j1['ttl']);
                content:=HTMLEncode(j1['dsc']);

                if not(VarIsNull(j1['sclImg'])) then
                  content:='<img class="postthumb" referrerpolicy="no-referrer" src="'+
                    HTMLEncodeQ(j1['sclImg'])+
                    '" /><br />'#13#10+
                    content;

                v:=JSON(j1['pgTxnmy'])['sources'];//'subjects'?
                if not(VarIsNull(v)) then
                 begin
                  tags:=VarArrayCreate([VarArrayLowBound(v,1),VarArrayHighBound(v,1)],varOleStr);
                  for tag_i:=VarArrayLowBound(v,1) to VarArrayHighBound(v,1) do
                    tags[tag_i]:=VarToStr(v[tag_i]);
                  Handler.PostTags('tag',tags);
                 end;

                Handler.RegisterPost(title,content);

               end
              else //!!
                SkipRemaining:=true;
             end;
           end;

         end;
       end;
     end;
   end;
  Handler.ReportSuccess('NatGeo');
end;

initialization
  RegisterFeedProcessor(TNatGeoProcessor.Create);
end.
