unit xxmp;

interface

uses xxm;

type
  TXxmfeeder=class(TXxmProject)
  public
    function LoadPage(Context: IXxmContext; const Address: WideString): IXxmFragment; override;
    function LoadFragment(Context: IXxmContext; const Address, RelativeTo: WideString): IXxmFragment; override;
    procedure UnloadFragment(Fragment: IXxmFragment); override;
  end;

function XxmProjectLoad(const AProjectName:WideString): IXxmProject; stdcall;

implementation

uses xxmFReg, xxmSession, SysUtils;

function XxmProjectLoad(const AProjectName:WideString): IXxmProject;
begin
  Result:=TXxmfeeder.Create(AProjectName);
end;

type
  TRespondNotImplemented=class(TXxmPage)
  public
    procedure Build(const Context: IXxmContext; const Caller: IXxmFragment;
      const Values: array of OleVariant; const Objects: array of TObject); override;
  end;

{ TXxmfeeder }

function TXxmfeeder.LoadPage(Context: IXxmContext; const Address: WideString): IXxmFragment;
var
  verb:WideString;
begin
  inherited;
  Context.BufferSize:=$10000;
  if LowerCase(Address)<>'auth.xxm' then
    SetSession(Context);

  verb:=Context.ContextString(csVerb);
  if (verb='OPTIONS') or (verb='TRACE') then
    Result:=TRespondNotImplemented.Create(Self)
  else
    Result:=XxmFragmentRegistry.GetFragment(Self,Address,'');
end;

function TXxmfeeder.LoadFragment(Context: IXxmContext; const Address, RelativeTo: WideString): IXxmFragment;
begin
  Result:=XxmFragmentRegistry.GetFragment(Self,Address,RelativeTo);
end;

procedure TXxmfeeder.UnloadFragment(Fragment: IXxmFragment);
begin
  inherited;
  //TODO: set cache TTL, decrease ref count
  //Fragment.Free;
end;

{ TRespondNotImplemented }

procedure TRespondNotImplemented.Build(const Context: IXxmContext; const Caller: IXxmFragment;
  const Values: array of OleVariant; const Objects: array of TObject);
begin
  inherited;
  Context.SetStatus(501,'Not Implemented');
end;

initialization
  IsMultiThread:=true;
end.
