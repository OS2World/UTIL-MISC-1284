program i1284_info;

uses crt;


{

The following code is based on the IEEE-1284 probe code from Linux, which was
written by Phil Blundell, Carsten Gross and Jose Renau.

The Turbo Pascal *implementation* is entirely my own creation.


version 1.1 : bugfix. Timing of signals in 'second check' found to work OK
for HP Laserjet 5L, but not for Canon BJ-210. Re-worked code to be compatable
with both types of printers. I assume this is an anomalie with the Linux
code, since the order of operations was copied from there.


}

var
  q,
  y,
  z 	: byte;

  r 	: array[0..1023] of char;

  i,
  s 	: integer;

  f,
  quit 	: boolean;



function wait(mask,result:byte) : boolean;	{ wait 35ms for response }
var
  x,
  i 	: byte;

begin
  i:=1;
  repeat
    x:=port[$379];
    inc(i);
    delay(1);
  until ((x and mask)=result) or (i=40);	{ 40 = small error margin }
  if i<40 then wait:=true else wait:=false;
end;


function read_nibble : byte;			{ read 4 bits of info }
var
  z 	: byte;

begin
  z:=(port[$379] shr 3) and $f7;
  if z and $10=0 then z:=z or 8;
  read_nibble:=z and $f;
end;


begin
  clrscr;
  writeln('IEEE-1284 Parallel port device scan.');
  writeln;

  port[$378]:=4;				{ request info command }
  delay(5);
  port[$37a]:=port[$37a] and $f7;		{ sel in low }
  port[$37a]:=port[$37a] or 2;			{ autofeed high }
  if wait($78,$38) then
  begin
    writeln('Passed initial check. An IEEE-1284 device is present.');

    port[$37a]:=port[$37a] or 1;		{ strobe high }
    port[$37a]:=port[$37a] and $fd;		{ autofeed low }
    delay(5);
    port[$37a]:=port[$37a] and $fe;		{ stobe low }
    delay(5);
    if wait($20,0) then
    begin
      writeln('Passed second check. Device ID is readable.');
      f:=false;
      quit:=false;
      s:=0;					{ s=index into array r() }
      delay(10);
      repeat
        port[$37a]:=port[$37a] or $2;		{ autofeed high }
        if not wait($40,0) then
        begin
          writeln('Read1 timeout!');
          port[$37a]:=port[$37a] and $fd;	{ autofeed low }
          quit:=true;
        end;
        y:=read_nibble;				{ get 4 bits }
        port[$37a]:=port[$37a] and $fd;		{ autofeed low }
        if not wait($40,$40) then
        begin
          writeln('Read2 timeout!');
          quit:=true;
        end;
        if f then				{ f signals when a byte is }
        begin					{ ready - each 2 passes }
          f:=not f;
          q:=q + y shl 4;
          r[s]:=chr(q);
          inc(s);
          if port[$379] and 8=8 then quit:=true; { eof? }
        end else
        begin
	  f:=not f;
	  q:=y;
        end;
        if s>1023 then quit:=true;		{ out of table space ? }
      until quit;
      port[$37a]:=(port[$37a] and $fd) or 8;	{ terminate read }
      if wait($80,0) then writeln('ID Read terminated OK')
        else writeln('ID Read terminated with error!');

{ Display Result, nicely formatted }

      writeln;
      writeln('Size our count : ',s);
      writeln('Size returned  : ',integer(ord(r[0]) shl 8+ord(r[1])));
      write('Info returned  : ');
      for i:=2 to s do
      begin
        if r[i]=';' then
	begin
	  writeln;
          write('                 ');
        end else write(r[i]);
      end;
      writeln;
      writeln;
    end else writeln('Failed second check. No device ID Readable.');

  end else
  begin
    writeln('Failed initial check. No IEEE-1284 device detected.');
     port[$37a]:=((port[$37a] and $fd) or 8);	{ reset port }
  end;

end.
