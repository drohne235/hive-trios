echo on
date /T
time /T

REM Pfade
set sd=".\bin\sdcard"
set sd-sys=".\bin\sdcard\system"
set flash=".\bin\flash"
set libpath=".\lib"
set BSTC=bstc.exe

REM ----------------------------------------------------------------
REM Alte Versionen löschen

del %flash%\*.* /Q
del %sd%\*.* /Q
del %sd-sys%\*.* /Q

REM ----------------------------------------------------------------
REM Flashdateien erzeugen
REM --> \bin\flash

%BSTC% -L %libpath% -b -O a .\flash\administra\admflash.spin
copy admflash.binary %flash%
rename admflash.binary admsys.adm
move admsys.adm %sd-sys%

%BSTC% -L %libpath% -D __VGA -b -O a .\flash\bellatrix\belflash.spin
copy belflash.binary %flash%
rename belflash.binary vga.bel
move vga.bel %sd-sys%

%BSTC% -L %libpath% -D __TV -b -O a .\flash\bellatrix\belflash.spin
rename belflash.binary tv.bel
move tv.bel %sd-sys%

%BSTC% -L %libpath% -b -O a .\flash\regnatix\regflash.spin
move regflash.binary %flash%

REM ----------------------------------------------------------------
REM Startdateie erzeugen
REM reg.sys	(Regime)
REM --> \bin\sdcard\

%BSTC% -L %libpath% -b -O a .\system\regnatix\regime.spin 
rename regime.binary reg.sys
move reg.sys %sd%


REM ----------------------------------------------------------------
REM Slave-Dateien erzeugen
REM admsid, admay, admterm
REM htxt, g0key

%BSTC% -L %libpath% -b -O a .\system\administra\admsid\admsid.spin
%BSTC% -L %libpath% -b -O a .\system\administra\admay\admay.spin
%BSTC% -L %libpath% -b -O a .\system\administra\admnet\admnet.spin
rename *.binary *.adm

%BSTC% -L %libpath% -b -O a .\system\bellatrix\bel-htext\htext.spin
%BSTC% -L %libpath% -b -O a .\system\bellatrix\bel-g0\g0key.spin
rename *.binary *.bel

move *.adm %sd-sys%
move *.bel %sd-sys%


REM ----------------------------------------------------------------
REM Systemdateien erzeugen
REM - div. externe Kommandos
REM - div. Systemdateien (Farbtabellen usw.)
REM --> \bin\sdcard\system\

for %%x in (.\system\regnatix\*.spin) do %BSTC% -L %libpath% -b -O a %%x 
rename *.binary *.bin
move *.bin %sd-sys% 
copy .\forth\*.* %sd-sys%
copy .\system\sonstiges %sd-sys%

echo off
