unit feedTitanium;

interface

uses eaterReg;

type
  TTitaniumFeedProcessor=class(TFeedProcessor)
  public
    function Determine(Store:IFeedStore;const FeedURL:WideString;
      var FeedData:WideString;const FeedDataType:WideString):boolean; override;
    procedure ProcessFeed(Handler: IFeedHandler; const FeedData: WideString);
      override;
  end;

implementation

uses SysUtils, jsonDoc, eaterSanitize, Variants, eaterUtils;

{ TTitaniumFeedProcessor }

function TTitaniumFeedProcessor.Determine(Store:IFeedStore;const FeedURL:WideString;
      var FeedData:WideString;const FeedDataType:WideString):boolean;
begin
  Result:=Store.CheckLastLoadResultPrefix('Titanium') and
    FindPrefixAndCrop(FeedData,'window\[''titanium-state''\] = ');
end;

procedure TTitaniumFeedProcessor.ProcessFeed(Handler: IFeedHandler;
  const FeedData: WideString);
var
  jnodes,jcaption,jThumbs:IJSONDocArray;
  jdoc,jn0,jn1,jd0,jd1:IJSONDocument;
  p1,p2,itemid,itemurl:string;
  pubDate:TDateTime;
  title,content,h1:WideString;
  i,j,k,n:integer;
  v:Variant;
begin
  jnodes:=JSONDocArray;
  jd0:=JSON(['cards',jnodes]);
  jdoc:=JSON(['hub',JSON(['data',JSON([
    FindMatch(FeedData,'"data":{"([^"]*?)":{"[^"]+?":\['),
    jd0])])]);
  try
    jdoc.Parse(FeedData);
  except
    on EJSONDecodeException do
      ;//ignore "data past end"
  end;

  v:=jd0['tagObjs'];
  if VarIsArray(v) then
    try
      Handler.UpdateFeedName(JSON(v[0])['seoTitle']);
    except
      //ignore
    end;

  jcaption:=JSONDocArray;
  jThumbs:=JSONDocArray;
  jn0:=JSON(['contents',jcaption,'feeds',jThumbs]);
  jn1:=JSON(['media',jThumbs]);
  jd1:=JSON;
  p1:='';
  p2:='';
  for i:=0 to jnodes.Count-1 do
   begin
    jnodes.LoadItem(i,jn0);

    //coalesce contents under feed onto contents
    for j:=0 to jThumbs.Count-1 do
      jcaption.AddJSON(jThumbs.GetJSON(j));

    for j:=0 to jcaption.Count-1 do
     begin
      jcaption.LoadItem(j,jn1);

      itemid:=VarToStr(jn1['id']);
      itemurl:=VarToStr(jn1['localLinkUrl']);
      try
        if VarIsNull(jn1['published']) then
          pubDate:=ConvDate1(VarToStr(jn1['updated']))
        else
          pubDate:=ConvDate1(VarToStr(jn1['published']));
      except
        pubDate:=UtcNow;
      end;
      if not((itemurl='') and (content='')) and
        Handler.CheckNewPost(itemid,itemurl,pubDate) then
       begin
        title:=VarToStr(jn1['headline']);

        //TODO: media, mediumIds (leadPhotoId?

        content:=VarToStr(jn1['storyHTML']);
        if content='' then
         begin
          content:=VarToStr(jn1['firstWords']);
          if content<>'' then
            content:=content+'<span style="color:silver;">...</span>';
         end;

        //jn1['media']
        if jthumbs.Count=0 then
         begin
          v:=jn1['mediumIds'];
          if (p1<>'') and VarIsArray(v) and (VarArrayLowBound(v,1)<=VarArrayHighBound(v,1)) then
           begin
            if Copy(content,1,3)='<p>' then h1:=#13#10 else h1:='<br />'#13#10;
            content:='<img class="postthumb" referrerpolicy="no-referrer" src="'+p1+
              VarToStr(v[VarArrayLowBound(v,1)])+
              p2+'" />'+h1+content;
           end;

         end
        else
         begin
          n:=0;
          while n<jthumbs.Count do
           begin
            jthumbs.LoadItem(n,jd1);
            if StartsWith(VarToStr(jd1['imageMimeType']),'image/') then
             begin
              if content='' then content:=VarToStr(jd1['caption']);
              if Copy(content,1,3)='<p>' then h1:=#13#10 else h1:='<br />'#13#10;
              content:='<img class="postthumb" referrerpolicy="no-referrer" src="'+
                VarToStr(jd1['gcsBaseUrl'])+
                VarToStr(VarArrLast(jd1['imageRenderedSizes']))+
                VarToStr(jd1['imageFileExtension'])+
                '" />'+h1+content;
              if p1='' then //see 'mediumIDs' above
               begin
                p1:=VarToStr(jd1['gcsBaseUrl']);
                k:=Length(p1)-1;
                while (k<>0) and (p1[k]<>'/') do dec(k);
                SetLength(p1,k);
                p2:='/'+//?
                  VarToStr(VarArrLast(jd1['imageRenderedSizes']))+
                  VarToStr(jd1['imageFileExtension']);
               end;
              n:=jthumbs.Count;
             end
            else
              inc(n);
           end;
         end;

        Handler.PostTags('tag',jn1['tagIds']);
        Handler.RegisterPost(title,content);
       end;
     end;
   end;
  Handler.ReportSuccess('Titanium');
end;

initialization
  RegisterFeedProcessor(TTitaniumFeedProcessor.Create);
end.
