{{
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// E555 Light Emitting Diode Engine
//
// Author: Kwabena W. Agyeman
// Updated: 7/27/2010
// Designed For: P8X32A
// Version: 1.1
//
// Copyright (c) 2010 Kwabena W. Agyeman
// See end of file for terms of use.
//
// Update History:
//
// v1.0 - Original release - 1/26/2010.
// v1.1 - Added support for variable pin assignments - 7/27/2010.
//
// For each included copy of this object only one spin interpreter should access it at a time.
//
// Nyamekye,
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// LED Circuit:
//
// LEDPinNumber --- LED Driver (Active High).
//
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
}}

PUB LEDFrequency(newFrequency, LEDPinNumber) '' 11 Stack Longs

'' ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'' // Changes the light emitting diode frequency using the SPIN interpreter's counters. Brightness will be set to zero.
'' //
'' // NewFrequency - The new frequency. Between 0 Hz and 80MHz @ 80MHz. -1 to reset the pin and counter modules.
'' // LEDPinNumber - Pin to use to drive the LED circuit. Between 0 and 31.
'' ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  LEDSetup((newFrequency <> -1), LEDPinNumber, true)

  newFrequency := ((newFrequency <# clkfreq) #> 0)

  result := 1
  repeat 32

    newFrequency <<= 1
    result <-= 1
    if(newFrequency => clkfreq)
      newFrequency -= clkfreq
      result += 1

  frqa := result~

PUB LEDBrightness(newBrightness, LEDPinNumber) '' 11 Stack Longs

'' ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
'' // Changes the light emitting diode brightness using the SPIN interpreter's counters. Frequency will be set to zero.
'' //
'' // NewBrightness - The new brightness. Between 0% and 100%. -1 to reset the pin and counter modules.
'' // LEDPinNumber - Pin to use to drive the LED circuit. Between 0 and 31.
'' ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  LEDSetup((newBrightness <> -1), LEDPinNumber, false)

  frqb := (((newBrightness <# 100) #> 0) * constant(posx / 50))

PRI LEDSetup(activeOrInactive, LEDPinNumber, frequencyOrBrightness) ' 6 Stack Longs

  LEDPinNumber := ((LEDPinNumber <# 31) #> 0)

  dira[LEDPinNumber] := activeOrInactive
  outa[LEDPinNumber] := false

  ctra := (((constant(%0_0100 << 26) + LEDPinNumber) & activeOrInactive) & frequencyOrBrightness)
  ctrb := (((constant(%0_0110 << 26) + LEDPinNumber) & activeOrInactive) & (not(frequencyOrBrightness)))

  spr[2 - frequencyOrBrightness] := 0
  spr[10 - frequencyOrBrightness] := 0
  spr[12 - frequencyOrBrightness] := 0

{{

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                  TERMS OF USE: MIT License
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
// Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
}}