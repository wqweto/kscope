@echo off
setlocal
set LJ_EXE=C:\Work\Temp\Lua\luajit.exe
set LUA_CPATH=C:\Work\Temp\Lua\?.dll
set CC=gcc.exe
set kscope_dst=%~dp0.
set kscope_src=%~dp0..\src
set kscope_lib=%~dp0..\lib

md %kscope_dst%\obj > nul 2>&1
call :compile_arch win32 x86 c:\mingw32\bin
call :compile_arch win64 x64 c:\mingw64\bin
echo Done.
goto :eof

:compile_arch
set PATH=%~3;%PATH%

rd /q /s %kscope_dst%\obj\%1 > nul 2>&1
md %kscope_dst%\obj\%1

echo %1: Compiling Lua sources...
for %%i in (%kscope_src%\kscope\*.lua) do call :luac %1 %2 %%i kscope.%%~ni
for %%i in (%kscope_src%\jit\*.lua) do call :luac %1 %2 %%i jit.%%~ni
call :luac %1 %2 %kscope_src%\main.lua main

echo %1: Linking kscope-%1.exe...
del /q kscope-%1.exe 2> nul
%CC% %kscope_dst%/obj/%1/*.o %kscope_lib%/%1/startup.o -o %kscope_dst%/kscope-%1.exe -static -static-libgcc -static-libstdc++ %kscope_lib%/%1/*.a -Wl,--export-all-symbols
goto :eof

:luac
pushd %kscope_src%
set dest=obj\%1\%~n3.o
echo %1: Compiling %dest%...
%LJ_EXE% %kscope_src%\main.lua -a %2 -n %4 %3 -ocore %kscope_dst%\%dest%
if not exist %kscope_dst%\%dest% echo %dest% compile failed
popd
goto :eof
