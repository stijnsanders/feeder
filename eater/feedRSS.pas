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
  doc.setProperty('SelectionNamespaces',
    'xmlns:content="http://purl.org/rss/1.0/modules/content/" '+
    'xmlns:media="http://search.yahoo.com/mrss/"');

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
    y:=x.selectSingleNode('title') as IXMLDOMElement;
    if y=nil then title:='' else title:=y.text;
    y:=x.selectSingleNode('content:encoded') as IXMLDOMElement;
    if (y=nil) or IsSomeThingEmpty(y.text) then
      y:=x.selectSingleNode('content') as IXMLDOMElement;
    if y=nil then
      y:=x.selectSingleNode('description') as IXMLDOMElement;
    if y=nil then content:='' else content:=y.text;
    try
      y:=x.selectSingleNode('pubDate') as IXMLDOMElement;
      if y=nil then y:=x.selectSingleNode('pubdate') as IXMLDOMElement; //reddit??!!
      if y=nil then pubDate:=UtcNow else pubDate:=ConvDate2(y.text);
    except
      pubDate:=UtcNow;
    end;

    if Handler.CheckNewPost(itemid,itemurl,pubDate) then
     begin
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

      //pustthumb if not already starts with image
      if not StartsWithIWS(content,'<img ') then
       begin
        if IsProbablyHTML(content) then
          x1:=nil //see below
        else
         begin
          //x1:=x.selectSingleNode('media:content/@url');
          //if x1=nil then
          x1:=x.selectSingleNode('media:thumbnail/@url');
          if x1=nil then
          x1:=x.selectSingleNode('media:content[@medium="image"]/media:thumbnail/@url');
         end;
        if x1=nil then
          x1:=x.selectSingleNode('enclosure[@type="image/jpeg"]/@url');
        if x1=nil then
          x1:=x.selectSingleNode('enclosure[@type="image/png"]/@url');
        if x1<>nil then //<a href="?
         begin
          if Copy(content,1,3)='<p>' then h1:=#13#10 else h1:='<br />'#13#10;
          content:='<img class="postthumb" src="'+
            HTMLEncode(x1.text)+'" />'+h1+content;
          x1:=nil;
         end;
       end;

      Handler.RegisterPost(title,content);
     end;

    x:=xl.nextNode as IXMLDOMElement;
   end;
  xl:=nil;
  Handler.ReportSuccess('RSS');
end;

initialization
  RegisterFeedProcessorXML(TRSSFeedProcessor.Create);
end.
