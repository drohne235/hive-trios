DAT
{
        video-treiber-frame
        - basiert auf dem tollen tutorial von bamse

30-09-2009-dr235        driver 1 - originalcode, anpassung an hive
                        driver 2 - senkrechte balken
                        driver 3 - einfarbige fläche
                        driver 4 - wandernde farbbalken, 1 byte pro pixel :)
                        driver 5 - 
                        
        
}

CON
  _CLKMODE = xtal1 + pll16x
  _XINFREQ = 5_000_000
  
PUB start 

  cognew(@entry,0)                                                         ' neue cog mit video-treiber starten

DAT                     org     0
entry                   jmp     #Start_of_driver                                ' Start here...

' NTSC sync stuff.
NTSC_color_freq                 long  3_579_545                                 ' NTSC Color Frequency
NTSC_hsync_VSCL                 long  39 << 12 + 624                            ' Used for the Horisontal Sync 
NTSC_active_VSCL                long  188 << 12 + 3008                          ' Used for the Vertical sync
NTSC_hsync_pixels               long  %%11_0000_1_2222222_11                    ' Horizontal sync pixels
NTSC_vsync_high_1               long  %%1111111_2222222_11                      ' Vertical sync signal part one for lines 1-6 and 13 to 18
NTSC_vsync_high_2               long  %%1111111111111111                        ' Vertical sync signal part two for lines 1-6 and 13 to 18
NTSC_vsync_low_1                long  %%2222222222222222                        ' Vertical sync signal part one for lines 7-12
NTSC_vsync_low_2                long  %%22_1111111_2222222                      ' Vertical sync signal part two for lines 7-12
NTSC_sync_signal_palette        long  $00_00_02_8A                              ' The sync Palette

'                             hbeat   --------+ +-------------------------    /cs                           
'                             clk     -------+| |                           
'                             /wr     ------+|| |  +----------------------    videopins                    
'                             /hs     -----+||| |  |
'                                          |||| |--+              --------    d0..d7
tvport_mask                     long  %00000000_01110000_00000000_00000000      ' Maske für Video-Pins am Hive
vsu_cfg                         long  %01110100_00000000_00000100_01110000      ' Wert für VCFG-Register

NTSC_Graphic_Lines              long  244                                       ' Anzahl der sichtbaren Zeilen
NTSC_Graphics_Pixels_VSCL       long  16 << 12 + 16                             ' 16 clocks per pixel, 64 clocks per frame.

                            
PAL0                            long  $01
PAL1                            long  $0E
PAL2                            long  $0D
PAL3                            long  $0C
PAL4                            long  $0B
DIF1                            long  $00_10
CNT_ANIM                        long  $4

' Loop counters.
line_loop                       long  $0                                        ' Line counter...
pix_loop                        long  $0
anim_loop                       long  $0

' General Purpose Registers
r0                              long  $0                                        ' Initialize to 0
r1                              long  $0
r2                              long  $0
r3                              long  $0
c1                              long  $0                                        ' colorregister
c2                              long  $0
c3                              long  $0

'========================== Start of the actual driver =============================================

Start_of_driver
                        ' VCFG, setup Video Configuration register and 3-bit tv DAC pins to output
                        mov     VCFG, vsu_cfg                                   ' Konfiguration der VSU
                        or      DIRA, tvport_mask                               ' Set DAC pins to output

                        ' CTRA, setup Frequency to Drive Video
                        movi    CTRA,#%00001_111                                ' pll internal routed to Video, PHSx+=FRQx (mode 1) + pll(16x)
                        mov     r1, NTSC_color_freq                             ' r1: Color frequency in Hz (3.579_545MHz)
                        rdlong  r2, #0                                          ' Copy system clock from main memory location 0. (80Mhz)
                        ' perform r3 = 2^32 * r1 / r2
                        mov     r0,#32+1
:loop                   cmpsub  r1,r2           wc
                        rcl     r3,#1
                        shl     r1,#1
                        djnz    r0,#:loop
                        mov     FRQA, r3                                        ' Set frequency for counter A


'========================== Start of Frame Loop ==============================================

frame_loop
                        mov     anim_loop, CNT_ANIM
frame_loop2             

'========================== Screen =============================================

                        mov     line_loop, NTSC_Graphic_Lines                   ' anzahl der zeilen laden (244)

user_lines
                        '------ zeilensynchronisation
                        mov     VSCL, NTSC_hsync_VSCL                           ' Setup VSCL for horizontal sync.
                        waitvid NTSC_sync_signal_palette, NTSC_hsync_pixels     ' Generate sync.


                        '------ sichtbarer zeileninhalt
                        mov     VSCL, NTSC_Graphics_Pixels_VSCL                 ' Setup VSCL for user pixels.

                        '------ verschiedenfarbige balken ausgeben
                        mov     c1, PAL4                                        
                        add     c1, c3
                        mov     pix_loop, #23                                   
bar_loop
                        add     c1, #$10                                        ' 8 x pixel einzeln! ausgeben
                        mov     c2, c1                                          ' also 2 tiles
                        waitvid c2, #0                                          ' 8 bit pro pixel!
                        add     c2, #1
                        waitvid c2, #0
                        add     c2, #1
                        waitvid c2, #0
                        add     c2, #1
                        waitvid c2, #0
                        sub     c2, #1
                        waitvid c2, #0
                        sub     c2, #1
                        waitvid c2, #0
                        sub     c2, #1
                        waitvid c2, #0
                        sub     c2, #1
                        waitvid c2, #0
                        
                        djnz    pix_loop, #bar_loop                             

                        sub     c2, #1
                        waitvid c2, #0                                          ' 4 mal extrapixel, für das timing
                        sub     c2, #1                                          ' also insgesamt 188 pixel pro zeile
                        waitvid c2, #0
                        sub     c2, #1
                        waitvid c2, #0
                        sub     c2, #1
                        waitvid c2, #0

                        djnz    line_loop, #user_lines                          ' schleife durch alle zeilen

'========================== The 16 lines of Horizontal sync ==================================
                        
                        mov     line_loop, #6                                   ' Line 244, start of first high sync.
vsync_high1             mov     VSCL, NTSC_hsync_VSCL
                        waitvid NTSC_sync_signal_palette, NTSC_vsync_high_1
                        mov     VSCL, NTSC_active_VSCL
                        waitvid NTSC_sync_signal_palette, NTSC_vsync_high_2
                        djnz    line_loop, #vsync_high1

                        mov     line_loop, #6                                   ' Line 250, start of the Seration pulses.
vsync_low               mov     VSCL, NTSC_active_VSCL
                        waitvid NTSC_sync_signal_palette, NTSC_vsync_low_1
                        mov     VSCL,NTSC_hsync_VSCL 
                        waitvid NTSC_sync_signal_palette, NTSC_vsync_low_2
                        djnz    line_loop, #vsync_low

                        mov     line_loop, #6                                   ' Line 256, start of second high sync.
vsync_high2             mov     VSCL, NTSC_hsync_VSCL
                        waitvid NTSC_sync_signal_palette, NTSC_vsync_high_1
                        mov     VSCL, NTSC_active_VSCL
                        waitvid NTSC_sync_signal_palette, NTSC_vsync_high_2
                        djnz    line_loop, #vsync_high2

'========================== End of Frame Loop =============================================
                        djnz    anim_loop, #frame_loop2
                        add     c3, #$10


'========================== Animation                       ==================================
                        
                        jmp     #frame_loop                                     ' And repeat for ever...
FIT
                                        