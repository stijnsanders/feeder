unit feedSoundCloud;

interface

uses eaterReg, MSXML2_TLB;

type
  TSoundCloudProcessor=class(TFeedProcessor)
  public
    function Determine(Store:IFeedStore;const FeedURL:WideString;
      var FeedData:WideString;const FeedDataType:WideString):boolean; override;
    procedure ProcessFeed(Handler: IFeedHandler; const FeedData: WideString);
      override;
  end;

  TSoundCloudRequest=class(TRequestProcessor)
  public
    function AlternateOpen(const FeedURL: string; var LastMod: string;
      Request: ServerXMLHTTP60): Boolean; override;
  end;

implementation

uses SysUtils, Variants, Classes, jsonDoc, eaterUtils, VBScript_RegExp_55_TLB,
  base64;

var
  SC_Token:string;
  SC_Valid:TDateTime;

function SC_AuthToken:string;
var
  sl:TStringList;
  r:ServerXMLHTTP60;
  j:IJSONDocument;
begin
  if SC_Valid<Now then
   begin
    r:=CoServerXMLHTTP60.Create;
    sl:=TStringList.Create;
    try
      sl.LoadFromFile('soundcloud.ini');

      r.open('POST','https://secure.soundcloud.com/oauth/token',false,EmptyParam,EmptyParam);
      r.setRequestHeader('Accept','application/json; charset=utf-8');
      r.setRequestHeader('Content-Type','application/x-www-form-urlencoded');
      r.setRequestHeader('Authorization','Basic '+string(base64encode(
        UTF8Encode((sl.Values['client']+':'+sl.Values['secret'])))));
      r.send('grant_type=client_credentials');
      j:=JSON(r.responseText);
      SC_Token:=j['access_token'];
      SC_Valid:=Now+(j['expires_in']-90)/SecsPerDay;
      //assert j['token_type']='Bearer'
    finally
      sl.Free;
    end;
   end;
  Result:='Bearer '+SC_Token;
end;

{ TSoundCloudProcessor }

function TSoundCloudProcessor.Determine(Store: IFeedStore;
  const FeedURL: WideString; var FeedData: WideString;
  const FeedDataType: WideString): boolean;
begin
  Result:=StartsWith(FeedURL,'https://soundcloud.com/');
end;

procedure TSoundCloudProcessor.ProcessFeed(Handler: IFeedHandler;
  const FeedData: WideString);
var
  r:ServerXMLHTTP60;
  j,j1,j2:IJSONDocument;
  jc:IJSONDocArray;
  i:integer;
  s:string;
  id,dd,dur:int64;
  urn,url,title,content:string;
  pubDate:TDateTime;
begin
  inherited;
  r:=CoServerXMLHTTP60.Create;
  j:=JSON;
  j.Parse(FeedData);

  s:=VarToStr(j['kind']);

  if s='user' then
   begin
    id:=j['id'];
    handler.UpdateFeedName('SoundCloud user: '+VarToStr(j['username']));

    //TODO: playlists?

    r.open('GET','https://api.soundcloud.com/users/'+IntToStr(id)+
      '/tracks'
      +'?access=,playable,preview,blocked&limit=25&linked_partitioning=true'
      ,false,EmptyParam,EmptyParam);
    r.setRequestHeader('Accept','application/json');
    r.setRequestHeader('User-Agent','FeedEater/1.1');
    r.setRequestHeader('Authorization',SC_AuthToken);
    r.send(EmptyParam);

    if r.status<>200 then raise Exception.Create('SoundCloud: can''t get user''s tracks: '+IntToStr(r.status));
    //SaveUTF16('xmls\'+Format('%.4d',[FeedID])+'t.json',r.responseText);

    jc:=JSONDocArray;
    j:=JSON(['collection',jc]);
    j.Parse(r.responseText);
    j1:=JSON;
    for i:=0 to jc.Count-1 do
     begin
      jc.LoadItem(i,j1);
      urn:=j1['urn'];
      url:=j1['permalink_url'];
      //pubDate:=ConvDate1(j1['last_modified']);
      if not(VarIsNull(j1['display_date'])) then
        pubDate:=ConvDate1(j1['display_date'])
      else
        pubDate:=ConvDate1(j1['created_at']);
      //assert j1['kind']='track'
      if Handler.CheckNewPost(urn,url,pubDate) then
       begin
        //TODO: Handler.PostTags(j1['genre']?)tag_list?

        title:=VarToStr(j1['title']);
        dd:=j1['duration'];
        dur:=(dd+500) div 1000;//full_duration?
        if dur>=3600 then
          s:=Format('%d:%.2d:%.2d',[dur div 3600,(dur div 60) mod 60,dur mod 60])
        else
          s:=Format('%d:%.2d',[dur div 60,dur mod 60]);
        content:='<a href="'+url+'"><img src="'+VarToStr(j1['artwork_url'])+'" border="0" /><br />'
         +'<b>'+HTMLEncode(title)+'</b></a> '+s+' # '+VarToStr(j1['genre'])+'<br />'
         +StringReplace(HTMLEncode(VarToStr(j1['description'])),#13#10,'<br />',[rfReplaceAll])
         ;

        //caption
        //label_name

        j2:=JSON(j1['user']);
        if j2<>nil then
         begin
          content:=content+'<br /><br />'
            +'<a href="'+VarToStr(j2['permalink_url'])+'"><img src="'+VarToStr(j2['avatar_url'])+'" border="0" /><br />'
            +VarToStr(j2['username'])
            +'</a>'
            ;
          //city country_code badges
         end;

        Handler.RegisterPost(title,content);
       end;
     end;

    //next_href?

    Handler.ReportSuccess('SoundCloud');
   end

  else
    Handler.ReportFailure('SoundCloud: unsupported kind "'+s+'"');
end;

{ TSoundCloudRequest }

function TSoundCloudRequest.AlternateOpen(const FeedURL: string;
  var LastMod: string; Request: ServerXMLHTTP60): Boolean;
begin
  if StartsWith(FeedURL,'https://soundcloud.com/') then
   begin
    Request.open('GET','https://api.soundcloud.com/resolve?url='+
      string(URLEncode(FeedURL)),false,EmptyParam,EmptyParam);
    Request.setRequestHeader('Accept','application/json');
    Request.setRequestHeader('User-Agent','FeedEater/1.1');
    Request.setRequestHeader('Authorization',SC_AuthToken);
    Result:=true;
   end
  else
    Result:=false;
end;

initialization
  SC_Token:='';
  SC_Valid:=0.0;
  RegisterFeedProcessor(TSoundCloudProcessor.Create);
  RegisterRequestProcessors(TSoundCloudRequest.Create);
end.
