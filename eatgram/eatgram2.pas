unit eatgram2;

{$WARN SYMBOL_PLATFORM OFF}

interface

uses
  ComObj, ActiveX, eatgram_TLB, StdVcl;

type
  TEaterGram = class(TAutoObject, IEaterGram)
  protected
    function LoadData(const URL: WideString): WideString; safecall;

  end;

implementation

uses ComServ, eatgram1;

function TEaterGram.LoadData(const URL: WideString): WideString;
begin
  Result:=webInstagram.LoadData(URL);
end;

initialization
  TAutoObjectFactory.Create(ComServer, TEaterGram, Class_EaterGram,
    ciMultiInstance, tmApartment);
end.
