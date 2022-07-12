unit eatgram1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.StdCtrls,
  WebView2, Winapi.ActiveX, Vcl.Edge;

type
  TWebInstagramState=(wisUnknown,wisNotLoggedIn,wisReady,wisLoaded,wisError);

  TwebInstagram = class(TForm)
    Panel1: TPanel;
    btnLoginDone: TButton;
    EdgeBrowser1: TEdgeBrowser;
    lblURL: TLabel;
    btnSkip: TButton;
    lblCount: TLabel;
    procedure EdgeBrowser1ExecuteScript(Sender: TCustomEdgeBrowser;
      AResult: HRESULT; const AResultObjectAsJson: string);
    procedure EdgeBrowser1NavigationCompleted(Sender: TCustomEdgeBrowser;
      IsSuccess: Boolean; WebErrorStatus: TOleEnum);
    procedure btnSkipClick(Sender: TObject);
    procedure btnLoginDoneClick(Sender: TObject);
  private
    FState:TWebInstagramState;
    FURL,FData,FCountL:string;
    FCountD,FCountI:integer;
    procedure ComLastRelease(var Shutdown:boolean);
  protected
    procedure DoShow; override;
    procedure DoClose(var Action: TCloseAction); override;
  public
    function LoadData(const URL:string):string;
    procedure WMQueryEndSession(var Message: TWMQueryEndSession); message WM_QUERYENDSESSION;
  end;

var
  webInstagram: TwebInstagram;

implementation

uses System.Win.ComServ;

{$R *.dfm}

{ TwebInstagram }

procedure TwebInstagram.DoShow;
begin
  inherited;

  if Copy(LowerCase(ParamStr(1)),1,4)='/reg' then
    ComServer.UpdateRegistry(true);
  if Copy(LowerCase(ParamStr(1)),1,4)='/unr' then
    ComServer.UpdateRegistry(false);

  ComServer.OnLastRelease:=ComLastRelease;
  ComServer.UIInteractive:=false;

  FState:=wisUnknown;
  FURL:='';
  FData:='';
  FCountD:=Trunc(Date);
  FCountI:=0;
  FCountL:='';
  EdgeBrowser1.UserDataFolder:=ExtractFileDir(ParamStr(0))+'\EdgeData';
  EdgeBrowser1.Navigate('https://www.instagram.com/');
end;

procedure TwebInstagram.DoClose(var Action: TCloseAction);
begin
  inherited;
  Action:=caMinimize;//?
end;

procedure TwebInstagram.EdgeBrowser1NavigationCompleted(
  Sender: TCustomEdgeBrowser; IsSuccess: Boolean; WebErrorStatus: TOleEnum);
begin
  case FState of
    wisUnknown,wisNotLoggedIn:
      EdgeBrowser1.ExecuteScript('document.cookie');
    wisReady:
      //EdgeBrowser1.ExecuteScript('window._sharedData.entry_data.ProfilePage[0].graphql');
      EdgeBrowser1.ExecuteScript('document.body.innerText');
  end;
end;

procedure TwebInstagram.EdgeBrowser1ExecuteScript(Sender: TCustomEdgeBrowser;
  AResult: HRESULT; const AResultObjectAsJson: string);
begin
  case FState of
    wisUnknown,wisNotLoggedIn:
      if Pos('mid=',AResultObjectAsJson)=0 then
        FState:=wisNotLoggedIn
      else
       begin
        FState:=wisReady;
        btnLoginDone.Visible:=false;
        if FURL<>'' then
          EdgeBrowser1.Navigate(FURL);
       end;
    wisReady:
     begin
      FData:=AResultObjectAsJson;//graphql
      FState:=wisLoaded;
     end;
  end;
end;

procedure TwebInstagram.btnLoginDoneClick(Sender: TObject);
begin
  //assert FState=wisNotLoggedIn
  EdgeBrowser1.ExecuteScript('document.cookie');
end;

procedure TwebInstagram.btnSkipClick(Sender: TObject);
begin
  //Assert FState=wisReady
  FState:=wisError;
end;

procedure TwebInstagram.ComLastRelease(var Shutdown: boolean);
begin
  Shutdown:=true;
end;

function wcHex(c:WideChar):word; inline;
begin
  if (word(c) and $00F0)=$0030 then
    Result:=word(c) and $F
  else
    Result:=9+word(c) and $7;
end;

const
  LoadDataTimeoutMS=30000;

function TwebInstagram.LoadData(const URL: string): string;
var
  i,j,l:integer;
  tc:cardinal;
begin
  FURL:=URL+'?__a=1&__d=1';
  FData:='';
  lblURL.Caption:=URL;
  i:=Trunc(Date);
  if FCountD<>i then
   begin
    FCountL:=','+IntToStr(FCountI)+Copy(FCountL,1,80);
    FCountD:=i;
    FCountI:=0;
   end
  else
   begin
    inc(FCountI);
   end;
  lblCount.Caption:=IntToStr(FCountI)+FCountL;

  if FState=wisReady then
    EdgeBrowser1.Navigate(FURL);
  tc:=GetTickCount;
  while FState<>wisLoaded do
   begin
    Application.HandleMessage;
    if FState=wisError then
     begin
      FState:=wisReady;//wisUnknown and x(document.cookie) here?
      raise Exception.Create('Instagram User Abort');
     end;
    if cardinal(GetTickCount-tc)>LoadDataTimeoutMS then
      raise Exception.Create('Instagram LoadData Timeout');
   end;
  if FState=wisLoaded then
   begin
    FState:=wisReady;
    l:=Length(FData);
    SetLength(Result,l);
    if (l=0) or (FData[1]<>'"') then
      raise Exception.Create('Data unexpectedly not a string');
    i:=2;
    j:=0;
    while i<l do
      if FData[i]='\' then
       begin
        inc(i);
        case FData[i] of
          '"','\':
           begin
            inc(j);
            Result[j]:=FData[i];
            inc(i);
           end;
          'u':
           begin
            inc(j);
            Result[j]:=WideChar(
             (wcHex(FData[i+1]) shl 12) or
             (wcHex(FData[i+2]) shl 8) or
             (wcHex(FData[i+3]) shl 4) or
             (wcHex(FData[i+4])));
            inc(i,5);
           end;
          else
            raise Exception.Create('Unknown escape code "'+FData[i]+'"');
        end;
       end
      else
       begin
        inc(j);
        Result[j]:=FData[i];
        inc(i);
       end;
    SetLength(Result,j);
    FData:='';
   end;
  //else raise?
end;

procedure TwebInstagram.WMQueryEndSession(var Message: TWMQueryEndSession);
begin
  Message.Result:=1;
  PostQuitMessage(0);
  Application.Terminate;
end;

end.
