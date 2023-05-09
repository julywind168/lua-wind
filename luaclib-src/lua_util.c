#include "lua_util.h"


int
lua_lib_util(lua_State *L) {
	static const struct luaL_Reg l[] = {
		{NULL, NULL}
	};

    luaL_newlib(L, l);
    return 1;
}