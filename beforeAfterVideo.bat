@echo off
setlocal enabledelayedexpansion

REM Set the path to the current directory
set "INPATH=%~dp0"
if "%INPATH:~-1%" == "\" set "INPATH=%INPATH:~0,-1%"

set "FIRSTRUN=1"

:start
set "BEFORE_IMG="
set "AFTER_IMG="
set "DURATION=0.75"
set "FONTSIZE=72"
set "LOOPS=3"
set "LABEL1=Before"
set "LABEL2=After"

if "!FIRSTRUN!"=="0" (
    echo.
    echo ================================================================
    echo Ready for the next one.
)

REM Check if before.png exists on the first run, otherwise always prompt
if "!FIRSTRUN!"=="1" set "BEFORE_IMG=%INPATH%\before.png"
if not defined BEFORE_IMG goto askbefore
if exist "!BEFORE_IMG!" goto gotbefore

echo Before image not found: !BEFORE_IMG!
:askbefore
echo Please drag and drop the "before" image onto this window, or type its path (leave empty to exit):
set "BEFORE_IMG="
set /p BEFORE_IMG=
set "BEFORE_IMG=!BEFORE_IMG:"=!"
if "!BEFORE_IMG!"=="" exit /b 0
if not exist "!BEFORE_IMG!" (
    echo Error: Invalid file path or file not found.
    goto askbefore
)
:gotbefore

REM Check if after.png exists on the first run, otherwise always prompt
if "!FIRSTRUN!"=="1" set "AFTER_IMG=%INPATH%\after.png"
if not defined AFTER_IMG goto askafter
if exist "!AFTER_IMG!" goto gotafter

echo After image not found: !AFTER_IMG!
:askafter
echo Please drag and drop the "after" image onto this window, or type its path (leave empty to exit):
set "AFTER_IMG="
set /p AFTER_IMG=
set "AFTER_IMG=!AFTER_IMG:"=!"
if "!AFTER_IMG!"=="" exit /b 0
if not exist "!AFTER_IMG!" (
    echo Error: Invalid file path or file not found.
    goto askafter
)
:gotafter

REM Get image dimensions using ffprobe with simpler output format
echo Detecting image dimensions...
for /f "tokens=*" %%a in ('ffprobe -v error -select_streams v:0 -show_entries stream^=height -of csv^=p^=0 "!BEFORE_IMG!"') do (
    set "HEIGHT=%%a"
    echo Detected height: !HEIGHT!

    REM Calculate font size as percentage of image height
    set /a "FONTSIZE=!HEIGHT! * 15 / 100"
    echo Calculated font size: !FONTSIZE!
)
echo Using font size: !FONTSIZE! for detected image resolution

set /p "LOOPS=Enter number of loop iterations (press Enter for 3): "
if "!LOOPS!"=="" set "LOOPS=3"

set /p "DURATION=Enter flicker duration in seconds (press Enter for 0.75): "
if "!DURATION!"=="" set "DURATION=0.75"

set /p "LABEL1=Enter text for the first image (press Enter for Before): "
if "!LABEL1!"=="" set "LABEL1=Before"
set /p "LABEL2=Enter text for the second image (press Enter for After): "
if "!LABEL2!"=="" set "LABEL2=After"

REM Quotes would break the ffmpeg filter string
set "LABEL1=!LABEL1:"=!"
set "LABEL1=!LABEL1:'=!"
set "LABEL2=!LABEL2:"=!"
set "LABEL2=!LABEL2:'=!"

set "FFMPEG=ffmpeg"
set "COUNT=1"

REM Find next available filename
:findnext
set "OUTFILE=%INPATH%\!COUNT!.mp4"
if exist "!OUTFILE!" (
    set /a COUNT+=1
    goto findnext
)

REM Build inputs and filter graph so before/after repeats LOOPS times
set "INPUTS="
set "FILTERS="
set "CONCATLIST="
set /a IDX=0
for /l %%i in (1,1,!LOOPS!) do (
    set /a BIDX=IDX
    set /a AIDX=IDX+1
    set "INPUTS=!INPUTS! -loop 1 -t !DURATION! -i "!BEFORE_IMG!" -loop 1 -t !DURATION! -i "!AFTER_IMG!""
    set "FILTERS=!FILTERS![!BIDX!:v]scale=iw:trunc(ih/2)*2,drawtext=text='!LABEL1!':font='Arial':fontcolor=white:fontsize=!FONTSIZE!:x=w-tw-20:y=h-th-20[v!BIDX!];"
    set "FILTERS=!FILTERS![!AIDX!:v]scale=iw:trunc(ih/2)*2,drawtext=text='!LABEL2!':font='Arial':fontcolor=white:fontsize=!FONTSIZE!:x=w-tw-20:y=h-th-20[v!AIDX!];"
    set "CONCATLIST=!CONCATLIST![v!BIDX!][v!AIDX!]"
    set /a IDX+=2
)
set /a TOTAL=LOOPS*2

%FFMPEG% !INPUTS! ^
  -filter_complex "!FILTERS!!CONCATLIST!concat=n=!TOTAL!:v=1:a=0" ^
  -c:v libx264 -pix_fmt yuv420p -movflags +faststart "!OUTFILE!"

if errorlevel 1 (
    echo.
    echo Error occurred during FFmpeg processing!
) else (
    echo.
    echo Saved as: !OUTFILE! ^(Duration per image: !DURATION!s, Font size: !FONTSIZE!, Loops: !LOOPS!^)
)

REM Go back to the initial state for the next run
set "FIRSTRUN=0"
goto start
