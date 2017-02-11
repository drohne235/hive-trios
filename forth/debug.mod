
hex

ifnot: mod:debug
: mod:debug ;

\ keycode ( -- ) - anzeige der tastaturcodes
ifnot: keycode
: keycode
  begin
    0 key? if 
      drop key dup dup ." code   : " emit ." : " . cr 1B = 
    then until ;
    
\ 
\ Noisy reset messages
\ 
\ print out a reset message to the console
\ (rsm) ( n -- ) n is the last status
\ 0011FFFF - stack overflow
\ 0012FFFF - return stack overflow
\ 0021FFFF - stack underflow
\ 0022FFFF - return stack underflow
\ 8100FFFF - no free cogs
\ 8200FFFF - no free main memory
\ 8400FFFF - fl no free main memory
\ 8500FFFF - no free cog memory
\ 8800FFFF - eeprom write error
\ 9000FFFF - eeprom read error

: (rsm) state W@ 2 and 0= swap
\ process the last status
  dup 0=     if c" ok" else
  dup FF11 = if c" DST OVER" else
  dup FF12 = if c" RST OVER" else
  dup FF21 = if c" DST LOW" else
  dup FF22 = if c" RST LOW" else
  dup 8001 = if c" COGs OUT" else
  dup 8002 = if c" hMEM OUT" else
  dup 8003 = if c" ROM WR" else
  dup 8004 = if c" FL" else
  dup 8005 = if c" cMEM OUT" else
  dup 8006 = if c" ROM RD" else
                c" ?"
  thens
  rot if
    lockdict cr c" ERR : " .cstr swap . .cstr cr freedict
  else 2drop then ;
: onreset (rsm) 4 state orC!  ; 

\ .byte ( n1 -- )
: .byte <# # # #> .cstr ;

\ [if (dumpb)
: (dumpb) cr over .addr space dup .addr _ecs bounds ; ]

\ [if (dumpm)
: (dumpm) cr .word _ecs ; ]

\ [if (dumpe)
: (dumpe) tbuf 8 bounds do i C@ .byte space loop 2 spaces tbuf 8 bounds do i C@ dup bl < if drop 2e then emit loop ; ]
    
\ dump  ( adr cnt -- ) uses tbuf
[if dump
: dump  (dumpb) do i (dumpm) i tbuf 8 cmove  (dumpe) 8 +loop cr ; ]
