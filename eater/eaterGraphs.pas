unit eaterGraphs;

interface

uses SysUtils, DataLank;

procedure DoGraphs(db:TDataConnection);

implementation

uses eaterUtils, Windows, Classes, Graphics, Vcl.Imaging.PngImage;

procedure DoGraphs(db:TDataConnection);
const
  bw=60;
  bh=40;
  fw=2;
  fh=1;
var
  qr:TQueryResult;
  sl:TStringList;
  s:string;
  UserID,tz,si,i,d,d1:integer;
  q1,q3,qi:cardinal;
  TimeBias:TDateTime;
  b:TBitmap;
  p:TPngImage;
  v:array[0..bw-1] of record
    t1,t2:cardinal;
  end;
begin
  OutLn('Generating post volume graphs...');
  sl:=TStringList.Create;
  try
    qr:=TQueryResult.Create(db,
      'select L.key,L.user_id,U.timezone'//,L.chart?
      +' from "UserLogon" L inner join "User" U on U.id=L.user_id where L.chart is not null',
      []);
    try
      while qr.Read do
        sl.Add(Format('%s%.8d%.8d',
          [StringReplace(Copy(qr.GetStr('key'),1,14),'/','=',[rfReplaceAll])
          ,qr.GetInt('user_id')
          ,qr.GetInt('timezone')
          ]));
    finally
      qr.Free;
    end;

    for si:=0 to sl.Count-1 do
     begin
      s:=sl[si];
      Write(#13+s);
      UserID:=StrToInt(Copy(s,15,8));
      tz:=StrToInt(Copy(s,23,8));

      TimeBias:=(tz div 100)/24.0+(tz mod 100)/1440.0;

      qr:=TQueryResult.Create(db,
        'select trunc(P.pubdate+T.bias) as d, count(*) as q1, count(X.id) as q2, count(distinct S.feed_id) as q3'
        +' from "Subscription" S cross join (values ($1)) T(bias)'
        +' inner join "Post" P on P.feed_id=S.feed_id'
        +' left outer join "UserPost" X on X.user_id=S.user_id and X.post_id=P.id'
        +' where S.user_id=$2 group by trunc(P.pubdate+T.bias)'
        +' order by 1 desc limit '+IntToStr(bw),[double(TimeBias),UserID]);
      try
        i:=0;
        d:=0;
        q1:=0;
        //q2:=0;
        q3:=0;
        while (i<bw) do
         begin
          if qr.Read then d1:=qr.GetInt('d') else d1:=0;
          if (d1<>0) and ((d=0) or (d=d1)) then
           begin
            d:=d1;
            v[i].t1:=qr.GetInt('q1');
            v[i].t2:=qr.GetInt('q2');
            qi:=qr.GetInt('q3');
            if q1<v[i].t1 then q1:=v[i].t1;
            //if q2<v[i].t2 then q2:=v[i].t2;
            if q3<qi then q3:=qi;
           end
          else
           begin
            v[i].t1:=0;
            v[i].t2:=0;
           end;
          inc(i);
          if d<>0 then dec(d);
         end;
      finally
        qr.Free;
      end;

      b:=TBitmap.Create;
      try
        b.PixelFormat:=pf32bit;
        b.Canvas.Brush.Color:=$000000;
        b.SetSize(bw*fw,bh*fh);
        b.Canvas.Pen.Width:=0;
        d1:=bh*fh-1;
        for i:=0 to bw-1 do
         begin
          d:=bw-i-1;
          if v[i].t1<>0 then
           begin
            b.Canvas.Brush.Color:=$00CCFF;
            b.Canvas.FillRect(Rect(d*fw,d1-Round(v[i].t1/q1*d1),(d+1)*fw,bh*fh));
           end;
          if v[i].t2<>0 then
           begin
            b.Canvas.Brush.Color:=$0000CC;
            b.Canvas.FillRect(Rect(d*fw,d1-Round(v[i].t2/q1*d1),(d+1)*fw,bh*fh));
           end;
         end;
        b.Canvas.Font.Name:='Verdana';
        b.Canvas.Font.Height:=-10;
        b.Canvas.Font.Color:=$CC6600;
        b.Canvas.Brush.Style:=bsClear;
        b.Canvas.TextOut(2,bh*fh-12,Format('%d (%d)',[q1,q3]));
        p:=TPngImage.Create;
        try
          p.Assign(b);
          p.SaveToFile('..\charts\'+Copy(s,1,14)+'.png');
        finally
          p.Free;
        end;
      finally
        b.Free;
      end;
     end;
    Write(#13);
    OutLn(IntToStr(sl.Count)+' charts generated');
  finally
    sl.Free;
  end;
end;

end.
