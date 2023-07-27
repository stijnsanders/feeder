unit feedAtom;

interface

uses eaterReg, MSXML2_TLB;

type
  TAtomFeedProcessor=class(TFeedProcessorXML)
  public
    function Determine(Doc:DOMDocument60): Boolean; override;
    procedure ProcessFeed(Handler:IFeedHandler;Doc:DOMDocument60); override;
  end;

implementation

uses eaterUtils, Variants, eaterSanitize;

{ TAtomFeedProcessor }

function TAtomFeedProcessor.Determine(Doc: DOMDocument60): Boolean;
begin
  Result:=Doc.documentElement.nodeName='feed';
end;

procedure TAtomFeedProcessor.ProcessFeed(Handler: IFeedHandler;
  Doc: DOMDocument60);
var
  s:string;
  i:integer;
  x,y:IXMLDOMElement;
  xl,xl1:IXMLDOMNodeList;
  x1:IXMLDOMNode;
  itemid,itemurl:string;
  pubdate:TDateTime;
  title,content,h1:WideString;
  tags:Variant;
begin
  if doc.namespaces.length=0 then
    s:='xmlns:atom="http://www.w3.org/2005/Atom"'
  else
   begin
    i:=0;
    while (i<doc.namespaces.length) and (doc.namespaces[i]<>'http://www.w3.org/2005/Atom') do inc(i);
    if i=doc.namespaces.length then i:=0;
    s:='xmlns:atom="'+doc.namespaces[i]+'"';
   end;
  s:=s+' xmlns:media="http://search.yahoo.com/mrss/"';
  doc.setProperty('SelectionNamespaces',s);

  x:=doc.documentElement.selectSingleNode('atom:title') as IXMLDOMElement;
  if x<>nil then Handler.UpdateFeedName(x.text);

  xl:=doc.documentElement.selectNodes('atom:entry');
  x:=xl.nextNode as IXMLDOMElement;
  while x<>nil do
   begin
    y:=x.selectSingleNode('atom:id') as IXMLDOMElement;
    if y=nil then itemid:='' else itemid:=y.text;
    if Copy(itemid,1,4)='http' then
      itemurl:=itemid
    else
     begin
      xl1:=x.selectNodes('atom:link');
      y:=xl1.nextNode as IXMLDOMElement;
      if y=nil then
        itemurl:=itemid
      else
        itemurl:=y.getAttribute('href');//default
      while y<>nil do
       begin
        //'rel'?
        if y.getAttribute('type')='text/html' then
          itemurl:=y.getAttribute('href');
        y:=xl1.nextNode as IXMLDOMElement;
       end;
      xl1:=nil;
      if itemid='' then itemid:=itemurl;
     end;
    try
      y:=x.selectSingleNode('atom:published') as IXMLDOMElement;
      if y=nil then y:=x.selectSingleNode('atom:issued') as IXMLDOMElement;
      if y=nil then y:=x.selectSingleNode('atom:modified') as IXMLDOMElement;
      if y=nil then y:=x.selectSingleNode('atom:updated') as IXMLDOMElement;
      if y=nil then pubDate:=UtcNow else pubDate:=ConvDate1(y.text);
    except
      pubDate:=UtcNow;
    end;

    if Handler.CheckNewPost(itemid,itemurl,pubDate) then
     begin

      y:=x.selectSingleNode('atom:title') as IXMLDOMElement;
      if y=nil then y:=x.selectSingleNode('media:group/media:title') as IXMLDOMElement;
      if y=nil then title:='' else title:=y.text;
      y:=x.selectSingleNode('atom:content') as IXMLDOMElement;
      if y=nil then y:=x.selectSingleNode('atom:summary') as IXMLDOMElement;
      if y=nil then
       begin
        y:=x.selectSingleNode('media:group/media:description') as IXMLDOMElement;
        if y=nil then
          content:=''
        else
          content:=EncodeNonHTMLContent(y.text);
       end
      else
        content:=y.text;

      xl1:=x.selectNodes('atom:category');
      if xl1.length<>0 then
       begin
        tags:=VarArrayCreate([0,xl1.length-1],varOleStr);
        i:=0;
        y:=xl1.nextNode as IXMLDOMElement;
        while y<>nil do
         begin
          tags[i]:=y.getAttribute('term');
          inc(i);
          y:=xl1.nextNode as IXMLDOMElement;
         end;
        Handler.PostTags('category',tags);
       end;
      xl1:=nil;

      if not(HTMLStartsWithImg(content))then
       begin
        x1:=x.selectSingleNode('atom:link[@rel="enclosure" and @type="image/jpeg"]/@href');
        if x1=nil then x1:=x.selectSingleNode('atom:link[@rel="enclosure" and @type="image/png"]/@href');
        if x1=nil then x1:=x.selectSingleNode('media:group/media:thumbnail/@url');
        if x1=nil then x1:=x.selectSingleNode('media:group/media:content[@medium="image" and @type="image/jpeg"]/@url');
        if x1=nil then x1:=x.selectSingleNode('media:content/media:thumbnail/@url');
        if x1<>nil then
         begin
          if Copy(content,1,3)='<p>' then h1:=#13#10 else h1:='<br />'#13#10;
          content:='<img class="postthumb" referrerpolicy="no-referrer" src="'+//<a href="?
            HTMLEncodeQ(x1.text)+'" />'+h1+content;
         end;
        x1:=nil;
       end;

      Handler.RegisterPost(title,content);
     end;

    x:=xl.nextNode as IXMLDOMElement;
   end;
  xl:=nil;
  Handler.ReportSuccess('Atom');
end;

initialization
  RegisterFeedProcessorXML(TAtomFeedProcessor.Create);
end.
