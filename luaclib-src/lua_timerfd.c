#include <stdio.h>
#include <errno.h>
#include <unistd.h>
#include <string.h>
#include <sys/timerfd.h>

#include "lua_timerfd.h"



static int
l_create(lua_State *L) {
	int fd = timerfd_create(CLOCK_MONOTONIC, TFD_NONBLOCK);
	if (fd == -1) {
		lua_pushnil(L);
		lua_pushstring(L, strerror(errno));
		return 2;
	}

	lua_pushinteger(L, fd);
	return 1;
}



static int
l_settime(lua_State *L) {
	int fd = luaL_checkinteger(L, 1);
	lua_Integer delay = luaL_checkinteger(L, 2);


	struct itimerspec timer;
	time_t sec = delay/1000;
	long nsec = 1000000 *(delay%1000);

	timer.it_interval.tv_sec = sec;
	timer.it_interval.tv_nsec = nsec;

	// first
	timer.it_value.tv_sec = sec;
	timer.it_value.tv_nsec = nsec;
	
	int res = timerfd_settime(fd, 0, &timer, NULL);

	if (res == -1) {
		lua_pushstring(L, strerror(errno));
		return 1;
	}

	return 0;
}


static int
l_gettime(lua_State *L) {

	struct itimerspec curr_value;

	int fd = luaL_checkinteger(L, 1);

	if (timerfd_gettime(fd, &curr_value)) {
		lua_pushnil(L);
		lua_pushstring(L, strerror(errno));
		return 2;
	}
	
	return 1;
}

static int
l_read(lua_State *L) {
	static uint64_t time;

	int fd = luaL_checkinteger(L, 1);

	if (read(fd, &time, sizeof(time)) != sizeof(time))
	{
		lua_pushstring(L, strerror(errno));
		return 1;
	}
	return 0;
}


static int
l_close(lua_State *L) {
	int fd = luaL_checkinteger(L, 1);
	if (close(fd)) {
		lua_pushstring(L, strerror(errno));
	}

	return 0;
}


int
lua_lib_timerfd(lua_State *L) {
	static const struct luaL_Reg l[] = {
		{"create", l_create},
		{"settime", l_settime},
		{"gettime", l_gettime},
		{"close", l_close},
		{"read", l_read},
		{NULL, NULL}
	};

    luaL_newlib(L, l);
    return 1;
}
