
hex

ifnot: mod:tools 
: mod:tools ;

\ kommandoformen
ifnot: adm:fkt!b!l@     \ ( b fkt -- l )
: adm:fkt!b!l@ b[ [a!] [a!] [a.l@] ]b ;
ifnot: adm:fkt!b!b@     \ ( b fkt -- b )
: adm:fkt!b!b@ b[ [a!] [a!] [a@] ]b ;
ifnot: adm:fkt!s!     \ ( s fkt -- )
: adm:fkt!s! b[ [a!] [a.s!] ]b ;

\ dm-funktionen
ifnot: adm:dmget  \ ( dmnr -- dm ) - marker lesen
: adm:dmget 1B adm:fkt!b!l@ ;

ifnot: adm:dmact  \ adm:dmact ( dmnr -- ) - marker aktivieren
: adm:dmact 19 adm:fkt!b!b@ drop ;

\ adm-funktionen

\ adm:aload ( cstr -- ) - neuen administra-code laden
ifnot: adm:load
: adm:load
  60 adm:fkt!s! ;

\ bel-funktionen

\ bel:load ( cstr -- ) - bellatrix-code laden
\ achtung: die gesamte loader-operation ist eine atomare
\ operation über alle drei propellerchips, kann also auch
\ nicht aufgetrennt werden!
ifnot: bel:load        
: bel:load
  52 adm:open .err      \ datei öffnen
  b[
    0 [b!] 57 [b!]                       \ bella-loader starten
    10 0 do 06 [a!] [a@] [b!] loop       \ header einlesen
    0A [a!] 0 [a.l!]                     \ 0 adm:seek
    [b@] <8 [b@] or                      \ dateilänge empfangen
    0 do 06 [a!] [a@] [b!] loop          \ datei senden
  ]b                                     
  adm:close .err       \ datei schließen
;

\ ------------------------------------ mod:tools

ifnot: aload
: aload                 \ name ( -- ) - administra-code laden
  mount? parsenw dup 
  if adm:load 0 else drop 23 then .err ;  

ifnot: bload
: bload                 \ name ( -- ) - bellatrix-code laden
  mount? parsenw dup
 if bel:load 0 else drop 23 then .err ;
  
ifnot: .dmstatus        \ ( dm -- ) - ausgabe marker-status
: .dmstatus -1 = if ." frei" else ." gesetzt" then cr ;

ifnot: dm?
: dm?
  ." [root] : " 0 adm:dmget .dmstatus
  ." [sys ] : " 1 adm:dmget .dmstatus
  ." [usr ] : " 2 adm:dmget .dmstatus
  ." [ A  ] : " 3 adm:dmget .dmstatus
  ." [ B  ] : " 4 adm:dmget .dmstatus
  ." [ C  ] : " 5 adm:dmget .dmstatus ;

\ open name ( -- ) - datei lesend öffnen und auf fehler prüfen
ifnot: open
: open 
  mount? parsenw dup 
  if 52 adm:open else drop 23 then .err ;  

\ close ( -- ) - geöffnete datei schließen
ifnot: close
: close  
  adm:close .err ;

\ (cat) ( -- ) - alle zeichen der geöffneten datei ab 
\ lesemarke auf ausgabekanal bis zum eof ausgeben
ifnot: (cat)
: (cat) begin adm:getc emit adm:eof until ;

\ cat name ( -- ) - datei "name" komplett ausgeben
ifnot: cat
: cat open (cat) close ;

\ nextline ( -- ) - ausgabe der nächsten textzeile aus der
\ geöffneten datei
ifnot: nextline
: nextline 
  begin adm:getc dup emit 0d = adm:eof or until ;

\ nextlines ( n -- ) - ausgabe von n zeilen
ifnot: nextlines
: nextlines
  0 do adm:eof 0= if nextline then loop ;
  
\ less name ( -- ) - zeilenweise ausgabe der datei
ifnot: less
: less 
  open begin 10 nextlines key 71 = adm:eof or until close ;

\ #C ( c1 -- ) prepend the character c1 to the number 
\ currently being formatted
ifnot: #C
: #C -1 >out W+! pad>out C! ;

\ .cogch ( n1 n2 -- ) print as x(y)
ifnot: .cogch
: .cogch <# 29 #C # 28 #C drop # #> .cstr ;

\ j ( -- n1 ) the second most current loop counter
ifnot: j
: j _rsptr COG@ 5 + COG@ ;

\ cog? ( -- )
ifnot: cog?
: cog? 
  8 0 do ." Cog:" i dup . ." #io chan:" 
  dup cognchan . cogstate C@ 
	dup 4 and if version W@ .cstr then
	dup 10 and if i cognumpad version W@ C@ over C@ - 
    spaces .cstr then
	14 and if i cogio i cognchan 0 do
		i 4* over + 2+ W@ dup 0= if drop else
			space space j i .cogch ." ->" io>cogchan .cogch 
		then
	loop
drop then cr loop ;

\ jede erweiterung legt ein wort als startmarke 
\ nmit folgendem namen an:
\ mod:xxx - softwaremodule
\ drv:xxx - treiber
\ lib:xxx - bibliotheken
\ so kann mit den folgenden kommandos eine schnelle liste der
\ vorhandenen erweiterungen abgerufen und mit forget
\ aus dem system entfernt werden 

\ mod? ( -- ) - anzeige der module
ifnot: mod?
: mod? c" mod:" _words ;

\ lib? ( -- ) - anzeige der bibliotheken
ifnot: lib?
: lib? c" lib:" _words ;

