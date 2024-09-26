unit eaterReg;

interface

uses SysUtils, MSXML2_TLB;

type
  IFeedStore=interface
    function CheckLastLoadResultPrefix(const Prefix:string):boolean;
  end;

  IFeedHandler=interface
    function CheckNewPost(const PostID:string;const PostURL:WideString;
      PubDate:TDateTime):boolean;
    procedure UpdateFeedName(const NewName:string);
    function GetConfig(const Key:string):string;
    procedure CheckCookie(const url:string;var s1,s2:string);
    procedure PostTags(const TagPrefix:string;const Tags:Variant);
    procedure RegisterPost(const PostTitle,PostContent:WideString);
    procedure ReportSuccess(const Lbl:string);
    procedure ReportFailure(const Msg:string);
  end;

  TFeedProcessor=class(TObject)
  public
    function Determine(Store:IFeedStore;const FeedURL:WideString;
      var FeedData:WideString;const FeedDataType:WideString):boolean; virtual; //abstract
    procedure ProcessFeed(Handler:IFeedHandler;const FeedData:WideString); virtual; //abstract
  end;

  TFeedProcessorXML=class(TObject)
  public
    function Determine(Doc:DOMDocument60):boolean; virtual; //abstract
    procedure ProcessFeed(Handler:IFeedHandler;Doc:DOMDocument60); virtual; //abstract
  end;

  TRequestProcessor=class(TObject)
  public
    function AlternateOpen(const FeedURL:string;var LastMod:string;
      Request:ServerXMLHTTP60):boolean; virtual; //abstract
  end;

  EAlternateProcessFeed=class(Exception);

var
  FeedProcessors:array of TFeedProcessor;
  FeedProcessorsIndex,FeedProcessorsSize:cardinal;

  FeedProcessorsXML:array of TFeedProcessorXML;
  FeedProcessorsXMLIndex,FeedProcessorsXMLSize:cardinal;

  RequestProcessors:array of TRequestProcessor;
  RequestProcessorsIndex,RequestProcessorsSize:cardinal;

procedure RegisterFeedProcessor(Processor:TFeedProcessor);
procedure RegisterFeedProcessorXML(Processor:TFeedProcessorXML);
procedure RegisterRequestProcessors(Processor:TRequestProcessor);

implementation

{ TFeedProcessor }

function TFeedProcessor.Determine(Store:IFeedStore;const FeedURL:WideString;
      var FeedData:WideString;const FeedDataType:WideString):boolean;
begin
  //inheriter is allowed to *not* call inherited
  Result:=false;//default
end;

procedure TFeedProcessor.ProcessFeed(Handler: IFeedHandler;
  const FeedData: WideString);
begin
  //inheriter is allowed to *not* call inherited
  //inheriter is expected to end with either ReportSuccess or ReportFailure
end;

{ TFeedProcessorXML }

function TFeedProcessorXML.Determine(Doc: DOMDocument60): boolean;
begin
  //inheriter is allowed to *not* call inherited
  Result:=false;//default
end;

procedure TFeedProcessorXML.ProcessFeed(Handler: IFeedHandler;
  Doc: DOMDocument60);
begin
  //inheriter is allowed to *not* call inherited
  //inheriter is expected to end with either ReportSuccess or ReportFailure
end;

{ TRequestProcessor }

function TRequestProcessor.AlternateOpen(const FeedURL:string;
  var LastMod:string;Request:ServerXMLHTTP60): boolean;
begin
  //inheriter is responsible of calling Req.open() when resulting true
  //or trowing an EAlternateProcessFeed exception to handle the request in ProcessFeed
  Result:=false;//default
end;

{  }

procedure RegisterFeedProcessor(Processor:TFeedProcessor);
begin
  if FeedProcessorsIndex=FeedProcessorsSize then
   begin
    inc(FeedProcessorsSize,$20);//grow step
    SetLength(FeedProcessors,FeedProcessorsSize);
   end;
  FeedProcessors[FeedProcessorsIndex]:=Processor;
  inc(FeedProcessorsIndex);
end;

procedure RegisterFeedProcessorXML(Processor:TFeedProcessorXML);
begin
  if FeedProcessorsXMLIndex=FeedProcessorsXMLSize then
   begin
    inc(FeedProcessorsXMLSize,$20);//grow step
    SetLength(FeedProcessorsXML,FeedProcessorsXMLSize);
   end;
  FeedProcessorsXML[FeedProcessorsXMLIndex]:=Processor;
  inc(FeedProcessorsXMLIndex);
end;

procedure RegisterRequestProcessors(Processor:TRequestProcessor);
begin
  if RequestProcessorsIndex=RequestProcessorsSize then
   begin
    inc(RequestProcessorsSize,$20);//grow step
    SetLEngth(RequestProcessors,RequestProcessorsSize);
   end;
  RequestProcessors[RequestProcessorsIndex]:=Processor;
  inc(RequestProcessorsIndex);
end;

initialization
  FeedProcessorsIndex:=0;
  FeedProcessorsSize:=0;
  FeedProcessorsXMLIndex:=0;
  FeedProcessorsXMLSize:=0;

end.
