unit feedInstagram;

interface

uses eaterReg;

type
  TInstagramFeedProcessor=class(TFeedProcessor)
  public
    function Determine(Store:IFeedStore;const FeedURL:WideString;
      var FeedData:WideString;const FeedDataType:WideString):boolean; override;
    procedure ProcessFeed(Handler:IFeedHandler;const FeedData:WideString); override;
  end;

implementation

uses Windows, SysUtils, eaterUtils;

{ TInstagramFeedProcessor }

function TInstagramFeedProcessor.Determine(Store:IFeedStore;const FeedURL:WideString;
      var FeedData:WideString;const FeedDataType:WideString):boolean;
begin
  Result:=StartsWith(FeedURL,'https://www.instagram.com/')
    //and FindPrefixAndCrop(FeedData,'window._sharedData = ');
    //and FindPrefixAndCrop(FeedData,'"entry_data":{"ProfilePage":[');
end;

procedure TInstagramFeedProcessor.ProcessFeed(Handler: IFeedHandler;
  const FeedData: WideString);
begin
  Handler.ReportFailure('Instagram not supported');
end;

initialization
  RegisterFeedProcessor(TInstagramFeedProcessor.Create);
end.
