unit feedRemix;

interface

uses eaterReg;

type
  TRemixContentProcessor=class(TFeedProcessor)
  private
    FURLPrefix:string;
  public
    function Determine(Store:IFeedStore;const FeedURL:WideString;
      var FeedData:WideString;const FeedDataType:WideString):boolean; override;
    procedure ProcessFeed(Handler: IFeedHandler; const FeedData: WideString);
      override;
  end;

implementation

uses SysUtils, jsonDoc, eaterSanitize, Variants, eaterUtils;

function JStoJSON(const Data:WideString):WideString;
var
  i,l,r:integer;
  s:WideChar;
begin
  l:=Length(Data);
  SetLength(Result,l+$100);
  i:=1;
  r:=0;
  s:=#0;
  while (i<=l) do
   begin
    if s=#0 then
      case Data[i] of
        #0..#32,'{','}','[',']',',',':','0'..'9','.':
         begin
          inc(r);Result[r]:=Data[i];
         end;
        '"',''''://Start string
         begin
          s:=Data[i];
          inc(r);Result[r]:='"';
         end;
        'f'://true?
          if Copy(Data,i,5)='false' then
           begin
            inc(r);Result[r]:='f';
            inc(r);Result[r]:='a';
            inc(r);Result[r]:='l';
            inc(r);Result[r]:='s';
            inc(r);Result[r]:='e';
            inc(i,4);
           end
          else
            i:=l;//??
        'n'://null?
          if Copy(Data,i,4)='null' then
           begin
            inc(r);Result[r]:='n';
            inc(r);Result[r]:='u';
            inc(r);Result[r]:='l';
            inc(r);Result[r]:='l';
            inc(i,3);
           end
          else
            i:=l;//??
        't'://true?
          if Copy(Data,i,4)='true' then
           begin
            inc(r);Result[r]:='t';
            inc(r);Result[r]:='r';
            inc(r);Result[r]:='u';
            inc(r);Result[r]:='e';
            inc(i,3);
           end
          else
            i:=l;//??
        'u'://undefined?
          if Copy(Data,i,9)='undefined' then
           begin
            inc(r);Result[r]:='n';
            inc(r);Result[r]:='u';
            inc(r);Result[r]:='l';
            inc(r);Result[r]:='l';
            inc(i,8);
           end
          else
            i:=l;//??
        else
          ///
          i:=l;//?raise Exception.Create(Copy(Data,i,100));
      end
    else
      case Data[i] of
        '"','''':
          if Data[i]=s then
           begin
            s:=#0;
            inc(r);Result[r]:='"';
           end
          else
           begin
            inc(r);Result[r]:='\';
            inc(r);Result[r]:=Data[i];
           end;
        '\':
          if (i<l) and (Data[i+1]='''') then
           begin
            inc(i);
            inc(r);Result[r]:=Data[i];
           end
          else
           begin
            inc(r);Result[r]:=Data[i];
            inc(i);
            inc(r);Result[r]:=Data[i];
           end
        else
         begin
          inc(r);Result[r]:=Data[i];
         end;
      end;
    inc(i);
   end;
  SetLength(Result,r);
end;

{ TRemixContentProcessor }

function TRemixContentProcessor.Determine(Store: IFeedStore;
  const FeedURL: WideString; var FeedData: WideString;
  const FeedDataType: WideString): boolean;
begin
  FURLPrefix:=FeedURL+'article/';//from data?
  Result:=Store.CheckLastLoadResultPrefix('Remix') and
    FindPrefixAndCrop(FeedData,'window\.__remixContext = ');
end;

procedure TRemixContentProcessor.ProcessFeed(Handler: IFeedHandler;
  const FeedData: WideString);
var
  jarts,jauthor:IJSONDocArray;
  jdoc,j1,j2,j3:IJSONDocument;
  itemid,itemurl,author:string;
  pubDate:TDateTime;
  title,content:WideString;
  art_i:integer;
begin
  jarts:=JSONDocArray;
  jdoc:=JSON(['routeData{','routes/index{','content{','articlesList',jarts,'}}}']);
  try
    jdoc.Parse(JStoJSON(FeedData));
  except
    on EJSONDecodeException do
      ;//ignore "data past end"
  end;

  //Handler.UpdateFeedName( routeData.'routes/index'.content.tagline?

  //routeData.'routes/index'.content.coverStory?
  //routeData.'routes/index'.content.layouts[].content.article*?

  jauthor:=JSONDocArray;
  j1:=JSON(['author',jauthor]);
  for art_i:=0 to jarts.Count-1 do
   begin
    jarts.LoadItem(art_i,j1);

    itemid:=j1['_id'];
    itemurl:=FURLPrefix+JSON(j1['slug'])['current'];
    try
      pubDate:=ConvDate1(VarToStr(j1['publishedAt']));
    except
      pubDate:=UtcNow;
    end;

    if handler.CheckNewPost(itemid,itemurl,pubDate) then
     begin
      title:=SanitizeTitle(j1['title']);
      content:='';//?
      if jauthor.Count=0 then
        author:=''
      else
        author:=JSON(jauthor[0])['name'];
      j2:=JSON(j1['featuredImage']);
      j3:=JSON(j2['asset']);
      if j3<>nil then content:=content
        +'<p><img class="postthumb" referrerpolicy="no-referrer" src="'
        +HTMLEncode(JSON(j2['asset'])['url'])
        +'" alt="'+HTMLEncode(VarToStr(j2['alt']))+'" /></p>'
        ;
      j2:=JSON(j1['color']);
      if j2=nil then j2:=JSON(['color','#FFFFFF']);
      content:=content
        +'<p><span style="background-color:'+j2['value']+'">&emsp;</span>'
        +' <i>'+HTMLEncode(author)+'</i></p>'
        ;
      Handler.RegisterPost(title,content);
     end;
   end;
  Handler.ReportSuccess('Remix');
end;

initialization
  RegisterFeedProcessor(TRemixContentProcessor.Create);
end.
