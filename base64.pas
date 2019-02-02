unit base64;

interface

uses Classes;

function base64encode(const x:UTF8String):UTF8String;

implementation

const
  Base64Codes:array[0..63] of AnsiChar=
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

function base64encode(const x:UTF8String):UTF8String;
type
  TBArr=array[0..0] of byte;
  PBArr=^TBArr;
var
  i,l:integer;
  d:PBArr;
begin
  i:=0;
  l:=Length(x);
  d:=@x[1];
  while i<l do
   begin
    if i+1=l then
      Result:=Result+UTF8String(
        Base64Codes[  d[i  ] shr  2]+
        Base64Codes[((d[i  ] and $3) shl 4)]+
        '==')
    else if i+2=l then
      Result:=Result+UTF8String(
        Base64Codes[  d[i  ] shr  2]+
        Base64Codes[((d[i  ] and $3) shl 4) or (d[i+1] shr 4)]+
        Base64Codes[((d[i+1] and $F) shl 2)]+
        '=')
    else
      Result:=Result+UTF8String(
        Base64Codes[  d[i  ] shr  2]+
        Base64Codes[((d[i  ] and $3) shl 4) or (d[i+1] shr 4)]+
        Base64Codes[((d[i+1] and $F) shl 2) or (d[i+2] shr 6)]+
        Base64Codes[  d[i+2] and $3F]);
    inc(i,3);
    //if (((i-1) mod 57)=0) then Result:=Result+#13#10;
   end;
end;

end.
