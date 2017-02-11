
hex

ifnot: mod:wplay
: mod:wplay ;

\ kommandoformate

ifnot: adm:fkt!s!b@   \ ( s fkt -- b )
: adm:fkt!s!b@ b[ [a!] [a.s!] [a@] ]b ;

ifnot: adm:fkt!b!b@     \ ( b fkt -- b )
: adm:fkt!b!b@ b[ [a!] [a!] [a@] ]b ;

ifnot: adm:fkt!b@     \ ( fkt -- b )
: adm:fkt!b@ b[ [a!] [a@] ]b ;

\ wave-funktionen

\ wav:start ( cstr -- err )
ifnot: wav:start
: wav:start
  96 adm:fkt!s!b@ ;

\ wav:stop ( -- )
ifnot: wav:stop
: wav:stop
  97 adm:fkt!b@ drop ;

\ wav:status ( -- status )
ifnot: wav:status
: wav:status
  98 adm:fkt!b@ ;
  
\ adm-funktionen

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

  
\ metafunktionen

\ won
ifnot: won
: won
  0 adm:setsound 3 adm:setsound 2drop ;

\ woff 
ifnot: woff
: woff
  2 adm:setsound 1 adm:setsound 2drop ; 

\ wend? ( -- t/f )  
ifnot: wend?
: wend?
  begin 50 delms key? dup if key drop then wav:status 0= or until ;

\ (wplay) ( cstr -- )
ifnot: (wplay)
: (wplay) \ ( cstr -- )
  ." Datei : " dup .cstr cr wav:start .err wend? wav:stop ;
  
\ wplay name ( -- )
ifnot: wplay
: wplay 
  won parsenw (wplay) woff ;

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

\ wdirplay ( -- ) - gesamtes verzeichnis abspielen
\ im verzeichnis dürfen nur wav-dateien sein!
ifnot: wdirplay
: wdirplay
  won files? dup ." Dateien : " . cr 
  0 do i dup 1 + . 3 + filenr? pad (wplay) loop padbl woff ;
