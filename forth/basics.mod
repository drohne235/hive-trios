fl

hex

: mod:basics ;

\ Copyright (c) 2010 Sal Sanci
\ Anpassung für Hive-System 2011 dr235

\ ------------------------------------------------------ BASICS

\ this words needs to align with the assembler code
: _stptr 5 _cv ;
: _sttop 2e _cv ;

\ _words ( cstr -- ) 
: _words lastnfa 
  begin
	2dup swap dup if npfx else 2drop -1 then
	if dup .strname space then 
    nfa>next dup 0=
  until 2drop cr ;

\ words name ( -- ) prints the words in the forth dictionary
: words parsenw _words ;

\ .long ( n -- ) emit 8 hex digits
: .long dup 10 rshift .word .word ;

\ st? ( -- ) prints out the stack
: st? ." ST: " _stptr COG@ 2+ dup _sttop < 
  if _sttop swap - 0 
    do _sttop 2- i -  COG@ .long space loop 
  else drop 
  then cr ;

\ variable ( -- ) skip blanks parse the next word and create 
\ a variable, allocate a long, 4 bytes
: variable 
  lockdict create $C_a_dovarl w, 0 l, forthentry freedict ;

\ constant ( x -- ) skip blanks parse the next word and create 
\ a constant, allocate a long, 4 bytes
: constant 
  lockdict create $C_a_doconl w, l, forthentry freedict ;

\ waitpeq ( n1 n2 -- ) \ wait until state n1 is equal to 
\ ina anded with n2
: waitpeq _execasm2>0 1E0 _cnip ;

\ locknew ( -- n2 ) allocate a lock, result is in n2, -1 
\ if unsuccessful
: locknew -1 4 hubop -1 = if drop -1 then ;

\ (forget) ( cstr -- ) wind the dictionary back to the word 
\ which follows - caution
: (forget) dup
if
	find if
		pfa>nfa nfa>lfa dup here W! W@ wlastnfa W!
	else .cstr 3f emit cr then
else drop then ;

\ forget ( -- ) wind the dictionary back to the word which 
\ follows - caution
: forget parsenw (forget) ;

\ free ( -- ) display free main bytes and current cog longs
: free dictend W@ here W@ - . ." bytes free - " par 
  coghere W@ - . ." cog longs free" cr ;

\ ifnot: name ( -- ) - bedingte compilierung; wenn name schon 
\ im wörterbuch vorhanden, wird bis zum nächsten semikolon
\ der eingabestrom ignoriert
: ifnot: parsenw nip find if begin key 3B = until 
  key drop then ;
\ bei konstrukte, die keine doppelpunkdefinition sind, muss der 
\ block mit diesem Wort abgeschlossen werden  
: :; ;

\ --------------------------------------------------------- BUS

\ bin ( -- ) - umschaltung auf duales zahlensystem
\ : bin 2 base W! ; 
\         +---------------------------- /hs
\         |+--------------------------- /wr
\         ||+-------------------------- busclk
\         |||+------------------------- hbeat
\         ||||+------------------------ al
\         |||||+----------------------- /bel
\         ||||||+---------------------- /adm
\         |||||||+--------------------- /ram2
\         ||||||||+-------------------- /ram1
\         |||||||||          +--------- a0..10
\         |||||||||          |
\         |||||||||          |       +- d0..7
\         |||||||||+---------++------+
\     00000000000000000000000000000000
\ bin 00000111111111111111111100000000 constant dinp hex
\ bin 00000111111111111111111111111111 constant dout hex
\ bin 00000010000000000000000000000000 constant boff hex
\ bin 00000100011110000000000000000000 constant _s1  hex
\ bin 00000000001110000000000000000000 constant _b1  hex
\ bin 00000010001110000000000000000000 constant _b2  hex
\ bin 00000110001110000000000000000000 constant _b3  hex
\ bin 00000000010110000000000000000000 constant _a1  hex
\ bin 00000010010110000000000000000000 constant _a2  hex
\ bin 00000110010110000000000000000000 constant _a3  hex
\ bin 00001000000000000000000000000000 constant ?hs  hex

8000000 constant ?hs

: [inp] \ ( -- ) bus eingabe
  7FFFF00 dira COG! ; \ dinp
  
: [out] \ ( -- ) bus ausgabe
  7FFFFFF dira COG! ; \ dout

: [off] \ ( -- ) bus aus
  2000000 dira COG! 0 outa COG! ;  \ boff
    
: [end] \ ( -- ) buskommunikation beendet
  4780000 outa COG! [inp] ; \ _s1

: [hs=1] \ ( -- ) wartet auf hs = 1
  ?hs dup waitpeq ;

: [hs=0] \ ( -- ) warten auf hs = 0
  0 ?hs waitpeq ;

: [s!] \ ( c ctrl -- ) sende 8 bit an einen slave
  [out] [hs=1] swap ff and or outa COG! [hs=0] [end] ; 

: [s@] \ ( ctrl -- c ) empfängt 8 bit von einem slave
  [inp] [hs=1] outa COG! [hs=0] ina COG@ ff and [end] ;

: [b!] \ ( c -- ) sende 8 bit an bellatrix
  2380000 [s!] ; \ _b2
  
: [a!] \ ( c -- ) sende 8 bit an administra
  2580000 [s!] ; \ _a2

: [b@] \ ( -- c ) empfängt 8 bit von bellatrix
  6380000 [s@] ; \ _b3

: [a@] \ ( -- c ) empfängt 8 bit von administra
  6580000 [s@] ; \ _a3

: <8 \ ( -- ) 
  8 lshift ;

\ [b.l!] ( 32b -- ) - long an bellatrix senden
: [b.l!]
  dup 18 rshift [b!] 
  dup 10 rshift [b!] 
  dup 8  rshift [b!] 
                [b!] ;

\ [b.l@] ( -- 32b ) - long von bellatrix einlesen
: [b.l@]
  [b@]    <8
  [b@] or <8 
  [b@] or <8 
  [b@] or ;

\ [a.s@] ( -- ) - einen cstring von administra empfangen 
\ und im pad speichern
: [a.s@]
  [a@] pad 2dup C! 1+ swap                  
  0 do dup [a@] swap C! 1+ loop drop ;

\ [a.s!] ( cstr -- ) - einen cstring an administra senden
: [a.s!]
  dup C@ dup [a!]       \ ( -- cstr len ) len senden 
  0 do                  \ ( cstr len -- cstr )
    1+ dup C@ [a!]      \ ( cstr -- cstr+1 ) zeichen senden
  loop drop ;           \ ( cstr -- )

\ [a.w@] ( -- 16b ) - 16bit-wert von administra einlesen
: [a.w@]
  [a@] <8 [a@] or ;

\ [a.l!] ( 32b -- ) - long an administra senden
: [a.l!]
  dup 18 rshift [a!] 
  dup 10 rshift [a!] 
  dup 8  rshift [a!] 
                [a!] ;

\ [a.l@] ( -- 32b ) - long von administra einlesen
: [a.l@]
  [a@]    <8
  [a@] or <8 
  [a@] or <8 
  [a@] or ;

wvariable b[lock]       \ nummer der semaphore für den 
                        \ zugriff auf die bus-hardware

\ b[ ( -- ) bus belegen; wartet bis semaphore freigegeben ist
: b[ begin b[lock] W@ lockset -1 <> until [inp] ;
 
\ ]b ( -- ) bus freigeben
\ ! busclk bleibt auf ausgabe, da dieses signal sonst
\ kein definierten pegel besitzt !
: ]b [off] b[lock] W@ lockclr drop ;  

\ administra-kommandoformate

: b[a! b[ [a!] ;
: b[a!a! b[ [a!] [a!] ;
: adm:fkt!     b[a! ]b ;             \ ( fkt -- ) 
: adm:fkt!b@   b[a! [a@] ]b ;        \ ( fkt -- b )
: adm:fkt!b!   b[a!a! ]b ;           \ ( b fkt -- )
: adm:fkt!b!b@ b[a!a! [a@] ]b ;      \ ( b fkt -- b )
: adm:fkt!s@   b[a! [a.s@] ]b ;      \ ( fkt -- )
: adm:fkt!s!b@ b[a! [a.s!] [a@] ]b ; \ ( s fkt -- b ) 
: adm:fkt!b!l@ b[a!a! [a.l@] ]b ;    \ ( b fkt -- l ) 

\ ----------------------------------------------------- SD0.LIB

\ marker-funktionen

\ adm:dmact ( dmnr -- ) - marker aktivieren
: adm:dmact 19 adm:fkt!b!b@ drop ;

\ adm:dmset ( dmnr -- ) - marker setzen
: adm:dmset 1A adm:fkt!b! ;

\ dateisystem-funktionen

\ adm:volname ( -- ) - name des volumes im pad ablegen
: adm:volname 0C adm:fkt!s@ ;

\ adm:mount ( -- err ) - medium mounten
: adm:mount 01 adm:fkt!b@ ;

\ adm:unmount ( -- err ) - medium unmounten  
: adm:unmount 18 adm:fkt!b@ ;
  
\ adm:checkmounted ( -- t/f )
: adm:checkmounted 0D adm:fkt!b@ ;

\ adm:diropen ( -- ) - verzeichnisabfrage initialisieren
: adm:diropen 02 adm:fkt! ;

\ adm:nextfile ( -- st ) 
\ st = 0 - keine gültige datei
\ st = 1 - dateiname im pad gültig 
\ bei gültigem eintrag befindet sich der dateiname im pad
: adm:nextfile b[ 3 [a!] [a@] dup if [a.s@] then ]b ; 

\ adm:fattrib ( nr -- attrib ) - dateiattribut abfragen
: adm:fattrib 0B adm:fkt!b!l@ ;  

\ adm:chdir ( cstr -- err ) - verzeichnis öffnen
: adm:chdir 16 adm:fkt!s!b@ ;

\ adm:getc ( -- c ) - ein zeichen aus der geöffneten datei lesen
: adm:getc 06 adm:fkt!b@ ;

\ adm:eof ( -- eof ) - abfrage ob end of file erreicht ist
: adm:eof 1E adm:fkt!b@ ;

\ adm:open ( cstr modus -- err ) - datei öffnen
\ modus "R" $52 - Read
\ modus "W" $57 - Write
\ modus "A" $41 - Append
: adm:open b[ 4 [a!] [a!] [a.s!] [a@] ]b ;

\ adm:close ( -- ) - datei schließen
: adm:close 05 adm:fkt!b@ ;

\ ----------------------------------------------------- SCR.LIB

\ [dscr] ( scrnr -- ) display-screen setzen
: [dscr] 0 [b!] 59 [b!] [b!] ;

\ [wscr] ( scrnr -- ) schreib-screen setzen
: [wscr] 0 [b!] 58 [b!] [b!] ;

\ [key?] ( -- c ) - ungekapselte tastaturstatusabfrage 
: [key?] 0 [b!] 1 [b!] [b@] ; 

\ [key] ( -- c ) - ungekapselte tastaturabfrage 
: [key] 0 [b!] 2 [b!] [b@] ; 

\ [emit] ( c -- ) - ungekapselte zeichenausgabe
: [emit] emit? if emit then ;

\ ----------------------------------------------------- TOOLS
  
\ cls ( -- ) - screen löschen
: cls 01 emit ;

\ .tab ( -- ) - tabulator
: .tab 09 emit ;

\ .err ( err -- ) - fehlermeldung ausgeben
\ 0    no error
\ 1    fsys unmounted
\ 2    fsys corrupted
\ 3    fsys unsupported
\ 4    not found
\ 5    file not found
\ 6    dir not found
\ 7    file read only
\ 8    end of file
\ 9    end of directory
\ 10   end of root
\ 11   dir is full
\ 12   dir is not empty
\ 13   checksum error
\ 14   reboot error
\ 15   bpb corrupt
\ 16   fsi corrupt
\ 17   dir already exist
\ 18   file already exist
\ 19   out of disk free space
\ 20   disk io error
\ 21   command not found
\ 22   timeout
\ 23   parameter error
: .err dup if ERR then drop ;

\ .pad ( -- ) - ausgabe eines strings im pad
: .pad pad .cstr ;
  
\ .vname ( -- ) - ausgabe des namens der eingelegten sd-card
: .vname adm:volname .pad ;

\ mount ( -- ) - sd-card mounten
: mount adm:mount .err ." Medium : " .vname cr ;

\ unmount ( -- ) - sd-card unmounten
: unmount adm:unmount .err ;

\ mount? ( -- ) - test ob medium mounted ist
\ wird als exception gewertet
: mount? adm:checkmounted 0= if 1 .err then ;
    
\ padbl ( -- ) fills this cogs pad with blanks
: padbl pad padsize bl fill ;

\ .entry ( -- st ) - einen verzeichniseintrag ausgeben
: .entry 
  adm:nextfile 13 adm:fattrib if 0F emit else space then 
  dup if .pad .tab then ;

\ .len ( st -- st ) - dateilänge ausgeben
: .len dup if 0 adm:fattrib . then ;
  
\ lscnt ( cnt1 st -- cnt2 st ) - spaltenformatierung für ls
\ cnt - spaltenzähler, st - flag verzeichnisende
: lscnt 
  swap 1+ dup 4 = if cr drop 0 else .tab then swap ;

\ lsl ( -- ) - verzeichnis anzeigen, long-format
: lsl mount? 
  adm:diropen begin .entry .len cr 0= until padbl ;
 
\ ls ( -- ) -  verzeichnis in spalten anzeigen
: ls mount? 
  adm:diropen 0 begin .entry lscnt 0= until drop padbl cr ;

\ cd name ( -- ) - verzeichnis wechseln
: cd mount? parsenw adm:chdir .err ;

\ open name ( -- ) - datei lesend öffnen und auf fehler prüfen
: open 
  mount? parsenw dup 
  if 52 adm:open else drop 23 then .err ;  

\ close ( -- ) - geöffnete datei schließen
: close adm:close .err ;

\ dload name - datei compilieren; log im gleichen screen
\ load name  - datei compilieren; log screen 3
\ sys name   - datei aus sys compilieren; log screen 3
\ die datei wird in der nächsten freien cog compiliert
\ fl ist für load nicht nötig und bringt in dem kontext
\ die cog-zuordnung durcheinander

: (load)
  begin adm:getc emit adm:eof until ;

: (dload)
  open cogid nfcog iolink 
  (load)
  cogid iounlink close ;

: (sload)
  open cogid 3 dup b[ [wscr] ]b  iolink
  (load)
  cogid dup b[ [wscr] ]b iounlink close ;
  
: load
  ." Loading... " (sload) ; 
  
: dload
  (dload) ;

: sys
  2 adm:dmset 1 adm:dmact ." Loading... " (sload) 2 adm:dmact ; 

\ ------------------------------------------------- SPIN-LOADER

\ (spin) ( cstr -- ) - c" reg.sys" (spin)
: (spin)
  dup C@ 1+
  0 do
    dup i + C@
    ldvar 1+ i + C!
  loop drop 
  1 ldvar C! 
;

\ spin name ( -- ) - spinobjekt "name" starten
: spin
  parsenw (spin) ;

\ regime  ( -- ) - startet dir trios-cli "regime"
: regime
  0 adm:dmact
  c" reg.sys" (spin) ; 

\ ----------------------------------------------------- DRV:INT


wvariable icog           \ nummer der drv:int-cog
wvariable lcog           \ nummer interaktiven cog

\ xint ( n -- ) io von cog n auf drv:int umschalten
: xint icog W@ ioconn ;  

\ [cogscr] ( nr -- ) - umschaltung screen + cog 
: [cogscr] 
  dup 2dup lcog W! xint [dscr] [wscr] ;       

\ =n ( n1 n2 -- n1 n1=n2 ) 
: =n  2dup = swap drop ;

\ [esc] ( -- ) - manager für esc-funktionen im drv:int
: [esc] 
  begin [key?] until [key] 
  71 =n if 1b [emit]        then \ esc - q   : esc-char/quit
  31 =n if 1 [cogscr]       then \ esc - 1   : cog-screen 0
  32 =n if 2 [cogscr]       then \ esc - 2   : cog-screen 1
  33 =n if 3 [cogscr]       then \ esc - 3   : cog-screen 2
  62 =n if lcog W@ cogreset then \ esc - b   : break (cog)
  72 =n if reboot           then \ esc - r   : reset (chip)
  drop ;                         \ esc - esc : pause

\ drv:int ( -- ) treiber für bellatrix-terminal 
\ diese cog fragt in einer endlosschleife ab, ob zeichen 
\ versendet oder empfangen werden sollen. um die zeichenausgabe 
\ zu beschleunigen, findet ausgabe und eingabe in einem 
\ verhältnis von 512:1 statt. per esc-code können spezielle 
\ funktionen im driver ausgelöst werden.
: drv:int
  \ name und typ der cog einstellen
  cogid dup cogstate 10 swap C! c" drv:int" over 
  cognumpad ccopy
  20 delms 0D emit               \ verzögertes cr für prompt
  begin
    \ input --> vga/video
    200 0 do key?                \ eingabezeichen vorhanden?
    if key b[ [b!] ]b then loop  \ cog ---> bel.vga
    \ output <-- keyboard
    b[ [key?]                    \ tastenstatus bellatrix?
    if [key] dup 1b = if drop [esc] else [emit] thens ]b
  0 until ;

\ ----------------------------------------------------- SYSINIT

: start \ ( -- ) initialisierung hive 
  locknew b[lock] W!            \ b-semaphore 
  0 dup cogstate 10 swap C! c" drv:ldr" over 
  cognumpad ccopy 
  5 dup icog W! c" drv:int" swap cogx 1 b[ [cogscr] ]b ;
: _ob onboot ;
: onboot _ob start ;

saveforth

reboot



