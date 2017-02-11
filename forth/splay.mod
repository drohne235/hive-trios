
\ achtung: vor verwendung muss der administra-code mit sidcog 
\ geladen werden:
\ sys tools.mod
\ sys splay.mod     <--- sid-player laden
\ aload admsid.adm  <--- administra-code mit sidcog laden
\ splay xyz.dmp     <--- sid-datei abspielen


hex

ifnot: mod:splay 
: mod:splay ;

\ kommandoformen

ifnot: adm:fkt!         \ ( fkt -- )
: adm:fkt! b[ [a!] ]b ;

ifnot: adm:fkt!b!       \ ( b fkt -- )
: adm:fkt!b! b[ [a!] [a!] ]b ;

ifnot: adm:fkt!b@      \ ( fkt -- b )
: adm:fkt!b@ b[ 0 [a!] [a!] [a@] ]b ; 

ifnot: adm:fkt!s!     \ ( s fkt -- )
: adm:fkt!s! b[ [a!] [a.s!] ]b ;

ifnot: adm:fkt!s!b@     \ ( s fkt -- err )
: adm:fkt!s! b[ [a!] [a.s!] [b@] ]b ;

ifnot: adm:fkt!b!l@     \ ( b fkt -- l )
: adm:fkt!b!l@ b[ [a!] [a!] [a.l@] ]b ;

\ dm-funktionen
ifnot: adm:dmget        \ ( dmnr -- dm ) - marker lesen
: adm:dmget 1B adm:fkt!b!l@ ;

\ adm:dmact ( dmnr -- ) - marker aktivieren
: adm:dmact 19 adm:fkt!b!b@ drop ;

\ adm-funktionen

\ adm:aload ( cstr -- ) - neuen administra-code laden
ifnot: adm:aload
: adm:aload
  60 adm:fkt!s! ;

\ tools

ifnot: aload
: aload
  mount? parsenw dup 
  if 1 adm:dmact adm:aload 0 else drop 23 then .err ;  

\ sid-funktionen

ifnot: sid:play
: sid:play \ ( cstr -- err )
  9E adm:fkt!s!b@ ;
  
ifnot: sid:stop
: sid:stop \ ( -- )
  9F adm:fkt! ; 

ifnot: sid:status
: sid:status \ ( -- status )
  A1 adm:fkt!b@ ; 

ifnot: sid:mute
\ 1 - sid1
\ 2 - sid2
\ 3 - sid1 & sid2
: sid:mute \ ( sidnr -- )
  A3 adm:fkt!b! ; 

\ send? ( -- t/f )  
ifnot: send?
: send?
  begin 50 delms key? dup if key drop then sid:status 0= or 
  until ;
  
\ (splay) ( cstr -- )
ifnot: (splay)
: (splay) \ ( cstr -- )
  ." Datei : " dup .cstr cr sid:play .err 
  send? sid:stop 3 sid:mute adm:close drop ;
  
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

\ splay name.dmp ( -- ) - sid-datei abspielen
ifnot: splay
: splay
  parsenw (splay) ;

\ sdirplay ( -- ) - gesamtes verzeichnis abspielen
\ im verzeichnis dürfen nur sid-dateien sein!
ifnot: sdirplay
: sdirplay
  files? dup ." Dateien : " . cr 
  0 do i dup 1 + . 3 + filenr? pad (splay) loop padbl ;

ifnot: smute
: smute
  sid:stop 3 sid:mute ;
  