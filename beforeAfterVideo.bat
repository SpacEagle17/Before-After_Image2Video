@echo off
setlocal enabledelayedexpansion

REM Set the path to the current directory
set "INPATH=%~dp0"
if "%INPATH:~-1%" == "\" set "INPATH=%INPATH:~0,-1%"

REM Check if first parameter is a file (drag and drop) or a duration value
set "DURATION=0.5"
if not "%~1"=="" (
    REM Check if parameter has a file extension (likely a file path)
    if /i not "%~x1"=="" (
        REM It's a file path, use as BEFORE_IMG
        set "BEFORE_IMG=%~1"
        echo Using dropped file as before image: !BEFORE_IMG!
    ) else (
        REM It's a duration value
        set "DURATION=%~1"
        set "DURATION_FROM_ARG1=1"
    )
)

REM Check if before.png exists, if not prompt user
if not defined BEFORE_IMG set "BEFORE_IMG=%INPATH%\before.png"
if not exist "%BEFORE_IMG%" (
    echo Before image not found: %BEFORE_IMG%
    echo Please drag and drop the "before" image onto this window, or type its path:
    set /p BEFORE_IMG=
    if not exist "!BEFORE_IMG!" (
        echo Error: Invalid file path or file not found.
        pause
        exit /b 1
    )
)

REM Check if after.png exists, if not prompt user
set "AFTER_IMG=%INPATH%\after.png"
if not exist "%AFTER_IMG%" (
    echo After image not found: %AFTER_IMG%
    echo Please drag and drop the "after" image onto this window, or type its path:
    set /p AFTER_IMG=
    if not exist "!AFTER_IMG!" (
        echo Error: Invalid file path or file not found.
        pause
        exit /b 1
    )
)

REM Set default font size and allow override via second parameter
set "FONTSIZE=72"
if not "%~2"=="" (
    REM Check if second parameter has file extension (for future two-file drag and drop)
    if /i "%~x2"=="" (
        set "FONTSIZE=%~2"
        echo Using manually specified font size: !FONTSIZE!
    )
) else (
    REM Get image dimensions using ffprobe with simpler output format
    echo Detecting image dimensions...
    for /f "tokens=*" %%a in ('ffprobe -v error -select_streams v:0 -show_entries stream^=height -of csv^=p^=0 "%BEFORE_IMG%"') do (
        set "HEIGHT=%%a"
        echo Detected height: !HEIGHT!

        REM Calculate font size as percentage of image height
        set /a "FONTSIZE=!HEIGHT! * 15 / 100"
        echo Calculated font size: !FONTSIZE!
    )

    echo Using font size: !FONTSIZE! for detected image resolution
)

REM Set default loop iterations and allow override via third parameter
set "LOOPS=1"
if not "%~3"=="" (
    set "LOOPS=%~3"
) else (
    set /p "LOOPS=Enter number of loop iterations (press Enter for 1): "
    if "!LOOPS!"=="" set "LOOPS=1"
)

REM Set flicker delay (duration per image) and allow override via fourth parameter
if not "%~4"=="" (
    set "DURATION=%~4"
) else if not defined DURATION_FROM_ARG1 (
    set /p "DURATION=Enter flicker duration in seconds (press Enter for 0.5): "
    if "!DURATION!"=="" set "DURATION=0.5"
)

set "FFMPEG=ffmpeg"
set "COUNT=1"

REM Find next available filename
:findnext
set "OUTFILE=%INPATH%\%COUNT%.mp4"
if exist "%OUTFILE%" (
    set /a COUNT+=1
    goto findnext
)

REM Build inputs and filter graph so before/after repeats LOOPS times
set "INPUTS="
set "FILTERS="
set "CONCATLIST="
set /a IDX=0
for /l %%i in (1,1,%LOOPS%) do (
    set /a BIDX=IDX
    set /a AIDX=IDX+1
    set "INPUTS=!INPUTS! -loop 1 -t !DURATION! -i "!BEFORE_IMG!" -loop 1 -t !DURATION! -i "!AFTER_IMG!""
    set "FILTERS=!FILTERS![!BIDX!:v]scale=iw:trunc(ih/2)*2,drawtext=text='Before':font='Arial':fontcolor=white:fontsize=!FONTSIZE!:x=w-tw-20:y=h-th-20[v!BIDX!];"
    set "FILTERS=!FILTERS![!AIDX!:v]scale=iw:trunc(ih/2)*2,drawtext=text='After':font='Arial':fontcolor=white:fontsize=!FONTSIZE!:x=w-tw-20:y=h-th-20[v!AIDX!];"
    set "CONCATLIST=!CONCATLIST![v!BIDX!][v!AIDX!]"
    set /a IDX+=2
)
set /a TOTAL=LOOPS*2

%FFMPEG% !INPUTS! ^
  -filter_complex "!FILTERS!!CONCATLIST!concat=n=!TOTAL!:v=1:a=0" ^
  -c:v libx264 -pix_fmt yuv420p -movflags +faststart "%OUTFILE%"

if %ERRORLEVEL% neq 0 (
    echo.
    echo Error occurred during FFmpeg processing!
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo Saved as: %OUTFILE% (Duration per image: %DURATION%s, Font size: !FONTSIZE!, Loops: !LOOPS!)
exit /b 0
