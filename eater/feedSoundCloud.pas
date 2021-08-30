unit feedSoundCloud;

interface

uses eaterReg;

type
  TSoundCloudProcessor=class(TFeedProcessor)
  public
    function Determine(Store:IFeedStore;const FeedURL:WideString;
      var FeedData:WideString;const FeedDataType:WideString):boolean; override;
    procedure ProcessFeed(Handler: IFeedHandler; const FeedData: WideString);
      override;
  end;

implementation

uses SysUtils, Variants, jsonDoc, eaterUtils, MSXML2_TLB;

{ TSoundCloudProcessor }

function TSoundCloudProcessor.Determine(Store: IFeedStore;
  const FeedURL: WideString; var FeedData: WideString;
  const FeedDataType: WideString): boolean;
begin
  Result:=StartsWith(FeedURL,'https://soundcloud.com/')
end;

procedure TSoundCloudProcessor.ProcessFeed(Handler: IFeedHandler;
  const FeedData: WideString);
var
  r:ServerXMLHTTP60;
  j,j1,j2:IJSONDocument;
  jc:IJSONDocArray;
  i:integer;
  s:string;
  id,dur:int64;
  urn,url,title,content:string;
  pubDate:TDateTime;
begin
  inherited;
  j:=JSON;
  j.Parse(FeedData);

  s:=VarToStr(j['kind']);

  if s='user' then
   begin
    id:=j['id'];
    handler.UpdateFeedName('SoundCloud user: '+VarToStr(j['username']));

    //TODO: playlists?

    r:=CoServerXMLHTTP60.Create;
    r.open('GET','https://api-v2.soundcloud.com/users/'+IntToStr(id)+'/tracks?client_id='+SoundCloudClientID,
      false,EmptyParam,EmptyParam);
    r.setRequestHeader('Accept','application/json');
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
      pubDate:=ConvDate1(j1['display_date']);
      //assert j1['kind']='track'
      if Handler.CheckNewPost(urn,url,pubDate) then
       begin
        //TODO: Handler.PostTags(j1['genre']?)tag_list?

        title:=VarToStr(j1['title']);
        dur:=(int64(j1['duration'])+500) div 1000;//full_duration?
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

  //r:=CoServerXMLHTTP60.Create;
  //r.open('GET',
end;

initialization
  RegisterFeedProcessor(TSoundCloudProcessor.Create);
end.
