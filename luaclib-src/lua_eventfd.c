#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <stdio.h>
#include <errno.h>
#include <unistd.h>
#include <string.h>
#include <sys/eventfd.h>

#include "lua_eventfd.h"


static int
l_eventfd_create(lua_State *L) {
	int fd = eventfd(0, 0);
	if (fd == -1) {
		lua_pushnil(L);
		lua_pushstring(L, strerror(errno));
		return 2;
	}
	lua_pushinteger(L, fd);
	return 1;
}

static int
l_eventfd_read(lua_State *L) {
    int fd = luaL_checkinteger(L, 1);
    uint64_t val;
    read(fd, &val, sizeof(val));
	return 0;
}

static int
l_eventfd_write(lua_State *L) {
    int fd = luaL_checkinteger(L, 1);
    uint64_t increment = 1;
    write(fd, &increment, sizeof(increment));
	return 0;
}


static int
l_eventfd_close(lua_State *L) {
	int fd = luaL_checkinteger(L, 1);
	if (close(fd)) {
		lua_pushstring(L, strerror(errno));
        return 1;
	}

	return 0;
}

int
lua_lib_eventfd(lua_State *L) {
	static const struct luaL_Reg l[] = {
        {"create", l_eventfd_create},
        {"read", l_eventfd_read},
        {"write", l_eventfd_write},
        {"close", l_eventfd_close},
		{NULL, NULL}
	};

    luaL_newlib(L, l);
    return 1;
}