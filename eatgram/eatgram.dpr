program eatgram;

uses
  Vcl.Forms,
  eatgram1 in 'eatgram1.pas' {webInstagram},
  eatgram_TLB in 'eatgram_TLB.pas',
  eatgram2 in 'eatgram2.pas' {EaterGram: CoClass};

{$R *.TLB}

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TwebInstagram, webInstagram);
  Application.Run;
end.
