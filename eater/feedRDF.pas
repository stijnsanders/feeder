unit feedRDF;

interface

uses eaterReg, MSXML2_TLB;

type
  TRDFFeedProcessor=class(TFeedProcessorXML)
  public
    function Determine(Doc: DOMDocument60): Boolean; override;
    procedure ProcessFeed(Handler: IFeedHandler; Doc: DOMDocument60);
      override;
  end;

implementation

uses Variants, eaterUtils;

{ TRDFFeedProcessor }

function TRDFFeedProcessor.Determine(Doc: DOMDocument60): Boolean;
begin
  Result:=doc.documentElement.nodeName='rdf:RDF';
end;

procedure TRDFFeedProcessor.ProcessFeed(Handler: IFeedHandler;
  Doc: DOMDocument60);
var
  x,y:IXMLDOMElement;
  xl:IXMLDOMNodeList;
  itemid,itemurl:string;
  pubDate:TDateTime;
  title,content:WideString;
  c:integer;
begin
  doc.setProperty('SelectionNamespaces',
   'xmlns:rss="http://purl.org/rss/1.0/"'+
   ' xmlns:dc="http://purl.org/dc/elements/1.1/"');
  x:=doc.documentElement.selectSingleNode('rss:channel/rss:title') as IXMLDOMElement;
  if x<>nil then Handler.UpdateFeedName(x.text);

  c:=0;
  xl:=doc.documentElement.selectNodes('rss:item');
  x:=xl.nextNode as IXMLDOMElement;
  while x<>nil do
   begin
    itemid:=x.getAttribute('rdf:about');
    itemurl:=x.selectSingleNode('rss:link').text;
    y:=x.selectSingleNode('rss:title') as IXMLDOMElement;
    if y=nil then title:='' else title:=y.text;
    y:=x.selectSingleNode('rss:description') as IXMLDOMElement;
    if y=nil then content:='' else content:=y.text;
    try
      y:=x.selectSingleNode('rss:pubDate') as IXMLDOMElement;
      if y=nil then
       begin
        y:=x.selectSingleNode('dc:date') as IXMLDOMElement;
        if y=nil then pubDate:=UtcNow else pubDate:=ConvDate1(y.text);
       end
      else pubDate:=ConvDate2(y.text);
    except
      pubDate:=UtcNow;
    end;
    if Handler.CheckNewPost(itemid,itemurl,pubDate) then
     begin
      Handler.RegisterPost(title,content);
      inc(c);
     end;
    x:=xl.nextNode as IXMLDOMElement;
   end;
  xl:=nil;

  if c=0 then
   begin
    doc.setProperty('SelectionNamespaces',
     'xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"'+
     ' xmlns:schema="http://schema.org/"');
    xl:=doc.documentElement.selectNodes('rdf:Description/schema:hasPart/rdf:Description');
    x:=xl.nextNode as IXMLDOMElement;
    while x<>nil do
     begin
      itemid:=x.getAttribute('rdf:about');
      y:=x.selectSingleNode('schema:url') as IXMLDOMElement;
      if y=nil then itemurl:=itemid else
        itemurl:=VarToStr(y.getAttribute('rdf:resource'));
      y:=x.selectSingleNode('schema:headline') as IXMLDOMElement;
      if y=nil then title:='' else title:=y.text;
      y:=x.selectSingleNode('schema:description') as IXMLDOMElement;
      if y<>nil then title:=title+' '#$2014' '+y.text;

      y:=x.selectSingleNode('schema:articleBody') as IXMLDOMElement;
      if y=nil then content:='' else content:=y.text;
      try
        y:=x.selectSingleNode('schema:datePublished') as IXMLDOMElement;
        pubDate:=ConvDate1(y.text);
      except
        pubDate:=UtcNow;
      end;
      if Handler.CheckNewPost(itemid,itemurl,pubDate) then
        Handler.RegisterPost(title,content);
      x:=xl.nextNode as IXMLDOMElement;
     end;
    xl:=nil;
   end;

  Handler.ReportSuccess('RDF');
end;

initialization
  RegisterFeedProcessorXML(TRDFFeedProcessor.Create);
end.
