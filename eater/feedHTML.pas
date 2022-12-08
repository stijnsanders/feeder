unit feedHTML;

interface

uses eaterReg, VBScript_RegExp_55_TLB, jsonDoc;

type
  THTMLFeedProcessor1=class(TFeedProcessor)
  private
    FURL:WideString;
    FPostItem,FPostBody:RegExp;
  public
    procedure AfterConstruction; override;
    function Determine(Store:IFeedStore;const FeedURL:WideString;
      var FeedData:WideString;const FeedDataType:WideString):boolean; override;
    procedure ProcessFeed(Handler: IFeedHandler; const FeedData: WideString);
      override;
  end;

  THTMLFeedProcessor2=class(TFeedProcessor)
  private
    FURL,FFeedTitle:WideString;
    FFeedParams:IJSONDocument;
    FPostItem:RegExp;
  public
    procedure AfterConstruction; override;
    function Determine(Store:IFeedStore;const FeedURL:WideString;
      var FeedData:WideString;const FeedDataType:WideString):boolean; override;
    procedure ProcessFeed(Handler: IFeedHandler; const FeedData: WideString);
      override;
  end;


implementation

uses SysUtils, Classes, Variants, eaterUtils, eaterSanitize;

{ THTMLFeedProcessor1 }

procedure THTMLFeedProcessor1.AfterConstruction;
begin
  inherited;
  FPostItem:=CoRegExp.Create;
  FPostItem.Global:=true;
  FPostItem.IgnoreCase:=true;//?
  FPostItem.Pattern:='<([a-z]+)[^>]*? class="post-item"[^>]*?>'
    +'.*?<time[^>]*? datetime="([^"]+?)"[^>]*?>.+?</time>'
    +'.*?<a[^>]*? href="([^"]+?)"[^>]*?>(.+?)</a>(.*?)</\1>';

  FPostBody:=CoRegExp.Create;
  FPostBody.Global:=true;
  FPostBody.IgnoreCase:=true;
  FPostBody.Pattern:='^([^<]*?</[a-z]*?>)*'
end;

//RexExp.Multiline apparently doesn't make '.' accept #10 as well,
//so switch before and after to a (presumably) unused code-point

function c0(const x:WideString):WideString;
var
  i:integer;
begin
  Result:=x;
  for i:=1 to Length(Result) do
    if Result[i]=#10 then Result[i]:=#11;
end;

function c1(const x:WideString):WideString;
var
  i:integer;
begin
  Result:=x;
  for i:=1 to Length(Result) do
    if Result[i]=#11 then Result[i]:=#10;
end;

function THTMLFeedProcessor1.Determine(Store: IFeedStore;
  const FeedURL: WideString; var FeedData: WideString;
  const FeedDataType: WideString): boolean;
begin
  FURL:=FeedURL;
  //Store.CheckLastLoadResultPrefix('HTML:1')?
  Result:=(FeedDataType='text/html') and FPostItem.Test(c0(FeedData));
end;

procedure THTMLFeedProcessor1.ProcessFeed(Handler: IFeedHandler;
  const FeedData: WideString);
var
  mc:MatchCollection;
  m:Match;
  sm:SubMatches;
  mci:integer;
  title,url,body:WideString;
  d:TDateTime;
begin
  inherited;
  mc:=FPostItem.Execute(c0(FeedData)) as MatchCollection;
  for mci:=0 to mc.Count-1 do
   begin
    m:=mc[mci] as Match;
    sm:=m.SubMatches as SubMatches;
    //assert sm.Count=5
    try
      d:=ConvDate2(HTMLDecode(sm[1]))
    except
      d:=UtcNow;
    end;
    url:=HTMLDecode(sm[2]);

    //TODO: CombineURL!

    title:=SanitizeTitle(c1(sm[3]));
    body:=c1(FPostBody.Replace(sm[4],''));

    //TODO: id?
    //TODO: image?

    if Handler.CheckNewPost(url,url,d) then
      Handler.RegisterPost(title,body);
   end;
  Handler.ReportSuccess('HTML:1');
end;

{ THTMLFeedProcessor2 }

procedure THTMLFeedProcessor2.AfterConstruction;
begin
  inherited;
  FPostItem:=CoRegExp.Create;
  FPostItem.Global:=true;
  FPostItem.IgnoreCase:=false;//?
  //FPostItem.Pattern:= see Determine
end;

function URLToFileName(const URL:string):string;
var
  i,l:integer;
begin
  i:=1;
  l:=Length(URL);
  //skip 'http://'
  while (i<=l) and (URL[i]<>'/') do inc(i);
  while (i<=l) and (URL[i]='/') do inc(i);
  while (i<=l) and (URL[i]<>'/') do
   begin
    case URL[i] of
      'A'..'Z','a'..'z','0'..'9','-':Result:=Result+URL[i];
      '.':Result:=Result+'_';
    end;
    inc(i);
   end;
end;

function THTMLFeedProcessor2.Determine(Store: IFeedStore;
  const FeedURL: WideString; var FeedData: WideString;
  const FeedDataType: WideString): boolean;
var
  fn:string;
  sl:TStringList;
begin
  FURL:=FeedURL;
  //Store.CheckLastLoadResultPrefix('HTML:2')?

  Result:=false;
  if (FeedDataType='text/html') then
   begin
    fn:='feeds/'+URLToFileName(string(FeedURL))+'.json';
    if FileExists(fn) then
     begin
      FFeedParams:=JSON;
      sl:=TStringList.Create;
      try
        sl.LoadFromFile(fn);
        FFeedParams.Parse(sl.Text);
      finally
        sl.Free;
      end;

      FPostItem.IgnoreCase:=FFeedParams['i']=true;
      FPostItem.Pattern:=FFeedParams['p'];
      Result:=FPostItem.Test(c0(FeedData));

     end;
   end;
end;

procedure THTMLFeedProcessor2.ProcessFeed(Handler: IFeedHandler;
  const FeedData: WideString);
var
  mc:MatchCollection;
  m:Match;
  sm:SubMatches;
  s:string;
  mci,i,n,l:integer;
  title,url,content:WideString;
  d:TDateTime;
  p:IJSONDocument;
begin
  inherited;
  Handler.UpdateFeedName(FFeedTitle);
  mc:=FPostItem.Execute(c0(FeedData)) as MatchCollection;
  for mci:=0 to mc.Count-1 do
   begin
    m:=mc[mci] as Match;
    sm:=m.SubMatches as SubMatches;
    try
      p:=JSON(FFeedParams['pubDate']);
      s:=sm[p['n']-1];

      if p['parse']='1' then d:=ConvDate1(s) else
      if p['parse']='2' then d:=ConvDate2(s) else
      if p['parse']='sloppy' then
       begin

        l:=Length(s);
        i:=1;
        while (i<=l) and not(AnsiChar(s[i]) in ['0'..'9']) do inc(i);
        n:=0;
        while (i<=l) and (AnsiChar(s[i]) in ['0'..'9']) do
         begin
          n:=n*10+(byte(s[i]) and $F);
          inc(i);
         end;
        inc(i);//' '
        s:=Copy(s,i,l-i+1);
        if StartsWith(s,'hour ago') then d:=UtcNow-1.0/24.0 else
        if StartsWith(s,'hours ago') then d:=UtcNow-n/24.0 else
        if StartsWith(s,'day ago') then d:=UtcNow-1.0 else
        if StartsWith(s,'days ago') then d:=UtcNow-n else
        if StartsWith(s,'week ago') then d:=UtcNow-7.0 else
        if StartsWith(s,'weeks ago') then d:=UtcNow-n*7.0 else
        if StartsWith(s,'month ago') then d:=UtcNow-30.0 else
        if StartsWith(s,'months ago') then d:=UtcNow-n*30.0 else
          raise Exception.Create('Unknown time interval');

       end
      else
        raise Exception.Create('Unknown PubDate Parse "'+VarToStr(p['parse'])+'"');

    except
      d:=UtcNow;
    end;

    //TODO FFeedParams['guid']

    p:=JSON(FFeedParams['url']);
    url:=HTMLDecode(sm[p['n']-1]);
    //TODO: CombineURL!


    p:=JSON(FFeedParams['title']);
    title:=sm[p['n']-1];
    if p['trim']=true then title:=Trim(title);
    title:=SanitizeTitle(c1(title));

    p:=JSON(FFeedParams['content']);
    if p=nil then
      content:=''
    else
     begin
      content:=c1(sm[p['n']-1]);
      //more?

      //TODO: absorb THTMLFeedProcessor1 here:
      //TODO: series of replaces

     end;

    p:=JSON(FFeedParams['postThumb']);
    if p<>nil then
     begin
      s:=sm[p['n']-1];
      if s<>'' then
       begin
        content:='<img class="postthumb" referrerpolicy="no-referrer'+
          '" src="'+HTMLEncode(FURL+s)+
          //'" alt="'+???
          '" /><br />'#13#10+content;
       end;
     end;

    if Handler.CheckNewPost(url,FURL+url,d) then
      Handler.RegisterPost(title,content);
   end;
  Handler.ReportSuccess('HTML:P');
end;

initialization
  //RegisterFeedProcessor(THTMLFeedProcessor1.Create);
  RegisterFeedProcessor(THTMLFeedProcessor2.Create);
end.
