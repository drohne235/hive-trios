{{
  Ethernet TCP/IP Socket Layer Driver (IPv4)
  ------------------------------------------
  
  Copyright (c) 2006-2009 Harrison Pham <harrison@harrisonpham.com>
   
  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:
   
  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.
   
  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.

  The latest version of this software can be obtained from
  http://hdpham.com/PropTCP and http://obex.parallax.com/
}}

'' NOTICE:  All buffer sizes must be a power of 2!

CON
' ***************************************
' **      Versioning Information       **
' ***************************************
  version    = 5                ' major version
  release    = 2                ' minor version
  apiversion = 8                ' api compatibility version

' ***************************************
' **     User Definable Settings       **
' ***************************************
  sNumSockets     = 4           ' max number of concurrent registered sockets (max of 255)

' *** End of user definable settings, don't edit anything below this line!!!
' *** All IP/MAC settings are defined by calling the start(...) method

CON
' ***************************************
' **      Return Codes / Errors        **
' ***************************************

  RETBUFFEREMPTY  = -1          ' no data available
  RETBUFFERFULL   = -1          ' buffer full

  ERRGENERIC      = -1          ' generic errors
  
  ERR             = -100        ' error codes start at -100
  ERRBADHANDLE    = ERR - 1     ' bad socket handle
  ERROUTOFSOCKETS = ERR - 2     ' no free sockets available
  ERRSOCKETCLOSED = ERR - 3     ' socket closed, could not perform operation

OBJ
  nic : "adm-enc28j60"

  'ser : "SerialMirror"
  'stk : "Stack Length"

CON
' ***************************************
' **   Socket Constants and Offsets    **
' ***************************************

' Socket states (user should never touch these)
  SCLOSED          = 0          ' closed, handle not used
  SLISTEN          = 1          ' listening, in server mode
  SSYNSENT         = 2          ' SYN sent, server mode, waits for ACK
  SSYNSENTCL       = 3          ' SYN sent, client mode, waits for SYN+ACK
  SESTABLISHED     = 4          ' established connection (either SYN+ACK, or ACK+Data)
  SCLOSING         = 5          ' connection is being forced closed by code
  SCLOSING2        = 6          ' closing, we are waiting for a fin now
  SFORCECLOSE      = 7          ' force connection close (just RSTs, no waiting for FIN or anything)
  SCONNECTINGARP1  = 8          ' connecting, next step: send arp request
  SCONNECTINGARP2  = 9          ' connecting, next step: arp request sent, waiting for response
  SCONNECTINGARP2G = 10         ' connecting, next step: arp request sent, waiting for response [GATEWAY REQUEST]
  SCONNECTING      = 11         ' connecting, next step: got mac address, send SYN

' ***************************************
' **  TCP State Management Constants   **
' ***************************************
  TIMEOUTMS       = 500         ' (milliseconds) timeout before a retransmit occurs
  RSTTIMEOUTMS    = 2000        ' (milliseconds) timeout before a RST is sent to close the connection
  WINDOWUPDATEMS  = 25          ' (milliseconds) window advertisement frequency

  MAXUNACKS       = 6           ' max number of unacknowledged retransmits before the stack auto closes the socket
                                ' timeout = TIMEOUTMS * MAXUNACKS (default: 500ms * 5 = 3000ms)

  EPHPORTSTART    = 49152       ' ephemeral port start
  EPHPORTEND      = 65535       ' end

  MAXPAYLOAD      = 1200        ' maximum TCP payload (data) in bytes, this only applies when your txbuffer_length > payload size

DAT
' ***************************************
' **          Global Variables         **
' ***************************************
  cog           long 0                                    ' cog index (for stopping / starting)
  stack         long 0[128]                               ' stack for new cog (currently ~74 longs, using 128 for expansion)

  mac_ptr       long 0                                    ' mac address pointer

  pkt_id        long 0                                    ' packet fragmentation id
  pkt_isn       long 0                                    ' packet initial sequence number

  ip_ephport    word 0                                    ' packet ephemeral port number (49152 to 65535)

  pkt_count     byte 0                                    ' packet count
  
  lock_id       byte 0                                    ' socket handle lock

  packet        byte 0[nic#MAXFRAME]                      ' the ethernet frame

' ***************************************
' **        IP Address Defaults        **
' ***************************************
  ' NOTE: All of the MAC/IP variables here contain default values that will
  '       be used if override values are not provided as parameters in start().
                long                                      ' long alignment for addresses
  ip_addr       byte    10, 10, 1, 4                      ' device's ip address
  ip_subnet     byte    255, 255, 255, 0                  ' network subnet
  ip_gateway    byte    10, 10, 1, 254                    ' network gateway (router)
  ip_dns        byte    10, 10, 1, 254                    ' network dns 

' ***************************************
' **        Socket Data Arrays         **
' ***************************************

                long
  SocketArrayStart
  lMySeqNum     long    0[sNumSockets]
  lMyAckNum     long    0[sNumSockets]
  lSrcIp        long    0[sNumSockets]
  lTime         long    0[sNumSockets]
  
                word
  wSrcPort      word    0[sNumSockets]
  wDstPort      word    0[sNumSockets]
  wLastWin      word    0[sNumSockets]
  wLastTxLen    word    0[sNumSockets]
  wNotAcked     word    0[sNumSockets]

                byte
  bSrcMac       byte    0[sNumSockets * 6]
  bConState     byte    0[sNumSockets]
  SocketArrayEnd  

' ***************************************
' **      Circular Buffer Arrays       **
' ***************************************
                        word
  FifoDataStart
  rx_head               word    0[sNumSockets]          ' rx head array
  rx_tail               word    0[sNumSockets]          ' rx tail array
  tx_head               word    0[sNumSockets]          ' tx head array
  tx_tail               word    0[sNumSockets]          ' tx tail array

  tx_tailnew            word    0[sNumSockets]          ' the new tx_tail value (unacked data)

  rxbuffer_length       word    0[sNumSockets]          ' each socket's buffer sizes
  txbuffer_length       word    0[sNumSockets]

  rxbuffer_mask         word    0[sNumSockets]          ' each socket's buffer masks for capping buffer sizes 
  txbuffer_mask         word    0[sNumSockets]

                        long
  tx_bufferptr          long    0[sNumSockets]          ' pointer addresses to each socket's buffer spaces
  rx_bufferptr          long    0[sNumSockets]
  FifoDataEnd 

PUB start(cs, sck, si, so, xtalout, macptr, ipconfigptr)
'' Start the TCP/IP Stack (requires 2 cogs)
'' Only call this once, otherwise you will get conflicts
''   macptr      = HUB memory pointer (address) to 6 contiguous mac address bytes
''   ipconfigptr = HUB memory pointer (address) to ip configuration block (16 bytes)
''                 Must be in order: ip_addr, ip_subnet, ip_gateway, ip_dns

  stop
  'stk.Init(@stack, 128)

  ' zero socket data arrays (clean up any dead stuff from previous instance)
  bytefill(@SocketArrayStart, 0, @SocketArrayEnd - @SocketArrayStart)

  ' reset buffer pointers, zeros a contigous set of bytes, starting at rx_head
  bytefill(@FifoDataStart, 0, @FifoDataEnd - @FifoDataStart)

  ' start new cog with tcp stack
  cog := cognew(engine(cs, sck, si, so, xtalout, macptr, ipconfigptr), @stack) + 1

PUB stop
'' Stop the driver

  if cog
    cogstop(cog~ - 1)           ' stop the tcp engine
    nic.stop                    ' stop nic driver (kills spi engine)
    lockclr(lock_id)            ' clear lock before returning it to the pool
    lockret(lock_id)            ' return the lock to the lock pool

PRI engine(cs, sck, si, so, xtalout, macptr, ipconfigptr) | i

  lock_id := locknew                                                            ' checkout a lock from the HUB
  lockclr(lock_id)                                                              ' clear the lock, just in case it was in a bad state

  ' Start the ENC28J60 driver in a new cog
  nic.start(cs, sck, si, so, xtalout, macptr)                                   ' init the nic
  
  if ipconfigptr > -1                                                           ' init ip configuration
    bytemove(@ip_addr, ipconfigptr, 16)
  
  mac_ptr := nic.get_mac_pointer                                                ' get the local mac address pointer 

  ip_ephport := EPHPORTSTART                                                    ' set initial ephemeral port number (might want to random seed this later)
  
  i := 0
  nic.banksel(nic#EPKTCNT)                                                      ' select packet count bank
  repeat
    pkt_count := nic.rd_cntlreg(nic#EPKTCNT)
    if pkt_count > 0
      service_packet                                                            ' handle packet
      nic.banksel(nic#EPKTCNT)                                                  ' re-select the packet count bank

    ++i
    if i > 10                                                                   ' perform send tick
      repeat while lockset(lock_id) 
      tick_tcpsend                                                              '  occurs every 10 cycles, since incoming packets more important
      lockclr(lock_id)

      i := 0
      nic.banksel(nic#EPKTCNT)                                                  ' re-select the packet count bank

PRI service_packet

  ' lets process this frame
  nic.get_frame(@packet)

  ' check for arp packet type (highest priority obviously)
  if packet[enetpacketType0] == $08 AND packet[enetpacketType1] == $06
    if packet[constant(arp_hwtype + 1)] == $01 AND packet[arp_prtype] == $08 AND packet[constant(arp_prtype + 1)] == $00 AND packet[arp_hwlen] == $06 AND packet[arp_prlen] == $04
      if packet[arp_tipaddr] == ip_addr[0] AND packet[constant(arp_tipaddr + 1)] == ip_addr[1] AND packet[constant(arp_tipaddr + 2)] == ip_addr[2] AND packet[constant(arp_tipaddr + 3)] == ip_addr[3]
        case packet[constant(arp_op + 1)]
          $01 : handle_arp
          $02 : repeat while lockset(lock_id)
                handle_arpreply
                lockclr(lock_id)
        '++count_arp
  else
    if packet[enetpacketType0] == $08 AND packet[enetpacketType1] == $00
      if packet[ip_destaddr] == ip_addr[0] AND packet[constant(ip_destaddr + 1)] == ip_addr[1] AND packet[constant(ip_destaddr + 2)] == ip_addr[2] AND packet[constant(ip_destaddr + 3)] == ip_addr[3]
        case packet[ip_proto]
          'PROT_ICMP : 'handle_ping
                      'ser.str(stk.GetLength(0, 0))
                      'stk.GetLength(30, 19200)
                      '++count_ping
          PROT_TCP :  repeat while lockset(lock_id)
                      \handle_tcp                                               ' handles abort out of tcp handlers (no socket found)
                      lockclr(lock_id)
                      '++count_tcp
          'PROT_UDP :  ++count_udp

' *******************************
' ** Protocol Receive Handlers **
' *******************************
PRI handle_arp | i
  nic.start_frame

  ' destination mac address
  repeat i from 0 to 5
    nic.wr_frame(packet[enetpacketSrc0 + i])

  ' source mac address
  repeat i from 0 to 5
    nic.wr_frame(BYTE[mac_ptr][i])

  nic.wr_frame($08)             ' arp packet
  nic.wr_frame($06)

  nic.wr_frame($00)             ' 10mb ethernet
  nic.wr_frame($01)

  nic.wr_frame($08)             ' ip proto
  nic.wr_frame($00)

  nic.wr_frame($06)             ' mac addr len
  nic.wr_frame($04)             ' proto addr len

  nic.wr_frame($00)             ' arp reply
  nic.wr_frame($02)

  ' write ethernet module mac address
  repeat i from 0 to 5
    nic.wr_frame(BYTE[mac_ptr][i])

  ' write ethernet module ip address
  repeat i from 0 to 3
    nic.wr_frame(ip_addr[i])

  ' write remote mac address
  repeat i from 0 to 5
    nic.wr_frame(packet[enetpacketSrc0 + i])

  ' write remote ip address
  repeat i from 0 to 3
    nic.wr_frame(packet[arp_sipaddr + i])

  return nic.send_frame

PRI handle_arpreply | handle, ip, found
  ' Gets arp reply if it is a response to an ip we have

  ip := (packet[constant(arp_sipaddr + 3)] << 24) + (packet[constant(arp_sipaddr + 2)] << 16) + (packet[constant(arp_sipaddr + 1)] << 8) + (packet[arp_sipaddr])

  found := false
  if ip == LONG[@ip_gateway]
    ' find a handle that wants gateway mac
    repeat handle from 0 to constant(sNumSockets - 1)
      if bConState[handle] == SCONNECTINGARP2G
        found := true
        quit
  else
    ' find the one that wants this arp
    repeat handle from 0 to constant(sNumSockets - 1)
      if bConState[handle] == SCONNECTINGARP2
        if lSrcIp[handle] == ip
          found := true
          quit
          
  if found
    bytemove(@bSrcMac[handle * 6], @packet + arp_shaddr, 6)
    bConState[handle] := SCONNECTING

'PRI handle_ping
  ' Not implemented yet (save on space!)
  
PRI handle_tcp | i, ptr, handle, srcip, dstport, srcport, datain_len
  ' Handles incoming TCP packets

  srcip := packet[ip_srcaddr] << 24 + packet[constant(ip_srcaddr + 1)] << 16 + packet[constant(ip_srcaddr + 2)] << 8 + packet[constant(ip_srcaddr + 3)]
  dstport := packet[TCP_destport] << 8 + packet[constant(TCP_destport + 1)]
  srcport := packet[TCP_srcport] << 8 + packet[constant(TCP_srcport + 1)]

  handle := find_socket(srcip, dstport, srcport)   ' if no sockets avail, it will abort out of this function

  ' at this point we assume we have an active socket, or a socket available to be used
  datain_len := ((packet[ip_pktlen] << 8) + packet[constant(ip_pktlen + 1)]) - ((packet[ip_vers_len] & $0F) * 4) - (((packet[TCP_hdrlen] & $F0) >> 4) * 4)

  if (bConState[handle] == SSYNSENT OR bConState[handle] == SESTABLISHED) AND (packet[TCP_hdrflags] & TCP_ACK) AND datain_len > 0
    ' ACK, without SYN, with data

    ' set socket state, established session
    bConState[handle] := SESTABLISHED
    
    i := packet[constant(TCP_seqnum + 3)] << 24 + packet[constant(TCP_seqnum + 2)] << 16 + packet[constant(TCP_seqnum + 1)] << 8 + packet[TCP_seqnum]
    if lMyAckNum[handle] == i
      if datain_len =< (rxbuffer_mask[handle] - ((rx_head[handle] - rx_tail[handle]) & rxbuffer_mask[handle]))
        ' we have buffer space
        ptr := rx_bufferptr[handle]
        if (datain_len + rx_head[handle]) > rxbuffer_length[handle]
          bytemove(ptr + rx_head[handle], @packet[TCP_data], rxbuffer_length[handle] - rx_head[handle])
          bytemove(ptr, @packet[TCP_data] + (rxbuffer_length[handle] - rx_head[handle]), datain_len - (rxbuffer_length[handle] - rx_head[handle]))
        else
          bytemove(ptr + rx_head[handle], @packet[TCP_data], datain_len)
        rx_head[handle] := (rx_head[handle] + datain_len) & rxbuffer_mask[handle]
      else
        datain_len := 0  

    else
      ' we had a bad ack number, meaning lost or out of order packet
      ' we have to wait for the remote host to retransmit in order
      datain_len := 0
     
    ' recalculate ack number
    lMyAckNum[handle] := conv_endianlong(conv_endianlong(lMyAckNum[handle]) + datain_len)

    ' ACK response
    build_ipheaderskeleton(handle)
    build_tcpskeleton(handle, TCP_ACK)
    send_tcpfinal(handle, 0)

  elseif (bConState[handle] == SSYNSENTCL) AND (packet[TCP_hdrflags] & TCP_SYN) AND (packet[TCP_hdrflags] & TCP_ACK)
    ' We got a server response, so we ACK it

    bytemove(@lMySeqNum[handle], @packet + TCP_acknum, 4)
    bytemove(@lMyAckNum[handle], @packet + TCP_seqnum, 4)
    
    lMyAckNum[handle] := conv_endianlong(conv_endianlong(lMyAckNum[handle]) + 1)

    ' ACK response
    build_ipheaderskeleton(handle)
    build_tcpskeleton(handle, TCP_ACK)
    send_tcpfinal(handle, 0)

    ' set socket state, established session
    bConState[handle] := SESTABLISHED
  
  elseif (bConState[handle] == SLISTEN) AND (packet[TCP_hdrflags] & TCP_SYN)
    ' Reply to SYN with SYN + ACK

    ' copy mac address so we don't have to keep an ARP table
    bytemove(@bSrcMac[handle * 6], @packet + enetpacketSrc0, 6)

    ' copy ip, port data
    bytemove(@lSrcIp[handle], @packet + ip_srcaddr, 4)
    bytemove(@wSrcPort[handle], @packet + TCP_srcport, 2)
    bytemove(@wDstPort[handle], @packet + TCP_destport, 2)

    ' get updated ack numbers
    bytemove(@lMyAckNum[handle], @packet + TCP_seqnum, 4)

    lMyAckNum[handle] := conv_endianlong(conv_endianlong(lMyAckNum[handle]) + 1)
    lMySeqNum[handle] := conv_endianlong(++pkt_isn)               ' Initial seq num (random)

    build_ipheaderskeleton(handle)
    build_tcpskeleton(handle, constant(TCP_SYN | TCP_ACK))
    send_tcpfinal(handle, 0)      

    ' incremement the sequence number for the next packet (it will be for an established connection)                                          
    lMySeqNum[handle] := conv_endianlong(conv_endianlong(lMySeqNum[handle]) + 1)

    ' set socket state, waiting for establish
    bConState[handle] := SSYNSENT
   
  elseif (bConState[handle] == SESTABLISHED OR bConState[handle] == SCLOSING2) AND (packet[TCP_hdrflags] & TCP_FIN)
    ' Reply to FIN with RST

    ' get updated sequence and ack numbers (gaurantee we have correct ones to kill connection with)
    bytemove(@lMySeqNum[handle], @packet + TCP_acknum, 4)
    bytemove(@lMyAckNum[handle], @packet + TCP_seqnum, 4)
                                              
    'LONG[handle_addr + sMyAckNum] := conv_endianlong(conv_endianlong(LONG[handle_addr + sMyAckNum]) + 1)

    build_ipheaderskeleton(handle)
    build_tcpskeleton(handle, TCP_RST)
    send_tcpfinal(handle, 0)

    ' set socket state, now free
    bConState[handle] := SCLOSED
    return
    
  elseif (bConState[handle] == SSYNSENT) AND (packet[TCP_hdrflags] & TCP_ACK)
    ' if just an ack, and we sent a syn before, then it's established
    ' this just gives us the ability to send on connect
    bConState[handle] := SESTABLISHED
  
  elseif (packet[TCP_hdrflags] & TCP_RST)
    ' Reset, reset states
    bConState[handle] := SCLOSED
    return

  if (bConState[handle] == SESTABLISHED OR bConState[handle] == SCLOSING) AND (packet[TCP_hdrflags] & TCP_ACK)
    wNotAcked[handle] := 0                              ' reset retransmit counter
    ' check to see if our last sent data has been ack'd
    i := packet[TCP_acknum] << 24 + packet[constant(TCP_acknum + 1)] << 16 + packet[constant(TCP_acknum + 2)] << 8 + packet[constant(TCP_acknum + 3)]
    if i == (conv_endianlong(lMySeqNum[handle]) + wLastTxLen[handle])
      ' we received an ack for our last sent packet, so we update our sequence number and buffer pointers
      lMySeqNum[handle] := conv_endianlong(conv_endianlong(lMySeqNum[handle]) + wLastTxLen[handle])
      tx_tail[handle] := tx_tailnew[handle]
      wLastTxLen[handle] := 0
        
      tcpsend(handle)                                   ' send data

PRI build_ipheaderskeleton(handle) | hdrlen, hdr_chksum
  
  bytemove(@packet + ip_destaddr, @lSrcIp[handle], 4)                           ' Set destination address

  bytemove(@packet + ip_srcaddr, @ip_addr, 4)                                   ' Set source address

  bytemove(@packet + enetpacketDest0, @bSrcMac[handle * 6], 6)                  ' Set destination mac address
  
  bytemove(@packet + enetpacketSrc0, mac_ptr, 6)                                ' Set source mac address

  packet[enetpacketType0] := $08
  packet[constant(enetpacketType0 + 1)] := $00
  
  packet[ip_vers_len] := $45
  packet[ip_tos] := $00

  ++pkt_id
  
  packet[ip_id] := pkt_id >> 8                                                  ' Used for fragmentation
  packet[constant(ip_id + 1)] := pkt_id

  packet[ip_frag_offset] := $40                                                 ' Don't fragment
  packet[constant(ip_frag_offset + 1)] := 0
                                                                             
  packet[ip_ttl] := $80                                                         ' TTL = 128

  packet[ip_proto] := $06                                                       ' TCP protocol

PRI build_tcpskeleton(handle, flags) | size

  bytemove(@packet + TCP_srcport, @wDstPort[handle], 2)                         ' Source port
  bytemove(@packet + TCP_destport, @wSrcPort[handle], 2)                        ' Destination port

  bytemove(@packet + TCP_seqnum, @lMySeqNum[handle], 4)                         ' Seq Num
  bytemove(@packet + TCP_acknum, @lMyAckNum[handle], 4)                         ' Ack Num

  packet[TCP_hdrlen] := $50                                                     ' Header length
  
  packet[TCP_hdrflags] := flags                                                 ' TCP state flags

  ' we have to recalculate the window size often otherwise our stack
  ' might explode from too much data :(
  size := (rxbuffer_mask[handle] - ((rx_head[handle] - rx_tail[handle]) & rxbuffer_mask[handle]))
  wLastWin[handle] := size

  packet[TCP_window] := (size & $FF00) >> 8
  packet[constant(TCP_window + 1)] := size & $FF
  
PRI send_tcpfinal(handle, datalen) | i, tcplen, hdrlen, hdr_chksum

  tcplen := 40 + datalen                                                        ' real length = data + headers

  packet[ip_pktlen] := tcplen >> 8
  packet[constant(ip_pktlen + 1)] := tcplen

  ' calc ip header checksum
  packet[ip_hdr_cksum] := $00
  packet[constant(ip_hdr_cksum + 1)] := $00
  hdrlen := (packet[ip_vers_len] & $0F) * 4
  hdr_chksum := calc_chksum(@packet[ip_vers_len], hdrlen)  
  packet[ip_hdr_cksum] := hdr_chksum >> 8
  packet[constant(ip_hdr_cksum + 1)] := hdr_chksum

  ' calc checksum
  packet[TCP_cksum] := $00
  packet[constant(TCP_cksum + 1)] := $00
  hdr_chksum := nic.chksum_add(@packet[ip_srcaddr], 8)
  hdr_chksum += packet[ip_proto]
  i := tcplen - ((packet[ip_vers_len] & $0F) * 4)
  hdr_chksum += i
  hdr_chksum += nic.chksum_add(@packet[TCP_srcport], i)
  hdr_chksum := calc_chksumfinal(hdr_chksum)
  packet[TCP_cksum] := hdr_chksum >> 8
  packet[constant(TCP_cksum + 1)] := hdr_chksum

  tcplen += 14
  if tcplen < 60
    tcplen := 60

  ' protect from buffer overrun
  if tcplen => nic#TX_BUFFER_SIZE
    return
    
  ' send the packet
  nic.start_frame  
  nic.wr_block(@packet, tcplen)
  nic.send_frame

  lTime[handle] := cnt                      ' update last sent time (for timeout detection) 

PRI find_socket(srcip, dstport, srcport) | handle, free_handle, listen_handle
  ' Search for socket, matches ip address, port states
  ' Returns handle address (start memory location of socket)
  '  If no matches, will abort with -1
  '  If supplied with srcip = 0 then will return free unused handle, aborts with -1 if none avail
  
  free_handle := -1
  listen_handle := -1
  repeat handle from 0 to constant(sNumSockets - 1)
    if bConState[handle] <> SCLOSED
      if (lSrcIp[handle] == 0) OR (lSrcIp[handle] == conv_endianlong(srcip))
        ' ip match, ip socket srcip = 0, then will try to match dst port (find listening socket)
          if (wDstPort[handle] == conv_endianword(dstport)) {AND (WORD[handle_addr + sSrcPort] == 0 OR WORD[handle_addr + sSrcPort] == conv_endianword(srcport))}
            if wSrcPort[handle] == conv_endianword(srcport)
              ' found exact socket match (established socket)
              return handle
            elseif wSrcPort[handle] == 0
              ' found a partial match (listening socket with no peer)
              listen_handle := handle
    elseif srcip == 0
      ' found a closed (unallocated) socket, save this as a free handle if we are searching for a free handle
      free_handle := handle     ' we found a free handle, may need this later

  if srcip <> 0
    ' return the listening handle we found
    if listen_handle <> -1
      return listen_handle
  else
    ' searched for a free handle  
    if free_handle <> -1
      return free_handle 

  ' could not find a matching socket / free socket...
  abort -1

' ******************************
' ** Transmit Buffer Handlers **
' ******************************
PRI tcpsend(handle) | ptr, len
  ' Check buffers for data to send (called in main loop)

  if tx_tail[handle] == tx_head[handle]
    ' no data in buffer, so just quit
    return

  ' we have data to send, so send it
  ptr := tx_bufferptr[handle]
  len := ((tx_head[handle] - tx_tail[handle]) & txbuffer_mask[handle]) <# MAXPAYLOAD
  if (len + tx_tail[handle]) > txbuffer_length[handle]
    bytemove(@packet[TCP_data], ptr + tx_tail[handle], txbuffer_length[handle] - tx_tail[handle])
    bytemove(@packet[TCP_data] + (txbuffer_length[handle] - tx_tail[handle]), ptr, len - (txbuffer_length[handle] - tx_tail[handle]))
  else
    bytemove(@packet[TCP_data], ptr + tx_tail[handle], len)
  tx_tailnew[handle] := (tx_tail[handle] + len) & txbuffer_mask[handle]
   
  wLastTxLen[handle] := len 
   
  build_ipheaderskeleton(handle)
  build_tcpskeleton(handle, TCP_ACK {constant(TCP_ACK | TCP_PSH)})
  send_tcpfinal(handle, len)                        ' send actual data
   
  send_tcpfinal(handle, 0)                          ' send an empty packet to force the other side to ACK (hack to get around delayed acks)
   
  wNotAcked[handle]++                               ' increment unacked packet counter
   
PRI tick_tcpsend | handle, state, len

  repeat handle from 0 to constant(sNumSockets - 1)
    state := bConState[handle]

    if state == SESTABLISHED OR state == SCLOSING
      len := (rxbuffer_mask[handle] - ((rx_head[handle] - rx_tail[handle]) & rxbuffer_mask[handle]))
      if wLastWin[handle] <> len AND len => (rxbuffer_length[handle] / 2) AND ((cnt - lTime[handle]) / (clkfreq / 1000) > WINDOWUPDATEMS)
        ' update window size
        build_ipheaderskeleton(handle)
        build_tcpskeleton(handle, TCP_ACK)
        send_tcpfinal(handle, 0)

      if ((cnt - lTime[handle]) / (clkfreq / 1000) > TIMEOUTMS) OR wLastTxLen[handle] == 0
        ' send new data OR retransmit our last packet since the other side seems to have lost it
        ' the remote host will respond with another dup ack, and we will get back on track (hopefully)
        tcpsend(handle)
    
    if (state == SCLOSING)          
     
      build_ipheaderskeleton(handle)
      build_tcpskeleton(handle, constant(TCP_ACK | TCP_FIN))
      send_tcpfinal(handle, 0)
     
      ' we now wait for the other side to terminate
      bConState[handle] := SCLOSING2
     
    elseif state == SCONNECTINGARP1
      ' We need to send an arp request
     
      arp_request_checkgateway(handle)
     
    elseif state == SCONNECTING
      ' Yea! We got an arp response previously, so now we can send the SYN
     
      lMySeqNum[handle] := conv_endianlong(++pkt_isn)        
      lMyAckNum[handle] := 0
       
      build_ipheaderskeleton(handle)
      build_tcpskeleton(handle, TCP_SYN)
      send_tcpfinal(handle, 0)
     
      bConState[handle] := SSYNSENTCL
     
    elseif (state == SFORCECLOSE) OR (state == SESTABLISHED AND wNotAcked[handle] => MAXUNACKS) OR (lookdown(state: SCLOSING2, SSYNSENT, SSYNSENTCL, SCONNECTINGARP2, SCONNECTINGARP2G) {(state == SCLOSING2 OR state == SSYNSENT)} AND ((cnt - lTime[handle]) / (clkfreq / 1000) > RSTTIMEOUTMS))
      ' Force close (send RST, and say the socket is closed!)
      
      ' This is triggered when any of the following happens:
      '  1 - we don't get a response to our SSYNSENT state
      '  2 - we exceeded MAXUNACKS tcp retransmits (remote host lost)
      '  3 - we get stuck in the SSCLOSING2 state
      '  4 - we don't get a response to our client SYNSENTCL state
      '  5 - we don't get an ARP response state SCONNECTINGARP2 or SCONNECTINGARP2G
     
      build_ipheaderskeleton(handle)
      build_tcpskeleton(handle, TCP_RST)
      send_tcpfinal(handle, 0)
     
      bConState[handle] := SCLOSED

PRI arp_request_checkgateway(handle) | ip_ptr

  ip_ptr := @lSrcIp[handle]
  
  if (BYTE[ip_ptr] & ip_subnet[0]) == (ip_addr[0] & ip_subnet[0]) AND (BYTE[ip_ptr + 1] & ip_subnet[1]) == (ip_addr[1] & ip_subnet[1]) AND (BYTE[ip_ptr + 2] & ip_subnet[2]) == (ip_addr[2] & ip_subnet[2]) AND (BYTE[ip_ptr + 3] & ip_subnet[3]) == (ip_addr[3] & ip_subnet[3])   
    arp_request(conv_endianlong(LONG[ip_ptr]))
    bConState[handle] := SCONNECTINGARP2
  else
    arp_request(conv_endianlong(LONG[@ip_gateway]))
    bConState[handle] := SCONNECTINGARP2G

  lTime[handle] := cnt   
  
PRI arp_request(ip) | i
  nic.start_frame

  ' destination mac address (broadcast mac)
  repeat i from 0 to 5
    nic.wr_frame($FF)

  ' source mac address (this device)
  repeat i from 0 to 5
    nic.wr_frame(BYTE[mac_ptr][i])

  nic.wr_frame($08)             ' arp packet
  nic.wr_frame($06)

  nic.wr_frame($00)             ' 10mb ethernet
  nic.wr_frame($01)

  nic.wr_frame($08)             ' ip proto
  nic.wr_frame($00)

  nic.wr_frame($06)             ' mac addr len
  nic.wr_frame($04)             ' proto addr len

  nic.wr_frame($00)             ' arp request
  nic.wr_frame($01)

  ' source mac address (this device)
  repeat i from 0 to 5
    nic.wr_frame(BYTE[mac_ptr][i])

  ' source ip address (this device)
  repeat i from 0 to 3
    nic.wr_frame(ip_addr[i])

  ' unknown mac address area
  repeat i from 0 to 5
    nic.wr_frame($00)

  ' figure out if we need router arp request or host arp request
  ' this means some subnet masking

  ' dest ip address
  repeat i from 3 to 0
    nic.wr_frame(ip.byte[i])

  ' send the request
  return nic.send_frame
  
' *******************************
' ** IP Packet Helpers (Calcs) **
' *******************************    
PRI calc_chksum(ptr, hdrlen) : chksum
  ' Calculates IP checksums
  ' packet = pointer to IP packet
  ' returns: chksum
  ' http://www.geocities.com/SiliconValley/2072/bit33.txt
  'chksum := calc_chksumhalf(packet, hdrlen)
  chksum := nic.chksum_add(ptr, hdrlen)
  chksum := calc_chksumfinal(chksum)

PRI calc_chksumfinal(chksumin) : chksum
  ' Performs the final part of checksums
  chksum := (chksumin >> 16) + (chksumin & $FFFF)
  chksum := (!chksum) & $FFFF
  
{PRI calc_chksumhalf(packet, hdrlen) : chksum
  ' Calculates checksum without doing the final stage of calculations
  chksum := 0
  repeat while hdrlen > 1
    chksum += (BYTE[packet++] << 8) + BYTE[packet++]
    chksum := (chksum >> 16) + (chksum & $FFFF)
    hdrlen -= 2
  if hdrlen > 0              
    chksum += BYTE[packet] << 8}

' ***************************
' ** Memory Access Helpers **
' ***************************    
PRI conv_endianlong(in)
  'return (in << 24) + ((in & $FF00) << 8) + ((in & $FF0000) >> 8) + (in >> 24)  ' we can sometimes get away with shifting without masking, since shifts kill extra bits anyways
  return (in.byte[0] << 24) + (in.byte[1] << 16) + (in.byte[2] << 8) + (in.byte[3])
  
PRI conv_endianword(in)
  'return ((in & $FF) << 8) + ((in & $FF00) >> 8)
  return (in.byte[0] << 8) + (in.byte[1])

PRI _handleConvert(userHandle, ptrHandle) | handle
' Checks to see if a handle index is valid
' Aborts if the handle is invalid

  handle := userHandle.byte[0]                          ' extract the handle index from the lower 8 bits

  if handle < 0 OR handle > constant(sNumSockets - 1)   ' check the handle index to make sure we don't go out of bounds
    abort ERRBADHANDLE

  ' check handle to make sure it's the one we want (rid ourselves of bad user handles)
  ' the current check method is as follows:
  ' - compare sDstPort

  if wDstPort[handle] <> ((userHandle.byte[2] << 8) + userHandle.byte[1])
    abort ERRBADHANDLE

  ' if we got here without aborting then we can assume the handle is good
  LONG[ptrHandle] := handle

' ************************************
' ** Public Accessors (Thread Safe) **
' ************************************
PUB listen(port, _ptrrxbuff, _rxlen, _ptrtxbuff, _txlen) | handle
'' Sets up a socket for listening on a port
''   port = port number to listen on
''   ptrrxbuff = pointer to the rxbuffer array
''   rxlen = length of the rxbuffer array (must be power of 2)
''   ptrtxbuff = pointer to the txbuffer array
''   txlen = length of the txbuffer array (must be power of 2)
'' Returns handle if available, ERROUTOFSOCKETS if none available
'' Nonblocking

  repeat while lockset(lock_id)

  ' just find any avail closed socket
  handle := \find_socket(0, 0, 0)

  if handle < 0
    lockclr(lock_id)
    abort ERROUTOFSOCKETS

  rx_bufferptr[handle] := _ptrrxbuff
  tx_bufferptr[handle] := _ptrtxbuff
  rxbuffer_length[handle] := _rxlen
  txbuffer_length[handle] := _txlen
  rxbuffer_mask[handle] := _rxlen - 1
  txbuffer_mask[handle] := _txlen - 1

  lMySeqNum[handle] := 0
  lMyAckNum[handle] := 0
  lSrcIp[handle] := 0
  lTime[handle] := 0
  wLastTxLen[handle] := 0
  wNotAcked[handle] := 0
  bytefill(@bSrcMac[handle * 6], 0, 6)

  wSrcPort[handle] := 0                                 ' no source port yet
  wDstPort[handle] := conv_endianword(port)             ' we do have a dest port though

  wLastWin[handle] := rxbuffer_length[handle]

  tx_head[handle] := 0
  tx_tail[handle] := 0
  tx_tailnew[handle] := 0
  rx_head[handle] := 0
  rx_tail[handle] := 0

  ' it's now listening
  bConState[handle] := SLISTEN

  lockclr(lock_id)

  return ((port.byte[0] << 16) + (port.byte[1] << 8)) + handle 

PUB connect(ipaddr, remoteport, _ptrrxbuff, _rxlen, _ptrtxbuff, _txlen) | handle, user_handle
'' Connect to remote host
''   ipaddr     = ipv4 address packed into a long (ie: 1.2.3.4 => $01_02_03_04)
''   remoteport = port number to connect to
''   ptrrxbuff = pointer to the rxbuffer array
''   rxlen = length of the rxbuffer array (must be power of 2)
''   ptrtxbuff = pointer to the txbuffer array
''   txlen = length of the txbuffer array (must be power of 2)
'' Returns handle to new socket, ERROUTOFSOCKETS if no socket available
'' Nonblocking

  repeat while lockset(lock_id)

  ' just find any avail closed socket
  handle := \find_socket(0, 0, 0)

  if handle < 0
    lockclr(lock_id)
    abort ERROUTOFSOCKETS

  rx_bufferptr[handle] := _ptrrxbuff
  tx_bufferptr[handle] := _ptrtxbuff
  rxbuffer_length[handle] := _rxlen
  txbuffer_length[handle] := _txlen
  rxbuffer_mask[handle] := _rxlen - 1
  txbuffer_mask[handle] := _txlen - 1

  lMySeqNum[handle] := 0
  lMyAckNum[handle] := 0
  lTime[handle] := 0
  wLastTxLen[handle] := 0
  wNotAcked[handle] := 0
  bytefill(@bSrcMac[handle * 6], 0, 6)

  if(ip_ephport => EPHPORTEND)                          ' constrain ephport to specified range
    ip_ephport := EPHPORTSTART

  user_handle := ((ip_ephport.byte[0] << 16) + (ip_ephport.byte[1] << 8)) + handle
  
  ' copy in ip, port data (with respect to the remote host, since we use same code as server)
  lSrcIp[handle] := conv_endianlong(ipaddr)
  wSrcPort[handle] := conv_endianword(remoteport)
  wDstPort[handle] := conv_endianword(ip_ephport++)

  wLastWin[handle] := rxbuffer_length[handle]

  tx_head[handle] := 0
  tx_tail[handle] := 0
  tx_tailnew[handle] := 0
  rx_head[handle] := 0
  rx_tail[handle] := 0

  bConState[handle] := SCONNECTINGARP1

  lockclr(lock_id)
  
  return user_handle

PUB close(user_handle) | handle, state
'' Closes a connection

  _handleConvert(user_handle, @handle)

  repeat while lockset(lock_id)

  state := bConState[handle]

  if state == SESTABLISHED
    ' try to gracefully close the connection
    bConState[handle] := SCLOSING
  elseif state <> SCLOSING AND state <> SCLOSING2
    ' we only do an ungraceful close if we are not in ESTABLISHED, CLOSING, or CLOSING2
    bConState[handle] := SCLOSED

  lockclr(lock_id)

  ' wait for the socket to close, this is very important to prevent the client app from reusing the buffers
  repeat until (bConState[handle] == SCLOSING2) or (bConState[handle] == SCLOSED)

PUB isConnected(user_handle) | handle
'' Returns true if the socket is connected, false otherwise

  if \_handleConvert(user_handle, @handle) <> 0
    return false
  
  return (bConState[handle] == SESTABLISHED)  

PUB isValidHandle(user_handle) | handle
'' Checks to see if the handle is valid, handles will become invalid once they are used
'' In other words, a closed listening socket is now invalid, etc

  {if handle < 0 OR handle > constant(sNumSockets - 1)
    ' obviously the handle index is out of range, so it's not valid!
    return false}

  if \_handleConvert(user_handle, @handle) < 0
    return false

  return (bConState[handle] <> SCLOSED)

PUB readDataNonBlocking(user_handle, ptr, maxlen) | handle, len, rxptr
'' Reads bytes from the socket
'' Returns number of read bytes
'' Not blocking (returns RETBUFFEREMPTY if no data)

  _handleConvert(user_handle, @handle)

  if rx_tail[handle] == rx_head[handle]
    return RETBUFFEREMPTY

  len := (rx_head[handle] - rx_tail[handle]) & rxbuffer_mask[handle]
  if maxlen < len
    len := maxlen

  rxptr := rx_bufferptr[handle]
  
  if (len + rx_tail[handle]) > rxbuffer_length[handle]
    bytemove(ptr, rxptr + rx_tail[handle], rxbuffer_length[handle] - rx_tail[handle])
    bytemove(ptr + (rxbuffer_length[handle] - rx_tail[handle]), rxptr, len - (rxbuffer_length[handle] - rx_tail[handle]))
  else
    bytemove(ptr, rxptr + rx_tail[handle], len)

  rx_tail[handle] := (rx_tail[handle] + len) & rxbuffer_mask[handle]

  return len  

PUB readData(user_handle, ptr, maxlen) : len | handle
'' Reads bytes from the socket
'' Returns the number of read bytes
'' Will block until data is received

  _handleConvert(user_handle, @handle)

  repeat while (len := readDataNonBlocking(user_handle, ptr, maxlen)) < 0
    ifnot isConnected(user_handle)
      abort ERRSOCKETCLOSED

PUB readByteNonBlocking(user_handle) : rxbyte | handle, ptr
'' Read a byte from the specified socket
'' Will not block (returns RETBUFFEREMPTY if no byte avail)

  _handleConvert(user_handle, @handle)

  rxbyte := RETBUFFEREMPTY
  if rx_tail[handle] <> rx_head[handle]
    ptr := rx_bufferptr[handle]
    rxbyte := BYTE[ptr][rx_tail[handle]]
    rx_tail[handle] := (rx_tail[handle] + 1) & rxbuffer_mask[handle]
    
PUB readByte(user_handle) : rxbyte | handle, ptr
'' Read a byte from the specified socket
'' Will block until a byte is received

  _handleConvert(user_handle, @handle)

  repeat while (rxbyte := readByteNonBlocking(user_handle)) < 0
    ifnot isConnected(user_handle)
      abort ERRSOCKETCLOSED

PUB writeDataNonBlocking(user_handle, ptr, len) | handle, txptr
'' Writes bytes to the socket
'' Will not write anything unless your data fits in the buffer
'' Non blocking (returns RETBUFFERFULL if can't fit data)

  _handleConvert(user_handle, @handle)

  if (txbuffer_mask[handle] - ((tx_head[handle] - tx_tail[handle]) & txbuffer_mask[handle])) < len
    return RETBUFFERFULL

  txptr := tx_bufferptr[handle]
  
  if (len + tx_head[handle]) > txbuffer_length[handle]
    bytemove(txptr + tx_head[handle], ptr, txbuffer_length[handle] - tx_head[handle])
    bytemove(txptr, ptr + (txbuffer_length[handle] - tx_head[handle]), len - (txbuffer_length[handle] - tx_head[handle]))
  else
    bytemove(txptr + tx_head[handle], ptr, len)

  tx_head[handle] := (tx_head[handle] + len) & txbuffer_mask[handle]

  return len

PUB writeData(user_handle, ptr, len) | handle
'' Writes data to the specified socket
'' Will block until all data is queued to be sent

  _handleConvert(user_handle, @handle)

  repeat while len > txbuffer_mask[handle]
    repeat while writeDataNonBlocking(user_handle, ptr, txbuffer_mask[handle]) < 0
      ifnot isConnected(user_handle)
        abort ERRSOCKETCLOSED
    len -= txbuffer_mask[handle]
    ptr += txbuffer_mask[handle]

  repeat while writeDataNonBlocking(user_handle, ptr, len) < 0
    ifnot isConnected(user_handle)
      abort ERRSOCKETCLOSED

PUB writeByteNonBlocking(user_handle, txbyte) | handle, ptr
'' Writes a byte to the specified socket
'' Will not block (returns RETBUFFERFULL if no buffer space available)

  _handleConvert(user_handle, @handle)

  ifnot (tx_tail[handle] <> (tx_head[handle] + 1) & txbuffer_mask[handle])
    return RETBUFFERFULL

  ptr := tx_bufferptr[handle]  
  BYTE[ptr][tx_head[handle]] := txbyte
  tx_head[handle] := (tx_head[handle] + 1) & txbuffer_mask[handle]

  return txbyte

PUB writeByte(user_handle, txbyte) | handle
'' Write a byte to the specified socket
'' Will block until space is available for byte to be sent 

  _handleConvert(user_handle, @handle)

  repeat while writeByteNonBlocking(user_handle, txbyte) < 0
    ifnot isConnected(user_handle)
      abort ERRSOCKETCLOSED

PUB resetBuffers(user_handle) | handle
'' Resets send/receive buffers for the specified socket

  _handleConvert(user_handle, @handle)

  rx_tail[handle] := rx_head[handle]
  tx_head[handle] := tx_tail[handle]

PUB flush(user_handle) | handle
'' Flushes the send buffer (waits till the buffer is empty)
'' Will block until all tx data is sent

  _handleConvert(user_handle, @handle)

  repeat while isConnected(user_handle) AND tx_tail[handle] <> tx_head[handle]

PUB getSocketState(user_handle) | handle
'' Gets the socket state (internal state numbers)
'' You can include driver_socket in any object and use the S... state constants for comparison

  _handleConvert(user_handle, @handle)
  
  return bConState[handle]

PUB getReceiveBufferCount(user_handle) | handle
'' Returns the number of bytes in the receive buffer

  _handleConvert(user_handle, @handle)

  return (rx_head[handle] - rx_tail[handle]) & rxbuffer_mask[handle] 

CON
  '******************************************************************
  '*      TCP Flags
  '******************************************************************
  TCP_FIN = 1
  TCP_SYN = 2
  TCP_RST = 4
  TCP_PSH = 8
  TCP_ACK = 16
  TCP_URG = 32
  TCP_ECE = 64
  TCP_CWR = 128
  '******************************************************************
  '*      Ethernet Header Layout
  '******************************************************************                
  enetpacketDest0 = $00  'destination mac address
  enetpacketDest1 = $01
  enetpacketDest2 = $02
  enetpacketDest3 = $03
  enetpacketDest4 = $04
  enetpacketDest5 = $05
  enetpacketSrc0 = $06  'source mac address
  enetpacketSrc1 = $07
  enetpacketSrc2 = $08
  enetpacketSrc3 = $09
  enetpacketSrc4 = $0A
  enetpacketSrc5 = $0B
  enetpacketType0 = $0C  'type/length field
  enetpacketType1 = $0D
  enetpacketData = $0E  'IP data area begins here
  '******************************************************************
  '*      ARP Layout
  '******************************************************************
  arp_hwtype = $0E
  arp_prtype = $10
  arp_hwlen = $12
  arp_prlen = $13
  arp_op = $14
  arp_shaddr = $16   'arp source mac address
  arp_sipaddr = $1C   'arp source ip address
  arp_thaddr = $20   'arp target mac address
  arp_tipaddr = $26   'arp target ip address
  '******************************************************************
  '*      IP Header Layout
  '******************************************************************
  ip_vers_len = $0E       'IP version and header length 1a19
  ip_tos = $0F    'IP type of service
  ip_pktlen = $10 'packet length
  ip_id = $12     'datagram id
  ip_frag_offset = $14    'fragment offset
  ip_ttl = $16    'time to live
  ip_proto = $17  'protocol (ICMP=1, TCP=6, UDP=11)
  ip_hdr_cksum = $18      'header checksum 1a23
  ip_srcaddr = $1A        'IP address of source
  ip_destaddr = $1E       'IP addess of destination
  ip_data = $22   'IP data area
  '******************************************************************
  '*      TCP Header Layout
  '******************************************************************
  TCP_srcport = $22       'TCP source port
  TCP_destport = $24      'TCP destination port
  TCP_seqnum = $26        'sequence number
  TCP_acknum = $2A        'acknowledgement number
  TCP_hdrlen = $2E        '4-bit header len (upper 4 bits)
  TCP_hdrflags = $2F      'TCP flags
  TCP_window = $30        'window size
  TCP_cksum = $32 'TCP checksum
  TCP_urgentptr = $34     'urgent pointer
  TCP_data = $36 'option/data
  '******************************************************************
  '*      IP Protocol Types
  '******************************************************************
  PROT_ICMP = $01
  PROT_TCP = $06
  PROT_UDP = $11
  '******************************************************************
  '*      ICMP Header
  '******************************************************************
  ICMP_type = ip_data
  ICMP_code = ICMP_type+1
  ICMP_cksum = ICMP_code+1
  ICMP_id = ICMP_cksum+2
  ICMP_seqnum = ICMP_id+2
  ICMP_data = ICMP_seqnum+2
  '******************************************************************
  '*      UDP Header
  '******************************************************************
  UDP_srcport = ip_data
  UDP_destport = UDP_srcport+2
  UDP_len = UDP_destport+2
  UDP_cksum = UDP_len+2
  UDP_data = UDP_cksum+2
  '******************************************************************
  '*      DHCP Message
  '******************************************************************
  DHCP_op = UDP_data
  DHCP_htype = DHCP_op+1
  DHCP_hlen = DHCP_htype+1
  DHCP_hops = DHCP_hlen+1
  DHCP_xid = DHCP_hops+1
  DHCP_secs = DHCP_xid+4
  DHCP_flags = DHCP_secs+2
  DHCP_ciaddr = DHCP_flags+2
  DHCP_yiaddr = DHCP_ciaddr+4
  DHCP_siaddr = DHCP_yiaddr+4
  DHCP_giaddr = DHCP_siaddr+4
  DHCP_chaddr = DHCP_giaddr+4
  DHCP_sname = DHCP_chaddr+16
  DHCP_file = DHCP_sname+64
  DHCP_options = DHCP_file+128
  DHCP_message_end = DHCP_options+312
