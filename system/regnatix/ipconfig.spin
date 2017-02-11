{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Autor: Jörg Deckert                                                                                 │
│ Copyright (c) 2013 Jörg Deckert                                                                     │
│ See end of file for terms of use.                                                                    │
│ Die Nutzungsbedingungen befinden sich am Ende der Datei                                              │
└──────────────────────────────────────────────────────────────────────────────────────────────────────┘

Informationen   : hive-project.de
Kontakt         : joergd@bitquell.de
System          : TriOS
Name            : flash
Chip            : Regnatix
Typ             : Programm
Version         : 
Subversion      : 
Funktion        : IP-Konfiguration in NVRAM ablegen
Komponenten     : -
COG's           : -
Logbuch         :

11.06.2013-joergd - erste Version, basierend auf time.spin
05.01.2014-joergd - kleine Verbesserungen im Parameter-Handling

Kommandoliste   :


Notizen         :


}}

OBJ
        ios: "reg-ios"
        str: "glob-string"
        num: "glob-numbers"

CON

_CLKMODE     = XTAL1 + PLL16X
_XINFREQ     = 5_000_000

 LANMASK     = %00000000_00000000_00000000_00100000

CON 'NVRAM Konstanten --------------------------------------------------------------------------

#4,     NVRAM_IPADDR
#8,     NVRAM_IPMASK
#12,    NVRAM_IPGW
#16,    NVRAM_IPDNS
#20,    NVRAM_IPBOOT
#24,    NVRAM_HIVE       ' 4 Bytes

DAT

  strNVRAMFile byte  "nvram.sav",0                      'contains the 56 bytes of NVRAM, if RTC is not available

VAR

byte    parastr[64]
byte    rtcAvailable

PUB main | i

  ios.start                                             'ios initialisieren
  ios.printnl

  ifnot (ios.admgetspec & LANMASK)
    ios.print(@strNoNetwork)
    ios.stop
  if ios.rtcTest                                        'RTC chip available?
    rtcAvailable := TRUE
  else                                                  'use configfile
    rtcAvailable := FALSE
    ios.print(@strNoRTC)
    ios.sddmset(ios#DM_USER)                            'u-marker setzen
    ios.sddmact(ios#DM_SYSTEM)                          's-marker aktivieren
    if ios.sdopen("R",@strNVRAMFile)                     'config file available
      ios.sdnewfile(@strNVRAMFile)                       'no, create it
      if ios.sdopen("W",@strNVRAMFile)
        ios.print(@strErrorOpen)
        ios.stop
      else
        repeat i from 0 to 55                           'set default value for pseudo NVRAM Bytes 0 - 55
          ios.sdputc(0)
        ios.sdclose
    else
      ios.sdclose
    ios.sddmact(ios#DM_USER)                            'u-marker aktivieren

  ios.parastart                                         'parameterübergabe starten
  repeat while ios.paranext(@parastr)                   'parameter einlesen
    if byte[@parastr][0] == "/"                         'option?
      case byte[@parastr][1]
        "?": ios.print(@help)
        "l": cmd_listcfg
        "a": if ios.paranext(@parastr)
               cmd_setaddr(NVRAM_IPADDR, @parastr)
        "m": if ios.paranext(@parastr)
               cmd_setaddr(NVRAM_IPMASK, @parastr)
        "g": if ios.paranext(@parastr)
               cmd_setaddr(NVRAM_IPGW, @parastr)
        "d": if ios.paranext(@parastr)
               cmd_setaddr(NVRAM_IPDNS, @parastr)
        "b": if ios.paranext(@parastr)
               cmd_setaddr(NVRAM_IPBOOT, @parastr)
        "i": if ios.paranext(@parastr)
               cmd_sethive(num.FromStr(@parastr, num#DEC))
        other: ios.print(@help)
  ios.stop

PRI cmd_listcfg | hiveid                                       'nvram: IP-Konfiguration anzeigen

  ifnot rtcAvailable
    ios.sddmset(ios#DM_USER)                                      'u-marker setzen
    ios.sddmact(ios#DM_SYSTEM)                                    's-marker aktivieren
    if ios.sdopen("R",@strNVRAMFile)
      ios.print(@strErrorOpen)
      ios.sddmact(ios#DM_USER)                                    'u-marker aktivieren
      return

  ios.print(@strAddr)
  listaddr(NVRAM_IPADDR)
  ios.print(string("/"))
  listaddr(NVRAM_IPMASK)
  ios.printnl

  ios.print(@strGw)
  listaddr(NVRAM_IPGW)
  ios.printnl

  ios.print(@strDNS)
  listaddr(NVRAM_IPDNS)
  ios.printnl

  ios.print(@strBoot)
  listaddr(NVRAM_IPBOOT)
  ios.printnl

  ios.print(@strHive)
  if rtcAvailable
    hiveid := ios.getNVSRAM(NVRAM_HIVE)
    hiveid += ios.getNVSRAM(NVRAM_HIVE+1) << 8
    hiveid += ios.getNVSRAM(NVRAM_HIVE+2) << 16
    hiveid += ios.getNVSRAM(NVRAM_HIVE+3) << 24
  else
    ios.sdseek(NVRAM_HIVE)
    hiveid := ios.sdgetc
    hiveid += ios.sdgetc << 8
    hiveid += ios.sdgetc << 16
    hiveid += ios.sdgetc << 24
  ios.print(str.trimCharacters(num.ToStr(hiveid, num#DEC)))
  ios.printnl

  ifnot rtcAvailable
    ios.sdclose
    ios.sddmact(ios#DM_USER)                                      'u-marker aktivieren

PRI listaddr (nvidx) | count                                  'IP-Adresse anzeigen

  ifnot rtcAvailable
    ios.sdseek(nvidx)

  repeat count from 0 to 3
    if(count)
      ios.print(string("."))
    if rtcAvailable
      ios.print(str.trimCharacters(num.ToStr(ios.getNVSRAM(nvidx+count), num#DEC)))
    else
      ios.print(str.trimCharacters(num.ToStr(ios.sdgetc, num#DEC)))

PRI cmd_setaddr (nvidx, ipaddr) | pos, count                  'IP-Adresse setzen

  ifnot rtcAvailable
    ios.sddmset(ios#DM_USER)                                      'u-marker setzen
    ios.sddmact(ios#DM_SYSTEM)                                    's-marker aktivieren
    if ios.sdopen("W",@strNVRAMFile)
      ios.print(@strErrorOpen)
      ios.sddmact(ios#DM_USER)                                    'u-marker aktivieren
      return
    else
      ios.sdseek(nvidx)

  count := 0
  repeat while ipaddr
    pos := str.findCharacter(ipaddr, ".")
    if(pos)
      byte[pos++] := 0
    if rtcAvailable
      ios.setNVSRAM(nvidx+count++, num.FromStr(ipaddr, num#DEC))
    else
      ios.sdputc(num.FromStr(ipaddr, num#DEC))
    ipaddr := pos
    if(count == 4)
      quit

  ifnot rtcAvailable
    ios.sdclose
    ios.sddmact(ios#DM_USER)                                      'u-marker aktivieren

  ios.lanstop
  ios.lanstart

PRI cmd_sethive (hiveid)                                       'Hive-Id setzen

  if rtcAvailable
    ios.setNVSRAM(NVRAM_HIVE, hiveid & $FF)
    ios.setNVSRAM(NVRAM_HIVE+1, (hiveid >> 8) & $FF)
    ios.setNVSRAM(NVRAM_HIVE+2, (hiveid >> 16) & $FF)
    ios.setNVSRAM(NVRAM_HIVE+3, (hiveid >> 24) & $FF)
  else
    ios.sddmset(ios#DM_USER)                                      'u-marker setzen
    ios.sddmact(ios#DM_SYSTEM)                                    's-marker aktivieren
    if ios.sdopen("W",@strNVRAMFile)
      ios.print(@strErrorOpen)
    else
      ios.sdseek(NVRAM_HIVE)
      ios.sdputc(hiveid & $FF)
      ios.sdputc((hiveid >> 8) & $FF)
      ios.sdputc((hiveid >> 16) & $FF)
      ios.sdputc((hiveid >> 24) & $FF)
      ios.sdclose
    ios.sddmact(ios#DM_USER)                                      'u-marker aktivieren

  ios.lanstop
  ios.lanstart

DAT                                                     'sys: helptext

#ifdef __LANG_EN
  'locale: english

  strNoNetwork byte "Administra doesn't provide network functions!",13,"Please load admnet.",13,0
  strNoRTC     byte "RTC/NVRAM not found",13,"using configuration in /system/nvram.sav",13,0
  strAddr      byte " Ip address:  ",0
  strGw        byte " Gateway:     ",0
  strDNS       byte " DNS server:  ",0
  strBoot      byte " Boot server: ",0
  strHive      byte " Hive ID:     ",0
  strErrorOpen byte "Can't open configuration file",13,0

  help         byte  "/?           : Help",13
               byte  "/l           : List configuration",13
               byte  "/a <a.b.c.d> : Set ip address",13
               byte  "/m <x.x.x.x> : Set network mask",13
               byte  "/g <e.f.g.h> : Set default gateway",13
               byte  "/d <i.j.k.l> : Set DNS server",13
               byte  "/b <m.n.o.p> : Set boot server",13
               byte  "/i <Id>      : Set Hive ID",13
               byte  0

#else
  'default locale: german

  strNoNetwork byte "Administra stellt keine Netzwerk-Funktionen zur Verfügung!",13,"Bitte admnet laden.",13,0
  strNoRTC     byte "RTC/NVRAM nicht vorhanden",13,"nutze Konfiguration in /system/nvram.sav",13,0
  strAddr      byte " IP-Adresse:  ",0
  strGw        byte " Gateway:     ",0
  strDNS       byte " DNS-Server:  ",0
  strBoot      byte " Boot-Server: ",0
  strHive      byte " Hive-Id:     ",0
  strErrorOpen byte "Kann Konfigurationsdatei nicht öffnen.",13,0

  help         byte  "/?           : Hilfe",13
               byte  "/l           : Konfiguration anzeigen",13
               byte  "/a <a.b.c.d> : IP-Adresse setzen",13
               byte  "/m <x.x.x.x> : Netzwerk-Maske setzen",13
               byte  "/g <e.f.g.h> : Gateway setzen",13
               byte  "/d <i.j.k.l> : DNS-Server setzen",13
               byte  "/b <m.n.o.p> : Boot-Server setzen",13
               byte  "/i <Id>      : Hive-Id setzen",13
               byte  0

#endif

DAT                                                     'lizenz
     
{{

┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │                                                            
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │ 
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}
