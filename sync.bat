@echo off
REM Copies addon source from repo into WoW 2.4.3 AddOns folder.
REM Run after editing RussianTranslator\*.lua; then /reload in game.

set SRC=%~dp0RussianTranslator
set DST=C:\Gry\World of WarcraftOLD\Interface\AddOns\RussianTranslator

if not exist "%DST%" mkdir "%DST%"

robocopy "%SRC%" "%DST%" /MIR /NFL /NDL /NJH /NJS /NP
echo.
echo Synced %SRC%  -->  %DST%
