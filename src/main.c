#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include "lua_wind.h"


void openlibs(lua_State *L) {
	luaL_openlibs(L);
	luaL_requiref(L, "wind.main", lua_lib_wind_main, 0);
	luaL_openlibs(L);
	luaL_requiref(L, "wind.core", lua_lib_wind_core, 0);
	lua_pop(L, 1);
}


int main(int argc, char const *argv[])
{
	if (argc < 2) {
		fprintf(stderr, "usage wind main.lua\n");
		return -1;
	}

	lua_State *L= luaL_newstate();

	openlibs(L);

	int err = luaL_loadfile(L, argv[1]) || lua_pcall(L, 0, 0, 0);
	if (err) {
		fprintf(stderr, "%s\n", lua_tostring(L, -1));
		lua_pop(L, 1);
	}

	lua_close(L);
    return 0;
}
