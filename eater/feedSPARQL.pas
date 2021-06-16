unit feedSPARQL;

interface

uses eaterReg, MSXML2_TLB;

type
  TSparqlFeedProcessor=class(TFeedProcessorXML)
  public
    function Determine(Doc: DOMDocument60): Boolean; override;
    procedure ProcessFeed(Handler: IFeedHandler; Doc: DOMDocument60);
      override;
  end;

implementation

uses eaterUtils;

{ TSparqlFeedProcessor }

function TSparqlFeedProcessor.Determine(Doc: DOMDocument60): Boolean;
begin
  Result:=doc.documentElement.nodeName='sparql';
end;

procedure TSparqlFeedProcessor.ProcessFeed(Handler: IFeedHandler;
  Doc: DOMDocument60);
var
  xl:IXMLDOMNodeList;
  x,y:IXMLDOMElement;
  itemid,itemurl:string;
  pubDate:TDateTime;
  title,content:WideString;
begin
  doc.setProperty('SelectionNamespaces',
   'xmlns:s="http://www.w3.org/2005/sparql-results#"');

  //feedname:=??
  xl:=doc.documentElement.selectNodes('s:results/s:result');
  x:=xl.nextNode as IXMLDOMElement;
  while x<>nil do
   begin
    itemid:=x.selectSingleNode('s:binding[@name="news"]/s:uri').text;
    itemurl:=x.selectSingleNode('s:binding[@name="url"]/s:uri').text;
    title:=x.selectSingleNode('s:binding[@name="headline"]/s:literal').text;

    y:=x.selectSingleNode('s:binding[@name="description"]/s:literal') as IXMLDOMElement;
    if (y<>nil) and (y.text<>title) then
      title:=title+' '#$2014' '+y.text;

    y:=x.selectSingleNode('s:binding[@name="body"]/s:literal') as IXMLDOMElement;
    if y=nil then content:='' else content:=y.text;
    try
      y:=x.selectSingleNode('s:binding[@name="pubDate"]/s:literal') as IXMLDOMElement;
      pubDate:=ConvDate1(y.text);
    except
      pubDate:=UtcNow;
    end;
    if Handler.CheckNewPost(itemid,itemurl,pubDate) then
      Handler.RegisterPost(title,content);
    x:=xl.nextNode as IXMLDOMElement;
   end;
  xl:=nil;

  Handler.ReportSuccess('SPARQL');
end;

initialization
  RegisterFeedProcessorXML(TSparqlFeedProcessor.Create);
end.
