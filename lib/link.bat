@echo off
setlocal
set CC=gcc.exe
set kscope_lib=%~dp0

if "%3"=="" echo usage: %~nx0 ^<platform^> ^<file.o^> ^<output.exe^> & goto :eof

if "%1"=="win32" set CC=i686-w64-mingw32-gcc.exe
if "%1"=="win64" set CC=x86_64-w64-mingw32-gcc.exe

%CC% "%~2" %kscope_lib%/%1/*.o -o "%~3" -static -static-libgcc -static-libstdc++ %kscope_lib%/%1/*.a -Wl,--export-all-symbols
