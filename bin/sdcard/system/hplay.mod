
hex

ifnot: mod:hplay
: mod:hplay ;

\ kommandoformate

ifnot: adm:fkt!         \ ( fkt -- )
: adm:fkt! b[ [a!] ]b ;

ifnot: adm:fkt!b!       \ ( b fkt -- )
: adm:fkt!b! b[ [a!] [a!] ]b ;

ifnot: adm:fkt!b!w@     \ ( b fkt -- w )
: adm:fkt!b!w@ b[ [a!] [a!] [a.w@] ]b ;

ifnot: adm:fkt!s!b@     \ ( cstr fkt -- b )
: adm:fkt!s!b@ b[ [a!] [a.s!] [a@] ]b ;

ifnot: bel:fkt!b@  \ ( fkt -- b ) 
: bel:fkt!b@ b[ 0 [b!] [b!] [b@] ]b ;  

ifnot: bel:char        \ ( b -- )
: bel:char b[ [b!] ]b ;

\ hss-funktionen

ifnot: hss:load     \ ( cstr -- err ) - hss-datei laden
: hss:load dup if 64 adm:fkt!s!b@ then ;

ifnot: hss:play     \ ( -- ) - datei im puffer abspielen
: hss:play 65 adm:fkt! ; 

ifnot: hss:stop     \ ( -- ) - player stop  
: hss:stop 66 adm:fkt! ;

ifnot: hss:reg      \ hreg ( regnr -- 16b )
: hss:reg 69 b[ [a!] [a!] [a.w@] ]b ;

ifnot: hss:vol      \ hvol ( vol -- ) - lautstärke 0..15
: hss:vol 6A adm:fkt!b! ;

\ keyboard-funktionen

ifnot: key:stat    \ ( -- stat ) - tastenstatus abfragen 
: key:stat 1 bel:fkt!b@ ;

\ steuerzeichen

ifnot: scr:cls     \ ( -- ) - screen löschen
: scr:cls 01 bel:char ;

ifnot: scr:home    \ ( -- ) - cursor oben links
: scr:home 02 bel:char ;

ifnot: scr:curon   \ ( -- ) - cursor anschalten
: scr:curon 04 bel:char ;

ifnot: scr:curoff  \ ( -- ) - cursor abschalten
: scr:curoff 05 bel:char ;

\ sd0-funktionen

\ adm:diropen ( -- ) - verzeichnisabfrage initialisieren
ifnot: adm:diropen
: adm:diropen
  02 adm:fkt! ;

\ adm:nextfile ( -- st ) 
\ st = 0 - keine gültige datei
\ st = 1 - dateiname im pad gültig 
\ bei gültigem eintrag befindet sich der dateiname im pad
ifnot: adm:nextfile
: adm:nextfile 
  b[ 03 [a!] [a@] dup if [a.s@] then ]b ; 

\ metafunktionen

\ hload name ( -- ) - hss-datei in player laden

ifnot: hload
: hload mount? parsenw hss:load .err ;

ifnot: .hset
: .hset \ ( shift -- ) - eine registersatz ausgeben
  5 0 do dup i + hss:reg .word space loop drop ;

ifnot: .hreg
: .hreg \ ( -- ) - register ausgeben
  14 0 do i .hset cr 5 +loop ;

ifnot: fadeout
: fadeout \ ( -- ) - sound langsam ausblenden
  f 0 do e i - hss:vol 50 delms loop ;

ifnot: end?
: end? \ ( cnt -- flag ) - abfrage nach cnt wiederholungen
  4 hss:reg = ;

ifnot: hwait
: hwait \ ( -- flag ) - wartet auf songende oder taste
  begin 50 delms key? 2 end? or until key drop ;

ifnot: hreg..
: hreg.. \ ( -- ) - fortlaufende anzeige register
  scr:curoff scr:cls begin scr:home .hreg 2 end? until 
  scr:curon fadeout hss:stop ;

ifnot: (hplay)
: (hplay) \ ( cstr -- )
  ." Datei : " dup .cstr hss:load .err f hss:vol hss:play 
  hwait fadeout hss:stop 100 delms cr ;

\ hplay name ( -- ) - datei abspielen
ifnot: hplay
: hplay  
  hload hss:play ;

\ files? ( -- cnt ) - anzahl dateien im dir
ifnot: files?
: files? 
  adm:diropen 
  0 begin adm:nextfile swap 1+ swap 0= until 3 - padbl ;
  
\ filenr? ( nr -- )
ifnot: filenr?
: filenr?
  adm:diropen 
  0 do adm:nextfile drop loop ;

\ hdirplay ( -- ) - gesamtes verzeichnis abspielen
\ im verzeichnis dürfen nur hss-dateien sein!
ifnot: hdirplay
: hdirplay
  decimal files? dup ." Dateien : " . cr 
  0 do i dup 1 + . 3 + filenr? pad (hplay) loop padbl hex ;

: (hp) ." play : " dup .cstr hss:load .err ;

ifnot: playliste
: playliste 
  c" kw.hss"        (hplay) 
  c" genes.hss"     (hplay) 
  c" greenpuz.hss"  (hplay)
  c" hssintro.hss"  (hplay)
  c" kali766.hss"   (hplay)
  c" machine.hss"   (hplay)
  c" metroid.hss"   (hplay)
  c" mrboss.hss"    (hplay)
  c" mrevil.hss"    (hplay)
  c" raind.hss"     (hplay)
  c" sytrus.hss"    (hplay)
  c" tbellsp1.hss"  (hplay) ;

