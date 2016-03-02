## Kaleidoscope Toy Language to Lua Transpiler

`kscope` is a LuaJIT implementation of [LLVM's Kaleidoscope toy language](http://llvm.org/docs/tutorial/LangImpl1.html) providing both an interpreter and a compiler which can build statically linked (portable) executables.

Currently the implementation is Windows based/tested only and heavily relies on [MinGW-w64 project](http://mingw-w64.org/) for bootstrapping the compiler and linking compiler output executables.

## Building the compiler

There is a `build.bat` batch file in `bin` folder that automates compilation of both `kscope-win32.exe` and `kscope-win64.exe` compiler executables. These are both cross-compilers for _Kaleidoscope toy language_, meaning that `kscope-win32.exe` can compile both 32-bit and 64-bit executables (defaulting to 32-bit) and vice-versa for `kscope-win64.exe` compiler.

Currently `build.bat` expects [`i686-w64-mingw32`](https://sourceforge.net/projects/mingw-w64/files/Toolchains%20targetting%20Win32/Personal%20Builds/mingw-builds/5.3.0/threads-posix/dwarf/) in `C:\mingw32` and [`x86_64-w64-mingw32`](https://sourceforge.net/projects/mingw-w64/files/Toolchains%20targetting%20Win64/Personal%20Builds/mingw-builds/5.3.0/threads-posix/seh/) in `C:\mingw64` (links to version 5.3). Include both folders in global `PATH` like this `set PATH=C:\mingw64;C:\mingw32;%PATH%` to prefer 64-bit toolchain and still be able to access 32-bit tools for cross compilation using compiler triplets (with something like `i686-w64-mingw32-gcc.exe`).

`kscope` depends on MinGW toolchain to bootstrap the compiler and the compiled executables. More specifically the C bootstrap (`startup.c`) includes a `main` entry-point function which initializes the Lua environment and additionally LuaJIT and LPeg are statically precompiled with MinGW to be compatible with `kscope`'s linking phase.

## Building support files (optional)

There is a `build.bat` batch file in `lib` folder that prepares compiler bootstrap and libraries. These come precompiled so using this batch file is optional.

Each platform has subfolder under `lib`, that is 32-bit object/lib files go to `lib\win32` while 64-bit precompiled files go to `lib\win64`. The compiler expects to find this `lib` folder under the folder of the executable (e.g. `bin`) or in its parent folder.

## Implementation

##### Using Visual Studio
The Lua project in `src` is using [babelua](https://babelua.codeplex.com/) plugin for VS2015 for coding and debugging. This plugin project obviously hoisted [decoda](http://unknownworlds.com/decoda/)'s hooking debugger and the resulting execution under debug is dog-slow but then the plugin brings some of the familiar VS goodness -- breakpoints, inspections, **editing** experience.

##### Frontend
`parser.lua` implements the language parser using a somewhat extended version of [LPeg.re](http://www.inf.puc-rio.br/~roberto/lpeg/re.html) that understands meta-patterns (functions that return patterns based on params) with `%def'param'` syntax. The parser builds the AST with instances from `tree.lua` which are a bunch of glorified tables. Properties of AST nodes are accessed by name, not by index as in metalua AST, i.e. `IfExpr` instance has `test`, `cons` and `altn` members, not `node[1]`, `node[2]` and `node[3]`. Base "class" `Node` implements the double-dispatch for [Visitor pattern](https://en.wikipedia.org/wiki/Visitor_pattern) in a strictly dynamic language way, so there is no need for `accept` method on each and every subclass.

`visitor.lua` implements a "virtual" `Visitor` class and a single `Dumper` implementation that prints the AST. Again the output is similar to metalua's AST but with "strongly" named members.

##### Backend
`emitter.lua` implements a visitor that does the actual codegen. Kaleidoscope language is pretty functional so the resulting code contains somewhat similar abominations as CoffeeScript lowering to JS, e.g. `return (function(a) return x+a end)(42)`. Nevertheless we are not pursuing performance in MVP release and the LuaJIT does miracles optimizing this bloat.

##### Linking
The compiler expects `link.bat` in `lib` folder for final linking. The batch file shells `gcc` and bundles the bootstrap module and LuaJIT runtime in the output portable executable.

##### Inspiration and 10x goes to
 - [@richardhundt](https://github.com/richardhundt) for [Shine](https://github.com/richardhundt/shine) implementation
 - [@carp](https://github.com/capr) of luapower for [bundle](https://github.com/luapower/bundle) scripts

## Known issues

- LuaJIT built-in object file emitter seems to be incompatible with MinGW linker which spits `corrupt .drectve at end of def file` warnings when parsing these. You can safely ignore the warnings.
