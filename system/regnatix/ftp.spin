{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Autor: Jörg Deckert                                                                                  │
│ Copyright (c) 2013 Jörg Deckert                                                                      │
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
Funktion        : FTP-Client
Komponenten     : -
COG's           : -
Logbuch         :

22.12.2013-joergd - erste Version
05.01.2014-joergd - Defaultwerte gesetzt
                  - Speichern auf SD-Card
                  - Parameter für Benutzer und Paßwort

Kommandoliste   :


Notizen         :


}}

OBJ
        ios: "reg-ios"
        str: "glob-string"
        num: "glob-numbers"        'Number Engine

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

  strNVRAMFile byte  "nvram.sav",0                       'contains the 56 bytes of NVRAM, if RTC is not available

VAR

  long    ip_addr
  byte    parastr[64]
  byte    remdir[64]
  byte    filename[64]
  byte    username[64]
  byte    password[64]
  byte    strTemp[128]
  byte    addrset
  byte    save2card
  byte    handleidx_control          'Handle FTP Control Verbindung
  byte    handleidx_data             'Handle FTP Data Verbindung

PUB main

  ip_addr := 0
  save2card := FALSE
  remdir[0] := 0
  filename[0] := 0
  username[0] := 0
  password[0] := 0

  ios.start
  ifnot (ios.admgetspec & LANMASK)
    ios.print(@strNoNetwork)
    ios.stop
  ios.printnl
  ios.parastart                                         'parameterübergabe starten
  repeat while ios.paranext(@parastr)                   'parameter einlesen
    if byte[@parastr][0] == "/"                         'option?
      case byte[@parastr][1]
        "?": ios.print(@help)
        "h": if ios.paranext(@parastr)
               setaddr(@parastr)
        "d": ios.paranext(@remdir)
        "f": ios.paranext(@filename)
        "u": ios.paranext(@username)
        "p": ios.paranext(@password)
        "s": save2card := TRUE
        other: ios.print(@help)

  ifnot byte[@filename][0] == 0
    ifnot ftpconnect
      ifnot ftplogin
        ifnot ftpcwd
          if ftppasv
            ftpretr
  else
    ios.print(@strNoFile)


  ftpclose
  ios.stop

PRI ftpconnect

  ifnot (ip_addr)  ' Adresse 0.0.0.0
    ios.print(@strNoHost)
    if ios.rtcTest                                        'RTC chip available?
      ip_addr := ios.getNVSRAM(NVRAM_IPBOOT) << 24
      ip_addr += ios.getNVSRAM(NVRAM_IPBOOT+1) << 16
      ip_addr += ios.getNVSRAM(NVRAM_IPBOOT+2) << 8
      ip_addr += ios.getNVSRAM(NVRAM_IPBOOT+3)
    else
      ios.sddmset(ios#DM_USER)                            'u-marker setzen
      ios.sddmact(ios#DM_SYSTEM)                          's-marker aktivieren
      ifnot ios.sdopen("R",@strNVRAMFile)
        ios.sdseek(NVRAM_IPBOOT)
        ip_addr := ios.sdgetc << 24
        ip_addr += ios.sdgetc << 16
        ip_addr += ios.sdgetc << 8
        ip_addr += ios.sdgetc
        ios.sdclose
      ios.sddmact(ios#DM_USER)                            'u-marker aktivieren
    if (ip_addr)
      ios.print(@strUseBoot)
    else
      return(-1)
#ifdef __DEBUG
  ios.print(@strStartLAN)
#endif
  ios.lanstart
  ios.print(@strConnect)
  if (handleidx_control := ios.lan_connect(ip_addr, 21)) == $FF
    ios.print(@strErrorNoSock)
    return(-1)
  ifnot (ios.lan_waitconntimeout(handleidx_control, 2000))
    ios.print(@strErrorConnect)
    return(-1)
#ifdef __DEBUG
  ios.print(@strConnected)
#endif
  ifnot getResponse(string("220 "))
    ios.print(@strError220)
    return(-1)
  return(0)

PRI ftpclose

  ifnot handleidx_control == $FF
    ios.lan_close(handleidx_control)
    handleidx_control := $FF
  ifnot handleidx_data == $FF
    ios.lan_close(handleidx_data)
    handleidx_data := $FF

PRI ftplogin | pwreq, respOK, hiveid

  pwreq := FALSE
  respOK := FALSE

  sendStr(string("USER "))
  if strsize(@username)
    sendStr(@username)
    sendStr(string(13,10))
  else
    sendStr(string("anonymous",13,10))

  repeat until readLine == -1
#ifdef __DEBUG
    ios.print(string(" < "))
    ios.print(@strTemp)
    ios.printnl
#endif
    strTemp[4] := 0
    if strcomp(@strTemp, string("230 "))
      respOk := TRUE
      quit
    elseif strcomp(@strTemp, string("331 "))
      pwreq := TRUE
      respOk := TRUE
      quit
  ifnot respOK
    ios.print(@strErrorLogin)
    return(-1)

  ifnot pwreq
    return(0)

  sendStr(string("PASS "))
  if strsize(@password)
    sendStr(@password)
    sendStr(string(13,10))
  else
    if ios.rtcTest                                        'RTC chip available?
      hiveid := ios.getNVSRAM(NVRAM_HIVE)
      hiveid += ios.getNVSRAM(NVRAM_HIVE+1) << 8
      hiveid += ios.getNVSRAM(NVRAM_HIVE+2) << 16
      hiveid += ios.getNVSRAM(NVRAM_HIVE+3) << 24
    else
      ios.sddmset(ios#DM_USER)                            'u-marker setzen
      ios.sddmact(ios#DM_SYSTEM)                          's-marker aktivieren
      ifnot ios.sdopen("R",@strNVRAMFile)
        ios.sdseek(NVRAM_HIVE)
        hiveid := ios.sdgetc
        hiveid += ios.sdgetc << 8
        hiveid += ios.sdgetc << 16
        hiveid += ios.sdgetc << 24
        ios.sdclose
      ios.sddmact(ios#DM_USER)                            'u-marker aktivieren
    sendStr(string("anonymous@hive"))
    sendStr(str.trimCharacters(num.ToStr(hiveid, num#DEC)))
    sendStr(string(13,10))

  ifnot getResponse(string("230 "))
    ios.print(@strErrorPass)
    return(-1)

  return(0)

PRI ftpcwd | i

  if byte[@remdir][0] == 0
    i := sendStr(string("CWD ")) || sendStr(@defdir) || sendStr(string(13,10))
  else
    i := sendStr(string("CWD ")) || sendStr(@remdir) || sendStr(string(13,10))
  if i
    ios.print(@strErrorCWD)
    return(-1)
  ifnot getResponse(string("250 "))
    ios.print(@strError250)
    ios.printchar("(")
    ios.print(@strTemp+4)
    ios.print(string(")",13))
    return(-1)
  return(0)

PRI ftppasv : port | i, k, port256, port1

  port := 0
  port256 := 0
  port1 := 0
  k := 0

  if sendStr(string("PASV",13,10))
    return(0)

  repeat until readLine == -1
#ifdef __DEBUG
    ios.print(string(" < "))
    ios.print(@strTemp)
    ios.printnl
#endif
    strTemp[4] := 0
    if strcomp(@strTemp, string("227 "))
      repeat i from 5 to 126
        if (strTemp[i] == 0) OR (strTemp[i] == 13) OR (strTemp[i] == 10)
          quit
        if strTemp[i] == 44 'Komma
          strTemp[i] := 0
          k++
          if k == 4         '4. Komma, Port Teil 1 folgt
            port256 := i + 1
          if k == 5         '5. Komma, Port Teil 2 folgt
            port1 := i + 1
        if strTemp[i] == 41 'Klammer zu
          strTemp[i] := 0
          if (port256 & port1)
            port := (num.FromStr(@strTemp+port256, num#DEC) * 256) + num.FromStr(@strTemp+port1, num#DEC)
      quit

  if (port == 0)
    ios.print(@strErrorPasvPort)
    return(0)
#ifdef __DEBUG
  ios.print(@strOpenPasv)
  ios.print(num.ToStr(port, num#DEC))
  ios.printnl
#endif
  if (handleidx_data := ios.lan_connect(ip_addr, port)) == $FF
    ios.print(@strErrorSockPasv)
    return(0)
  ifnot (ios.lan_waitconntimeout(handleidx_data, 2000))
    ios.print(@strErrorPasvConn)
    return(0)

PRI ftpretr | len, respOK

  if sendStr(string("TYPE I",13,10))
    ios.print(@strErrorSendType)
    return(-1)
  ifnot getResponse(string("200 "))
    ios.print(@strErrorChType)
    return(-1)

  if sendStr(string("SIZE ")) || sendStr(@filename) || sendStr(string(13,10))
    ios.print(@strErrorSendSize)
    return(-1)
  ifnot getResponse(string("213"))
    ios.print(@strErrorSize)
    ios.printchar("(")
    ios.print(@strTemp+4)
    ios.print(string(")",13))
    return(-1)
  ifnot(len := num.FromStr(@strTemp+4, num#DEC))
    ios.print(@strErrorGetSize)
    return(-1)

  ios.print(@strGetFile)
  if sendStr(string("RETR ")) || sendStr(@filename) || sendStr(string(13,10))
    ios.print(@strErrorSendFN)
    return -1
  respOK := FALSE
  repeat until readLine == -1
#ifdef __DEBUG
    ios.print(string(" < "))
    ios.print(@strTemp)
    ios.printnl
#endif
    strTemp[4] := 0
    if strcomp(@strTemp, string("150 "))
      respOk := TRUE
      quit
    elseif strcomp(@strTemp, string("125 "))
      respOk := TRUE
      quit
  ifnot respOK
    ios.print(@strErrorRetr)
    ios.printchar("(")
    ios.print(@strTemp+4)
    ios.print(string(")",13))
    return(-1)

  if ios.lan_rxdata(handleidx_data, @filename, len)
    ios.print(@strErrorRXData)
    return(-1)

  ifnot getResponse(string("226 "))
    ios.print(@strErrorRetrOK)
    return(-1)

  if save2card
    ios.print(@strWrite2SD)
    writeToSDCard

PRI writeToSDCard | fnr, len, i

  fnr := ios.rd_open(@filename)
  ifnot fnr == -1
    len := ios.rd_len(fnr)
    ios.sddel(@filename)                                   'falls alte Datei auf SD-Card vorhanden, diese löschen
    ifnot ios.sdnewfile(@filename)
      ifnot ios.sdopen("W",@filename)
        i := 0
        ios.sdxputblk(fnr,len)                          'Daten als Block schreiben
        ios.sdclose
        ios.rd_del(@filename)
    ios.rd_close(fnr)

PRI setaddr (ipaddr) | pos, count                       'IP-Adresse in Variable schreiben

  count := 3
  repeat while ipaddr
    pos := str.findCharacter(ipaddr, ".")
    if(pos)
      byte[pos++] := 0
    ip_addr += num.FromStr(ipaddr, num#DEC) << (8*count--)
    ipaddr := pos
    if(count == -1)
      quit

PRI getResponse (strOk) : respOk | len

  respOk := FALSE

  repeat until readLine == -1
#ifdef __DEBUG
    ios.print(string(" < "))
    ios.print(@strTemp)
    ios.printnl
#endif
    strTemp[strsize(strOk)] := 0
    if strcomp(@strTemp, strOk)
      respOk := TRUE
      quit

  return respOk

PRI readLine | i, ch

  repeat i from 0 to 126
    ch := ios.lan_rxtime(handleidx_control, 2000)
    if ch == 13
      ch := ios.lan_rxtime(handleidx_control, 2000)
    if ch == -1 or ch == 10
      quit
    strTemp[i] := ch

  strTemp[i] := 0

  return ch 'letztes Zeichen oder -1, wenn keins mehr empfangen

PRI sendStr (strSend) : error

#ifdef __DEBUG
  ios.print(string(" > "))
  ios.print(strSend)
  ios.printnl
#endif
  error := ios.lan_txdata(handleidx_control, strSend, strsize(strSend))

DAT ' Locale

#ifdef __LANG_EN
  'locale: english

  defdir           byte  "/hive/sdcard/system",0

  strNoNetwork     byte 13,"Administra doesn't provide network functions!",13,"Please load admnet.",13,0
  strNoFile        byte "No file to download specified, exit...",13,0
  strNoHost        byte "No host (ftp server) specified (parameter /h)",13,0
  strUseBoot       byte "Using boot server (set with ipconfig).",13,0
  strStartLAN      byte "Starting LAN...",13,0
  strConnect       byte "Connecting to ftp server...",13,0
  strErrorNoSock   byte "No free socket.",13,0
  strErrorConnect  byte "Couldn't connect to ftp server.",13,0
  strConnected     byte "Connected to ftp server, waiting for answer...",13,0
  strError220      byte "Ftp server doesn't acknowledge the connection (220).",13,0
  strErrorLogin    byte "Ftp server doesn't acknowledge the login (230/331)",13,0
  strErrorPass     byte "Ftp server doesn't acknowledge the password (230)",13,0
  strErrorCWD      byte "Error sendig remote directory",13,0
  strError250      byte "Ftp server doesn't acknowledge the directory change (250).",13,0
  strErrorPasvPort byte "Couldn't get the passive port.",13,0
  strOpenPasv      byte "Open Connection to passive port ",0
  strErrorSockPasv byte "No free socket fpr passive connection.",13,0
  strErrorPasvConn byte "Couldn't connect to passive port.",13,0
  strErrorSendType byte "Error sending file type",13,0
  strErrorChType   byte "Ftp serve couldn't change file type (200).",13,0
  strErrorSendSize byte "Error sending SIZE command",13,0
  strErrorSize     byte "Ftp server couldn't send file size (213).",13,"File not found? SIZE not supported?",13,0
  strErrorGetSize  byte "Couldn't get file size.",13,0
  strGetFile       byte "Retrieve file, please wait...",13,0
  strErrorSendFN   byte "Error sending file name.",13,0
  strErrorRetr     byte "Ftp server couldn't send file (150/125).",13,0
  strErrorRXData   byte "Error retrieving file.",13,0
  strErrorRetrOK   byte "Ftp server doesn't acknowledge sending of file (226).",13,0
  strWrite2SD      byte "Saving to sd card...",13,0

  help             byte  "/?            : Help",13
                   byte  "/h <a.b.c.d>  : host ip address (ftp server)",13
                   byte  "                (default: boot server from ipconfig)",13
                   byte  "/d <directory>: change to remote directory",13
                   byte  "                (default: /hive/sdcard/system)",13
                   byte  "/f <filename> : download <filename>",13
                   byte  "/u <username> : Username at ftp server",13
                   byte  "                (default: anonymous)",13
                   byte  "/p <password> : password at ftp server",13
                   byte  "                (default: anonymous@hive<hive id>)",13
                   byte  "/s            : save file to sd card",13
                   byte  0

#else
  'default locale: german

  defdir           byte  "/hive/sdcard/system",0

  strNoNetwork     byte 13,"Administra stellt keine Netzwerk-Funktionen zur Verfügung!",13,"Bitte admnet laden.",13,0
  strNoFile        byte "Keine Datei zum Downloaden angegeben, beende...",13,0
  strNoHost        byte "FTP-Server nicht angegeben (Parameter /h)",13,0
  strUseBoot       byte "Verwende Boot-Server (mit ipconfig gesetzt).",13,0
  strStartLAN      byte "Starte LAN...",13,0
  strConnect       byte "Verbinde mit FTP-Server...",13,0
  strErrorNoSock   byte "Kein Socket frei...",13,0
  strErrorConnect  byte "Verbindung mit FTP-Server konnte nicht aufgebaut werden.",13,0
  strConnected     byte "Verbindung mit FTP-Server hergestellt, warte auf Antwort...",13,0
  strError220      byte "FTP-Server bestätigt den Verbindungsaufbau nicht (220).",13,0
  strErrorLogin    byte "FTP-Server hat Login nicht bestätigt (230/331)",13,0
  strErrorPass     byte "FTP-Server hat das Paßwort nicht bestätigt (230)",13,0
  strErrorCWD      byte "Fehler beim Senden des Verzeichnisses",13,0
  strError250      byte "FTP-Server hat den Verzeichniswechsel nicht bestätigt (250).",13,0
  strErrorPasvPort byte "Konnte zu öffnenden Passiv-Port nicht ermitteln.",13,0
  strOpenPasv      byte "Öffne Verbindung zu Passiv-Port ",0
  strErrorSockPasv byte "Kein Socket für Passiv-Verbindung frei...",13,0
  strErrorPasvConn byte "Passiv-Verbindung mit FTP-Server konnte nicht aufgebaut werden.",13,0
  strErrorSendType byte "Fehler beim Senden des Types",13,0
  strErrorChType   byte "FTP-Server konnte Übertragungs-Typ nicht ändern (200).",13,0
  strErrorSendSize byte "Fehler beim Senden des SIZE-Kommandos",13,0
  strErrorSize     byte "FTP-Server kann die Datei-Größe nicht übermitteln (213).",13,"Datei nicht vorhanden? SIZE nicht unterstützt?",13,0
  strErrorGetSize  byte "Konnte Filegröße nicht ermitteln.",13,0
  strGetFile       byte "Empfange Datei, bitte warten...",13,0
  strErrorSendFN   byte "Fehler beim Senden des Filenamens.",13,0
  strErrorRetr     byte "FTP-Server kann die Datei nicht senden (150/125).",13,0
  strErrorRXData   byte "Fehler beim Empfang der Datei.",13,0
  strErrorRetrOK   byte "FTP-Server hat den Empfang durch den Client nicht bestätigt (226).",13,0
  strWrite2SD      byte "Speichere auf SD-Card...",13,0

  help             byte  "/?              : Hilfe",13
                   byte  "/h <a.b.c.d>    : FTP-Server-Adresse (Host)",13
                   byte  "                  (default: mit ipconfig gesetzter Boot-Server)",13
                   byte  "/d <verzeichnis>: in entferntes Verzeichnis wechseln",13
                   byte  "                  (default: /hive/sdcard/system)",13
                   byte  "/f <dateiname>  : Download <dateiname>",13
                   byte  "/u <username>   : Benutzername am FTP-Server",13
                   byte  "                  (default: anonymous)",13
                   byte  "/p <password>   : Paßwort am FTP-Server",13
                   byte  "                  (default: anonymous@hive<Hive-Id>)",13
                   byte  "/s              : Datei auf SD-Card speichern",13
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
