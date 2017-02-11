
\ ACHTUNG: Diese Modifikation nicht bei einer Installation im 
\ HI-EEPROM verwenden!

hex
[if mod:rom 
: mod:rom ; ]

\ constant ( x -- ) skip blanks parse the next word and create a constant, allocate a long, 4 bytes
[if constant
: constant lockdict create $C_a_doconl w, l, forthentry freedict ; ]

\
\ CONFIG PARAMETERS BEGIN
\
40	wconstant	fsps		\ a page size which works with 32kx8 & 64kx8 eeproms
                            \ and should work with larger as well.                


8000	constant	fsbot \ file-system bottom:  the start adress in eeprom for the file system

                          \ file system top: the end address of the file  system
                          \ uncomment the line for your comfiguration
\ 8000 constant	fstop \ the end address for the file system with one 24LC256 32k eeprom                           
10000	constant	fstop \ the end address for the file system with one 24LC512 64k eeprom 
\ 20000	constant	fstop \ the end address for the file system with two 24LC512 64k eeprom 
\ 30000	constant	fstop \ the end address for the file system with 3   24LC512 64k eeprom 
\ 40000	constant	fstop \ the end address for the file system with 4   24LC512 64k eeprom 
\ 50000	constant	fstop \ the end address for the file system with 5   24LC512 64k eeprom 
\ 60000	constant	fstop \ the end address for the file system with 6   24LC512 64k eeprom 
\ 70000	constant	fstop \ the end address for the file system with 7   24LC512 64k eeprom

\ NOTE IF you have DEMOBOARD or any system with 32K EEPROM, you will step on your spin image
\ when you write to the EEPROM.  You can still use it (if you are tricky), but KNOW WHAT YOUR DOING!!!  

\
\ CONFIG PARAMETERS END
\


\ lasti? ( -- t/f ) true if this is the last value of i in this loop
[if lasti?
: lasti? _rsptr COG@ 2+ COG@ 1- _rsptr COG@ 3 + COG@ = ; ]

\ padbl ( -- ) fills this cogs pad with blanks
[if padbl
: padbl pad padsize bl fill ; ]
\ _eeread ( t/f -- c1 ) read a byte from the eeprom, ackbit in, byte out
[if _eeread : _eeread _sdai 0 8 0 do 1 lshift _sclh _sda? _scll if 1 or then loop
swap if _sdah else _sdal then _sdao _sclh _scll _sdal ; ]

\ the eereadpage and eewritePage words assume the eeprom are 64kx8 and will address up to 
\ 8 sequential eeproms
\ eereadpage ( eeAddr addr u -- t/f ) return true if there was an error, use lock 1
[if eereadpage : eereadpage begin 1 lockset 0= until
1 max rot dup ff and swap dup 8 rshift ff and swap 10 rshift 7 and 1 lshift dup >r
_eestart A0 or _eewrite swap _eewrite or swap _eewrite or
_eestart r> A1 or _eewrite or
rot2 bounds
do lasti? _eeread i C! loop _eestop 1 lockclr drop ; ]

\ _eeread ( t/f -- c1 ) read a byte from the eeprom, ackbit in, byte out
[if _eeread : _eeread _sdai 0 8 0 do 1 lshift _sclh _sda? _scll if 1 or then loop
swap if _sdah else _sdal then _sdao _sclh _scll _sdal ; ]

\ the eereadpage and eewritePage words assume the eeprom are 64kx8 and will address up to 
\ 8 sequential eeproms
\ eereadpage ( eeAddr addr u -- t/f ) return true if there was an error, use lock 1
[if eereadpage : eereadpage begin 1 lockset 0= until
1 max rot dup ff and swap dup 8 rshift ff and swap 10 rshift 7 and 1 lshift dup >r
_eestart A0 or _eewrite swap _eewrite or swap _eewrite or
_eestart r> A1 or _eewrite or
rot2 bounds
do lasti? _eeread i C! loop _eestop 1 lockclr drop ; ]

\ EW@ ( eeAddr -- n1 )
[if EW@
: EW@ t0 2 eereadpage if 8006 ERR then t0 W@ ; ]

\ EC@ ( eeAddr -- c1 )
[if EC@
: EC@ EW@ FF and ; ]

\ (fspa) ( addr1 -- addr2) addr2 is the next page aligned address after addr1
: (fspa) fsps 1- + fsps 1- andn ;

\ (fsnext) ( addr1 -- addr2 t/f) addr - the current file address, addr2 - the next addr, t/f - true if we have
\				gone past the end of the eeprom. t0 -length of the current file
\				t1 - length of the file name (char)
: (fsnext) t0 W@ t1 C@ + 2+ 1+ + (fspa) dup fstop >= ;


\ (fswr) ( addr1 addr2 n1 -- ) addr1 - the eepropm address to write, addr2 - the address to write from
\ n1 - the number of bytes to write
: (fswr) dup >r rot dup r> + fstop 1- > if A0 ERR then rot2 eewritepage if 88 ERR then ;

\ (fsrd) ( addr1 addr2 n1 -- ) addr1 - the eepropm address to read, addr2 - the address of the read buffer
\ n1 - the number of bytes to read
: (fsrd) dup >r rot dup r> + fstop 1- > if C0 ERR then rot2 eereadpage if 90 ERR then ;

\ (fsfree) ( -- n1 ) n1 is the first location in the file system, -1 if there are none
: (fsfree) -1 fsbot begin
\ read 3 bytes into t0, t1 and process
	dup t0 3 (fsrd) t0 W@ FFFF = if nip dup -1 else (fsnext) then
until drop ;

\ (fsfind) ( cstr -- addr ) find the last file named cstr, addr is the eeprom address, 0 if not found
: (fsfind) fsbot 0 >r begin
\ read namesizemax 1F + 3 bytes into t0, t1, and tbuf
	dup t0 22 (fsrd) t0 W@ FFFF = if -1 else
		over t1 cstr= if r> drop dup >r then
		(fsnext)
	then
until 2drop r> ;

\ (fslast) ( -- addr ) find the last file, 0 if not found
: (fslast) 0 fsbot begin
\ read namesizemax 1F + 3 bytes into t0, t1, and tbuf
	dup t0 22 (fsrd) t0 W@ FFFF = if -1 else
		nip dup
		(fsnext)
	then
until drop ;

\ fsclear ( -- )
: fsclr padbl fsbot 400 + fsbot do i pad fsps (fswr) 2e emit fsps +loop -1 fsbot EW! ;
: fsclear -1 fsbot EW! ; 

\ fsfree ( -- )
: fsfree (fsfree) dup -1 = if 0 else fstop swap - then . ." bytes free in fs" cr ;

\ fsls ( -- ) list the files
: fsls cr fsbot begin
\ read namesizemax 1F + 3 bytes into t0, t1, and tbuf
	dup t0 22 (fsrd) t0 W@ FFFF = if -1 else
		dup .addr space t0 W@ .addr space t1 .cstr cr
		(fsnext)
	then
until fstop swap - cr . ."  bytes free in files system" cr cr ;

\ (fsread) ( cstr -- )
: (fsread) (fsfind) dup if
\ read 3 bytes into t0, t1 and process
	dup t0 3 (fsrd)
		t1 C@ + 2+ 1+ t0 W@ bounds do
			ibound i - fsps >= if
			i pad fsps (fsrd) pad fsps bounds
			do i C@ emit loop i fsps 1- + seti
		else
			i EC@ emit
		then
	loop
else drop then padbl ;
 
\ fsread ( -- ) filename
: fsread parsenw dup if (fsread) else drop then ;

\ (fsload) ( ctsr -- )
: (fsload) cogid nfcog iolink (fsread) d emit d emit cogid iounlink ;

\ fsload filename ( -- ) send the file to the next free forth cog
: fsload parsenw dup if (fsload) else drop then ;

\ (fsk) ( n1 -- n2)
: (fsk) 8 lshift key or ;

\ fswrite filename ( -- ) writes a file until ... followed immediately by a cr is encountered
: fswrite  (fsfree) dup -1 <> parsenw dup rot and  if
\ set the file length to 0, copy in the file name
	0 pad W! dup C@ 2+ 1+ pad + swap pad 2+ ccopy
\ find the first free page
	0 swap key (fsk) (fsk) (fsk)
\ ( eaddr1 n1 addr2 n2 ) eaddr - start of file in the eeprom, n1 - bytes written so far, addr2 - next addr in the pad,
\ n2 - a 4 byte key buffer
	begin
\ check to see if we have a ... at the end of a line
		2E2E2E0D over = if
			-1
		else
\ get a key from the key buffer, write it the the pad
			swap over 18 rshift dup dup d = if drop cr else emit then over C! 1+ tuck pad - fsps = if
\ we have a page worth of data, write it out
				nip rot2 2dup + pad fsps (fswr) fsps + rot pad swap
			then	
\ get another key			
			(fsk) 0
		then
	until
\ any keys left?
	drop pad - dup 0> if
\ write the leftover, not a full page
		>r 2dup + pad r> dup >r (fswr) r> +
	else 
		drop
	then
\ write the length of FFFF for the next file
	2dup + FFFF swap (fspa) dup fstop 1- < if EW! else 2drop then	
\ subtract the length of the filename +1, and the 2 bytes which are the length of the file, and update the length of the file 
	over 2+ EC@ 2+ 1+ - swap EW!
else 2drop clearkeys then padbl
;

\ fsdrop ( -- ) deletes last file
: fsdrop (fslast) dup -1 = if drop else FFFF swap EW! then ;
 

