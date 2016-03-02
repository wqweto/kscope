#include <stdio.h>

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

extern int luaopen_lpeg (lua_State *L);

int main(int argc, char **argv)
{
    int status, i;
    lua_State *L = luaL_newstate();
    luaL_openlibs(L);

    lua_pushcfunction(L, luaopen_lpeg);
    lua_pushstring(L, "lpeg");
    lua_call(L, 1, 0);

    /* create and fill up _G.arg */
    lua_createtable(L, argc, 2);
    /* add argv */
    for (i = 0; i < argc; i++) {
        lua_pushstring(L, argv[i]);
        lua_rawseti(L, -2, i);
    }
    lua_setglobal(L, "arg");
    /* add varargs */
    luaL_checkstack(L, argc - 1, "too many arguments");
    for (i = 1; i < argc; i++) {
        lua_pushstring(L, argv[i]);
    }
  
    lua_getglobal(L, "require");
    lua_pushliteral(L, "main");
    status = lua_pcall(L, 1, 0, 0);
    if (status) {
        fprintf(stderr, "Error: %s\n", lua_tostring(L, -1));
        return 1;
    }
    return 0;
}
