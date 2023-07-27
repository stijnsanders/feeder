unit feedRSS;

interface

uses eaterReg, MSXML2_TLB;

type
  TRSSFeedProcessor=class(TFeedProcessorXML)
  public
    function Determine(Doc: DOMDocument60): Boolean; override;
    procedure ProcessFeed(Handler: IFeedHandler; Doc: DOMDocument60);
      override;
  end;

  TRSSRequestProcessor=class(TRequestProcessor)
  public
    function AlternateOpen(const FeedURL: string; var LastMod: string;
      Request: IServerXMLHTTPRequest2): Boolean; override;
  end;

implementation

uses eaterUtils, Variants, eaterSanitize;

{ TRSSFeedProcessor }

function TRSSFeedProcessor.Determine(Doc: DOMDocument60): Boolean;
begin
  Result:=doc.documentElement.nodeName='rss';
end;

procedure TRSSFeedProcessor.ProcessFeed(Handler: IFeedHandler;
  Doc: DOMDocument60);
var
  hasFoaf:boolean;
  s:string;
  i:integer;
  x,y:IXMLDOMElement;
  xl,xl1:IXMLDOMNodeList;
  x1:IXMLDOMNode;
  itemid,itemurl,h1:string;
  pubDate:TDateTime;
  title,content:WideString;
  tags:Variant;
begin
  tags:=Null;//see <source> below
  doc.setProperty('SelectionNamespaces',
    'xmlns:content="http://purl.org/rss/1.0/modules/content/" '+
    'xmlns:media="http://search.yahoo.com/mrss/" '+
    'xmlns:snf="http://www.smartnews.be/snf" '+
    'xmlns:dc="http://purl.org/dc/elements/1.1/"');

  hasFoaf:=false;
  i:=0;
  while not(hasFoaf) and (i<doc.namespaces.length) do
   begin
    s:=doc.namespaces[i];
    if Copy(s,1,22)='http://xmlns.com/foaf/' then hasFoaf:=true;
    inc(i);
   end;

  x:=doc.documentElement.selectSingleNode('channel/title') as IXMLDOMElement;
  if x<>nil then Handler.UpdateFeedName(x.text);

  xl:=doc.documentElement.selectNodes('channel/item');
  x:=xl.nextNode as IXMLDOMElement;
  while x<>nil do
   begin
    y:=x.selectSingleNode('guid') as IXMLDOMElement;
    if y=nil then y:=x.selectSingleNode('link') as IXMLDOMElement;
    if y=nil then itemid:='' else itemid:=y.text;
    y:=x.selectSingleNode('link') as IXMLDOMElement;
    if y=nil then itemurl:='' else itemurl:=y.text;
    try
      y:=x.selectSingleNode('pubDate') as IXMLDOMElement;
      if y=nil then y:=x.selectSingleNode('pubdate') as IXMLDOMElement; //reddit??!!
      if y=nil then y:=x.selectSingleNode('date') as IXMLDOMElement;
      if y=nil then y:=x.selectSingleNode('dc:date') as IXMLDOMElement;
      if y=nil then pubDate:=UtcNow else pubDate:=ConvDate2(y.text);
    except
      pubDate:=UtcNow;
    end;

    if Handler.CheckNewPost(itemid,itemurl,pubDate) then
     begin
      y:=x.selectSingleNode('title') as IXMLDOMElement;
      if y=nil then title:='' else title:=y.text;
      y:=x.selectSingleNode('content:encoded') as IXMLDOMElement;
      if (y=nil) or IsSomeThingEmpty(y.text) then
        y:=x.selectSingleNode('content') as IXMLDOMElement;
      if y=nil then
        y:=x.selectSingleNode('description') as IXMLDOMElement;
      if y=nil then content:='' else content:=y.text;

      xl1:=x.selectNodes('category');
      if xl1.length<>0 then
       begin
        tags:=VarArrayCreate([0,xl1.length-1],varOleStr);
        i:=0;
        y:=xl1.nextNode as IXMLDOMElement;
        while y<>nil do
         begin
          tags[i]:=y.text;
          inc(i);
          y:=xl1.nextNode as IXMLDOMElement;
         end;
        Handler.PostTags('category',tags);
       end;
      xl1:=nil;

      if hasFoaf then //and rhImgFoaf.Test(content) then
        SanitizeFoafImg(content);

      //postthumb if not already starts with image
      if not(HTMLStartsWithImg(content))then
       begin
        if IsProbablyHTML(content) then
          x1:=nil
        else
         begin
          x1:=x.selectSingleNode('media:thumbnail/@url');
          if x1=nil then x1:=x.selectSingleNode('media:content/media:thumbnail/@url');
         end;
        if x1=nil then x1:=x.selectSingleNode('media:content[@type="image/jpeg"]/@url');
        if x1=nil then x1:=x.selectSingleNode('media:content[@type="image/png"]/@url');
        if x1=nil then x1:=x.selectSingleNode('media:content[@medium="image"]/@url');
        if x1=nil then x1:=x.selectSingleNode('enclosure[@type="image/jpeg"]/@url');
        if x1=nil then x1:=x.selectSingleNode('enclosure[@type="image/jpg"]/@url');
        if x1=nil then x1:=x.selectSingleNode('enclosure[@type="image/png"]/@url');
        if x1=nil then x1:=x.selectSingleNode('media:content/@url');
        if x1=nil then x1:=x.selectSingleNode('enclosure/@url');
        if x1=nil then x1:=x.selectSingleNode('image/@url');
        if x1=nil then x1:=x.selectSingleNode('image/@src');
        if x1=nil then x1:=x.selectSingleNode('image');
        if x1<>nil then //<a href="?
         begin
          if Copy(content,1,3)='<p>' then h1:=#13#10 else h1:='<br />'#13#10;
          content:='<img class="postthumb" referrerpolicy="no-referrer" src="'+
            HTMLEncodeQ(x1.text)+'" />'+h1+content;
          x1:=nil;
         end;
       end;

      //really no content (news.yahoo?) check <source>
      if content='' then
       begin
        x1:=x.selectSingleNode('source');
        if x1<>nil then
         begin
          content:=content+'<p style="color:silver;" onclick="document.location='''+
            HTMLEncodeQ(VarToStr((x1 as IXMLDOMElement).getAttribute('url')))+''';">'+
            HTMLEncode(x1.text)+'</p>'#13#10;
          if VarIsNull(tags) then
           begin
            tags:=VarArrayCreate([0,0],varOleStr);
            tags[0]:=x1.text;
            Handler.PostTags('source',tags);
           end;
         end;
       end;

      Handler.RegisterPost(title,content);
     end;

    x:=xl.nextNode as IXMLDOMElement;
   end;
  xl:=nil;
  Handler.ReportSuccess('RSS');
end;

{ TRSSRequestProcessor }

function TRSSRequestProcessor.AlternateOpen(const FeedURL: string;
  var LastMod: string; Request: IServerXMLHTTPRequest2): Boolean;
begin
  if Pos('tumblr.com',FeedURL)<>0 then
   begin
    Request.open('GET',FeedURL,false,EmptyParam,EmptyParam);
    Request.setRequestHeader('User-Agent','Mozilla/5.0 (Windows NT 10.0; Win64; x'+
      '64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/75.0.3770.100 Safari/537.36');
    Request.setRequestHeader('Cookie','_ga=GA1.2.23714421.1433010142; rxx=1tcxhdz'+
      'ww7.1lckhv27&v=1; tmgioct=5d2ce7032975560097163000; pfg=1fd4f3446c5c'+
      'c43c229f7759a039c1f03c54916c6dbe1ad54d36c333d0cf0ed4%23%7B%22eu_resi'+
      'dent%22%3A1%2C%22gdpr_is_acceptable_age%22%3A1%2C%22gdpr_consent_cor'+
      'e%22%3A1%2C%22gdpr_consent_first_party_ads%22%3A1%2C%22gdpr_consent_'+
      'third_party_ads%22%3A1%2C%22gdpr_consent_search_history%22%3A1%2C%22'+
      'exp%22%3A1594760108%2C%22vc%22%3A%22granted_vendor_oids%3D%26oath_ve'+
      'ndor_list_version%3D18%26vendor_list_version%3D154%22%7D%233273090316');
    Request.setRequestHeader('Cache-Control','no-cache, no-store, max-age=0');
    Request.setRequestHeader('Accept','application/rss+xml, application/atom+xml, application/xml, application/json, text/xml');
    Result:=true;
   end
  else
  if StartsWith(FeedURL,'https://www.washingtonpost.com') then
   begin
    Request.open('GET',FeedURL,false,EmptyParam,EmptyParam);
    Request.setRequestHeader('Cookie','wp_gdpr=1|1');
    Request.setRequestHeader('Cache-Control','no-cache, no-store, max-age=0');
    Request.setRequestHeader('User-Agent','FeedEater/1.1');
    Result:=true;
   end
  else
    Result:=false;
end;

initialization
  RegisterFeedProcessorXML(TRSSFeedProcessor.Create);
  RegisterRequestProcessors(TRSSRequestProcessor.Create);
end.
