unit xxmp;

interface

uses xxm;

type
  TXxmfeeder=class(TXxmProject, IXxmProjectEvents1)
  protected
    function HandleException(Context: IXxmContext; const PageClass,
      ExceptionClass, ExceptionMessage: WideString): boolean;
    procedure ReleasingContexts;
    procedure ReleasingProject;
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
  a:string;
begin
  inherited;
  Context.BufferSize:=$10000;
  a:=LowerCase(Address);
  if not((a='auth.xxm') and (Context.ContextString(csVerb)='POST')) and (a<>'badge.xxm') then
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

function TXxmfeeder.HandleException(Context: IXxmContext; const PageClass,
  ExceptionClass, ExceptionMessage: WideString): boolean;
begin
  Context.SendHTML('<!--[>">">"]--><div style="background-color:red;color:white;font-weight:bold;">');
  Context.Send(PageClass+'['+ExceptionClass+']'+ExceptionMessage);
  Context.SendHTML('</div>');
  //TODO: e-mail
  Result:=true;
end;

procedure TXxmfeeder.ReleasingContexts;
begin
  //
end;

procedure TXxmfeeder.ReleasingProject;
begin
  //
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
