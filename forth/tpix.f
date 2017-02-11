\ requires bel.lib
\ requires g0.lib
\ requires ari.lib

hex

: it ;  \ fuer forget

variable colortab 40 4* 4 - allot
variable tiletab g0:xtiles g0:ytiles * 2* 4 - allot

: fillcolortab
  colortab
  40 0 do
    i dup + 4 + 0F and 00001010 * 0D060D02 +
    over L! 4+
  loop drop
;
 
: filltilescreen
  tiletab g0:disp_base 6 rshift
  g0:ytiles 0 do
    g0:xtiles 0 do
      swap 2dup W! 2+ swap g0:ytiles +
    loop 341 +
  loop 2drop ;

decimal

: setscreen
  fillcolortab filltilescreen
  tiletab colortab g0:setscreen
;

: tpix
  g0:load setscreen g0:static
  g0:clear 14 g0:width 1 g0:color
  g0:xtiles 0 do i 16 * 8 + 
    g0:ytiles 0 do i 16 * 8 + over g0:plot loop drop
  loop
  key g0:clear
  2000 0 do
    rnd 31 and g0:width rnd 3 and g0:color
    rnd rnd g0:plot
  loop
  key g0:reboot
  cr ." erledigt" cr
;
