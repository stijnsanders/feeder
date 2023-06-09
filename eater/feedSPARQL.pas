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

  TSparqlRequestProcessor=class(TRequestProcessor)
  public
    function AlternateOpen(const FeedURL: string;
      var LastMod: string; Request: ServerXMLHTTP60): Boolean; override;
  end;

implementation

uses eaterUtils, Variants;

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
    try
      y:=x.selectSingleNode('s:binding[@name="pubDate"]/s:literal') as IXMLDOMElement;
      pubDate:=ConvDate1(y.text);
    except
      pubDate:=UtcNow;
    end;
    if Handler.CheckNewPost(itemid,itemurl,pubDate) then
     begin
      title:=x.selectSingleNode('s:binding[@name="headline"]/s:literal').text;
      y:=x.selectSingleNode('s:binding[@name="description"]/s:literal') as IXMLDOMElement;
      if (y<>nil) and (y.text<>title) then
        title:=title+' '#$2014' '+y.text;
      y:=x.selectSingleNode('s:binding[@name="body"]/s:literal') as IXMLDOMElement;
      if y=nil then content:='' else content:=y.text;
      Handler.RegisterPost(title,content);
     end;
    x:=xl.nextNode as IXMLDOMElement;
   end;
  xl:=nil;

  Handler.ReportSuccess('SPARQL');
end;

{ TSparqlRequestProcessor }

function TSparqlRequestProcessor.AlternateOpen(const FeedURL: string;
  var LastMod: string; Request: ServerXMLHTTP60): Boolean;
begin
  if StartsWith(FeedURL,'sparql://') then
   begin
    Request.open('GET','https://'+Copy(FeedURL,10,Length(FeedURL)-9)+
      '?default-graph-uri=&query=PREFIX+schema%3A+<http%3A%2F%2Fschema.org%2F>%0D%0A'+
      'SELECT+*+WHERE+%7B+%3Fnews+a+schema%3ANewsArticle%0D%0A.+%3Fnews+schema%3Aurl+%3Furl%0D%0A'+
      '.+%3Fnews+schema%3AdatePublished+%3FpubDate%0D%0A'+
      '.+%3Fnews+schema%3Aheadline+%3Fheadline%0D%0A'+
      '.+%3Fnews+schema%3Adescription+%3Fdescription%0D%0A'+
      '.+%3Fnews+schema%3AarticleBody+%3Fbody%0D%0A'+
      '%7D+ORDER+BY+DESC%28%3FpubDate%29+LIMIT+20'
      ,false,EmptyParam,EmptyParam);
    Request.setRequestHeader('Accept','application/sparql-results+xml, application/xml, text/xml');
    Request.setRequestHeader('User-Agent','FeedEater/1.1');
    Result:=true;
   end
  else
    Result:=false;
end;

initialization
  RegisterFeedProcessorXML(TSparqlFeedProcessor.Create);
  RegisterRequestProcessors(TSparqlRequestProcessor.Create);
end.
