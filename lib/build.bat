@echo off
setlocal
set LJ_PATH=C:\Work\Temp\Lua\LuaJIT-2.1.0-beta1\src
set LPEG_PATH=C:\Work\Temp\Lua\lpeg-1.0.0
set LJ_EXE=C:\Work\Temp\Lua\luajit.exe
set LUA_CPATH=.\?.dll;C:\Work\Temp\Lua\?.dll
set CC=gcc.exe
set AR=ar.exe
set MAKE=mingw32-make.exe
set kscope_lib=%~dp0
set kscope_src=..\src

call :compile_arch win32 x86 c:\mingw32\bin
call :compile_arch win64 x64 c:\mingw64\bin
echo Done.
goto :eof

:compile_arch
set PATH=%~3;%PATH%

rd %1 /q /s > nul 2>&1
md %1

echo %1: Compiling kscope core...
pushd %kscope_src%
%LJ_EXE% main.lua -n kscope.core kscope/core.lua -a %2 -ocore %kscope_lib%/%1/core.o
if not exist %kscope_lib%/%1/core.o echo %1/core.o compile failed
popd

echo %1: Compiling kscope startup...
pushd %kscope_src%\startup
%CC% -c -O2 -xc startup.c -o %kscope_lib%/%1/startup.o -I%LJ_PATH% -ansi
if not exist %kscope_lib%/%1/startup.o echo %1/startup.o compile failed
popd

echo %1: Compiling LPeg...
pushd %LPEG_PATH%
del /s *.o > nul 2>&1
%CC% -c -O2 -xc *.c -I. -I%LJ_PATH% -ansi
%AR% rcs lpeg.a *.o
popd
copy %LPEG_PATH%\lpeg.a %1\lpeg.a > nul
if not exist %1\lpeg.a echo %1/lpeg.a compile failed

echo %1: Compiling LuaJIT (takes some time)...
pushd %LJ_PATH%
%MAKE% clean > nul 2>&1
%MAKE% BUILDMODE=static > nul
popd
copy %LJ_PATH%\libluajit.a %1\luajit.a > nul
if not exist %1\luajit.a echo %1/luajit.a compile failed

goto :eof
