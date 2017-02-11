
: mod:vortrag ;

24 constant rows 
64 constant cols 

wvariable lcol 7 lcol W!

ifnot: adm:fkt!s!b@   \ ( s fkt -- b )
: adm:fkt!s!b@ b[ [a!] [a.s!] [a@] ]b ;
ifnot: adm:fkt!b!b@     \ ( b fkt -- b )
: adm:fkt!b!b@ b[ [a!] [a!] [a@] ]b ;
ifnot: adm:fkt!b@     \ ( fkt -- b )
: adm:fkt!b@ b[ [a!] [a@] ]b ;

ifnot: bel:char        \ ( b -- )
: bel:char b[ [b!] ]b ;
ifnot: bel:ctrl!b!     \ ( b ctrl -- )
: bel:ctrl!b! b[ 0 [b!] 3 [b!] [b!] [b!] ]b ;
ifnot: bel:fkt!b!b!    \ ( b b fkt -- )
: bel:fkt!b!b! b[ 0 [b!] [b!] [b!] [b!] ]b ;

ifnot: scr:bs      \ ( -- ) - backspace  
: scr:bs 08 bel:char ;
ifnot: scr:tab     \ ( -- ) - tabulator
: scr:tab 09 bel:char ;
ifnot: scr:pos1    \ ( -- ) - cursor an zeilenanfang  
: scr:pos1 03 bel:char ;
ifnot: scr:setcol  \ ( colnr -- ) - farbe wählen 0..15
: scr:setcol 06 bel:ctrl!b! ; 
ifnot: scr:sline   \ ( row -- ) - anfangszeile scrollbereich
: scr:sline 07 bel:ctrl!b! ; 
ifnot: scr:setx    \ ( x -- ) - cursor position x setzen  
: scr:setx 02 bel:ctrl!b! ; 
ifnot: scr:sety    \ ( y -- ) - cursor position y setzen 
: scr:sety 03 bel:ctrl!b! ; 
ifnot: scr:curon   \ ( -- ) - cursor anschalten
: scr:curon 04 bel:char ;
ifnot: scr:curoff  \ ( -- ) - cursor abschalten
: scr:curoff 05 bel:char ;
ifnot: scr:logo    \ ( y x -- ) - hive logo  
: scr:logo 5 bel:fkt!b!b! ; 

\ adm:setsound ( sfkt -- sstat ) - soundsystem verwalten
\ sfkt:
\ 0: hss-engine abschalten
\ 1: hss-engine anschalten
\ 2: dac-engine abschalten
\ 3: dac-engine anschalten
\ sstat  - status/cognr startvorgang
ifnot: adm:setsound
: adm:setsound
  5C adm:fkt!b!b@ ;

\ wav:start ( cstr -- err )
ifnot: wav:start
: wav:start
  96 adm:fkt!s!b@ ;

\ wav:stop ( -- )
ifnot: wav:stop
: wav:stop
  97 adm:fkt!b@ drop ;

\ won
ifnot: won
: won
  0 adm:setsound 3 adm:setsound 2drop ;

\ woff 
ifnot: woff
: woff
  2 adm:setsound 1 adm:setsound 2drop ; 

: lcol@ lcol W@ ; \ ( -- col )

: lines \ ( n -- )
  0 do cr loop ;
  
: waitkey
  scr:curoff cr key drop scr:bs scr:bs scr:bs scr:curon ; 

: nextpage
  scr:curoff scr:pos1 lcol@ spaces ." -->" key drop scr:bs scr:bs scr:bs scr:curon ; 
  
: .head \ ( -- )
  4 scr:setcol scr:pos1 lcol@ spaces ;
  
: .bullet \ ( -- )
  0 scr:setcol scr:pos1 lcol@ spaces 0f emit space ;

: .number \ ( n -- n )
  0 scr:setcol scr:pos1 lcol@ spaces dup . 1+ 
  2e emit space ;

: .line \ ( -- )
  cr 0 scr:setcol scr:pos1 lcol@ 2+ spaces ;

: .sub \ ( -- )
  0 scr:setcol scr:pos1 lcol@ 2+ spaces ;

wvariable xpos 1 xpos W!
wvariable ypos 1 ypos W!
  
: pos! \ ( x y -- )
  ypos W! xpos W! ;
  
: pos@ \ ( -- x y )
  xpos W@ ypos W@ ;
  
: nextline
  ypos W@ 1+ ypos W! ;  

: move \ ( x y -- )
  1 delms pos@ scr:sety scr:setx ;

  
: btop0 \ ( -- )
  move 9f emit 6 0 do 90 emit loop 9e emit nextline ;
  
: bbot0 \ ( -- )
  move 9d emit 6 0 do 90 emit loop 9c emit nextline ;

: btop1 \ ( -- )
  move 2 spaces 9f emit 6 0 do 90 emit loop 9e emit nextline ;
  
: bbot1 \ ( -- )
  move 2 spaces 9d emit 6 0 do 90 emit loop 9c emit nextline ;

: bmid0 \ ( -- )
  move 91 emit ." COG   " 95 emit 90 emit bb emit nextline
  move 91 emit ."       " 95 emit 90 emit aa emit nextline ;

: bmid1 \ ( -- )
  move a9 emit 90 emit 94 emit ." COG   " 91 emit nextline
  move ba emit 90 emit 94 emit ."       " 91 emit nextline ;

: bmid2 \ ( -- )
  move a9 emit 90 emit 94 emit ." SER   " 
  95 emit 90 emit bb emit ."  [TERMINAL]" nextline
  move ba emit 90 emit 94 emit ."       " 91 emit nextline ;

: bmid3 \ ( -- )
  move a9 emit 90 emit 94 emit ." VGA   " 
  95 emit 90 emit bb emit ."  [BELLATRIX]" nextline
  move ba emit 90 emit 94 emit ." KBD   " 91 emit nextline ;

: bmid4 \ ( -- )
  move 91 emit ." COG   " 95 emit 90 emit bb emit 
  ."  Zeichenausgabekanal (emit)" nextline
  move 91 emit ."       " 95 emit 90 emit aa emit 
  ."  Zeicheneingabekanal (key)" nextline ;

: cog0 \ ( x y -- )
  0 scr:setcol pos! btop0 bmid0 bbot0 ;  

: cog1 \ ( x y -- )
  0 scr:setcol pos! btop1 bmid1 bbot1 ;  

: cog3 \ ( x y -- )
  0 scr:setcol pos! btop0 bmid4 bbot0 ;  

: cogext \ ( x y -- )
  0 scr:setcol pos! btop1 bmid2 bbot1 ;  

: cogint \ ( x y -- )
  0 scr:setcol pos! btop1 bmid3 bbot1 ;  

: drvser
  0 scr:setcol 2dup cog0 swap a + swap cogext ;

: drvint
  0 scr:setcol 2dup cog0 swap a + swap cogint ;  
  
: p0
  0 scr:sline cls 5 lines
  14 1c scr:curoff scr:logo won c" woodz.wav" wav:start drop 
  key drop scr:curon wav:stop woff ;

: i1
  0 scr:sline cls 3 lines
  .head   ." Implementierungsvarianten" cr waitkey
  .bullet ." Forth-Diamond: Master & Slaves = PropForth" waitkey cr
  .sub    ."   Nachteil: Programmierung aller Treiber in Forth" waitkey cr
  .bullet ." Forth-Spin: Forth mit SPIN-Interface" waitkey cr
  .sub    ."   Vorteil:  Nutzung fertiger Treiber" waitkey 
  .sub    ."   Nachteil: hoher Ressourcenverbrauch" waitkey cr
  .bullet ." Forth-Funktionskomplexe: " cr cr
  .sub    ."   Master = Forth" cr
  .sub    ."   Slaves = Spin-Funktionsbibliotheken" cr
  .sub    ."   Interface Forth <--> Spin = 8Bit-Bus" cr cr
  nextpage ;

: i2
  0 scr:sline cls 3 lines
  .head   ." Implementierungsvarianten" cr cr
  .bullet ." Forth-Funktionskomplexe: " cr cr
  .sub    ."   Master = Forth" cr
  .sub    ."   Slaves = Spin-Funktionsbibliotheken" cr
  .sub    ."   Interface Forth <--> Spin = 8Bit-Bus" cr waitkey
  .bullet ." Nachteile:" cr cr
  .sub    ."   Spin --> Compiler noch auf Host" cr waitkey
  .bullet ." Vorteile:" cr cr
  .sub    ."   Code ist schon vorhanden (TriOS)" waitkey
  .sub    ."   Gegenseitige Befruchtung von Forth & TriOS" waitkey
  .sub    ."   Maximale Ressourcen für Forth im Master" waitkey
  .sub    ."   Spin-Code kann später auch durch Forth ersetzt werden" cr
  nextpage ;

: i3
  0 scr:sline cls 3 lines
  .head   ." Ablauf der Implementierung" cr waitkey
  .bullet ." Ausgangslage: " cr cr
  .sub    ."   Forth mit Terminalzugriff" cr waitkey
  .bullet ." Plan:" cr cr
  .sub    ." 1. Busroutine um auf Slaves zuzugreifen" waitkey
  .sub    ." 2. Integration VGA/Keyboard/SD-Card" waitkey
  .sub    ." 3. Autostart" cr cr
  nextpage ;
  
  
: p1
  0 scr:sline cls 1 lines
  .head   ." Buszugriff" cr cr
  .bullet ." !   ( n adr -- ) store - Wert im RAM speichern" cr
  .bullet ." @   ( adr -- n ) fetch - Wert aus RAM lesen" cr waitkey
  .bullet ." c! c@ p! p@  - Abwandlungen der Grundform" cr waitkey
  .bullet ." s!  ( c adr -- ) - Byte an Slave senden" cr
  .bullet ." s@  ( adr -- c ) - Byte von Slave empfangen" cr waitkey
  .bullet ." b!  ( c -- ) - Byte an Bellatrix senden" cr
  .bullet ." b@  ( -- c ) - Byte von Bellatrix empfangen" cr
  .bullet ." a!  ( c -- ) - Byte an Administra senden" cr
  .bullet ." a@  ( -- c ) - Byte von Administra empfangen" cr cr 
  .head   ." Beispiele :" cr cr
  .bullet   ."   01 b! - Bildschirm löschen" waitkey
  .bullet   ."   : cls 01 b! ; " waitkey
  .bullet   ."   : bel:key 0 b! 2 b! b@ ; \ ( -- key )" cr
  nextpage ;

: p2
  0 scr:sline cls 5 lines
  .head   ." IO-Kanäle/Pipes" cr waitkey
  9 8  cog3 key drop
  9 c  cog3
  .line ." ..."
  9 11 cog3
  cr cr
  nextpage ;

: p3
  0 scr:sline cls 5 lines
  .head   ." Serieller Treiber" cr cr
  9 8 drvser
  9 c  cog3
  .line ." ..."
  9 11 cog3
  cr cr
  nextpage ;
  
: p4
  0 scr:sline cls 5 lines
  .head   ." VGA/Keyboard-Treiber" cr cr
  9 8 drvser
  9 c drvint
  .line ." ..."
  9 11 cog3
  cr cr
  nextpage ;

: p5  
  0 scr:sline cls 5 lines
  .head   ." Treiber: VGA" cr cr
  9 8 drvint cr
  .line ." : drv-vga " 
  .line ."   begin" 
  .line ."     key?"
  .line ."     if key b! then" 
  .line ."   0 until ;" 
  cr cr
  nextpage ;
  
: p6  
  0 scr:sline cls 5 lines
  .head   ." Treiber: Keyboard" cr cr
  9 8 drvint cr
  .line ." : drv-key" 
  .line ."   begin" 
  .line ."     bel:keystat" 
  .line ."     if bel:key emit then" 
  .line ."   0 until ;" 
  cr cr
  nextpage ;
  
: p7  
  0 scr:sline cls 5 lines
  .head   ." Treiber: Gesamt" cr cr
  9 8 drvint cr
  .line ." : drv:int" 
  .line ."   begin" 
  .line ."     \ input --> vga/video" 
  .line ."    200 0 do key?" 
  .line ."     if key b[ [b!] ]b then loop" 
  .line ."     \ output <-- keyboard" 
  .line ."     b[ [key?]" 
  .line ."     if [key] [emit] then ]b"              
  .line ."   0 until ;" 
  cr cr
  nextpage ;
  
: p8  
  0 scr:sline cls 5 lines
  .head   ." Semaphoren" cr waitkey
  .bullet ." : bel:key 0 b! 2 b! b@ ; \ ( -- key )" cr waitkey
  .bullet ." : bel:key bon 0 b! 2 b! b@ boff ;" cr waitkey
  .bullet ." [ ... ]" cr waitkey
  .bullet ." b[ ... ]b" cr waitkey
  .bullet ." : bel:key b[ 0 b! 2 b! b@ ]b ;" cr waitkey 
  .bullet ." : bel:key b[ 0 [b!] 2 [b!] [b@] ]b ;" cr waitkey 
  .bullet ." : bel:key 2 0 b[ [b!] [b!] [b@] ]b ;" cr cr 
  cr cr
  nextpage ;

: run
  begin p0 i1 i2 i3 p1 p2 p3 p4 p5 p6 p7 p8 0 until ;

