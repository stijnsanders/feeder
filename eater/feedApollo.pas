unit feedApollo;

interface

uses eaterReg;

type
  TApolloFeedProcessor=class(TFeedProcessor)
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

{ TApolloFeedProcessor }

function TApolloFeedProcessor.Determine(Store: IFeedStore;
  const FeedURL: WideString; var FeedData: WideString;
  const FeedDataType: WideString): Boolean;
var
  i,l:integer;
begin
  Result:=Store.CheckLastLoadResultPrefix('Apollo') and
    FindPrefixAndCrop(FeedData,'<script>window.__APOLLO_STATE__=');
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

procedure TApolloFeedProcessor.ProcessFeed(Handler: IFeedHandler;
  const FeedData: WideString);
var
  jdoc,jd1,jd2:IJSONDocument;
  je:IJSONEnumerator;
  itemid,itemurl,title,content,s:WideString;
  pubDate:TDateTime;
  v,tags:Variant;
  i,l:integer;
begin
  jdoc:=JSON;
  try
    jdoc.Parse(FeedData);
  except
    on EJSONDecodeException do
      ;//ignore "data past end"
  end;
  //SaveUTF16('xmls\0000.json',jdoc.AsString);

  je:=JSONEnum(jdoc);
  while je.Next do
    if StartsWith(je.Key,'$ROOT_QUERY.Article') then
     begin
      Handler.UpdateFeedName(JSON(je.Value)['title']);
     end
    else
    if StartsWith(je.Key,'Article:') then
     begin
      jd1:=JSON(je.Value);
      //assert jd1['__typename']='Article'
      if not(VarIsNull(jd1['status'])) then
       begin
        //if jd1['subscribersOnly']=false?
        itemid:=jd1['id'];//assert je.Key='Article:'+jd1['id']
        //jd1['nid']?

        v:=jd1['urlFull'];
        if VarIsNull(v) then
          itemurl:=FURLPrefix+jd1['url']
        else
          itemurl:=VarToStr(v);//assert StartsWith(itemurl,'http')

        pubDate:=ConvDate1(JSON(jd1['publishedAt'])['json']); //publicPublishedDate? updatedAt?

        if Handler.CheckNewPost(itemid,itemurl,pubDate) then
         begin

          title:=SanitizeTitle(jd1['title']);
          //'badge'?

          content:=HTMLEncode(VarToStr(jd1['deck']));

          v:=jd1['authors'];
          if not(VarIsNull(v)) then //and VarIsArray(v) then
           begin
            s:='';
            //assert VarArrayLowBound(v,1)=0 (see jsonDoc.pas)
            l:=VarArrayHighBound(v,1);
            for i:=0 to l do
             begin
              if s<>'' then s:=s+'<br />'#13#10;
              s:=s+HTMLEncode(JSON(jdoc[JSON(v[i])['id']])['name']);
             end;
            content:='<div class="postcreator" style="padding:0.2em;float:right;color:silver;">'+
              s+'</div>'#13#10+content;
           end;

          v:=jd1['ledeImage'];
          if not(VarIsNull(v)) then
           begin
            jd2:=JSON(jdoc[JSON(v)['id']]);
            //if jd2['format']='JPEG'?
            content:='<img class="postthumb" referrerpolicy="no-referrer" src="'+
              HTMLEncode(jd2['src'])+'" alt="'+
              HTMLEncode(jd2['alt'])+'" /><br />'#13#10+content;
            //width? height?
           end;
          //ledeAltImage?   ledeImageCaption?

          v:=jd1['tags'];
          if not(VarIsNull(v)) then //and VarIsArray(v) then
           begin
            //assert VarArrayLowBound(v,1)=0 (see jsonDoc.pas)
            l:=VarArrayHighBound(v,1);
            tags:=VarArrayCreate([0,l],varOleStr);
            for i:=0 to l do
              tags[i]:=JSON(jdoc[JSON(v[i])['id']])['label']; //'slug'?
            Handler.PostTags('tag',tags);
           end;

          Handler.RegisterPost(title,content);
         end;
       end;
     end
    else
    //ignore
    ;

  Handler.ReportSuccess('Apollo');
end;

initialization
  RegisterFeedProcessor(TApolloFeedProcessor.Create);
end.
