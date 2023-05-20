#ifndef LUA_WIND_H
#define LUA_WIND_H

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <stdatomic.h>
#include <stdint.h>
#include <pthread.h>
#include <sys/eventfd.h>
#include <sys/epoll.h>

#include "queue.h"


// 0 is main
// 1 is root
// 2+ is worker
struct Proc {
	lua_State *L;
	int id;
	Queue *queue;
	pthread_t thread;
    int efd;
};

struct State {
    uint32_t id;
    uint32_t thread_id;
    bool root;
};


int
lua_lib_wind_main(lua_State* L);


int
lua_lib_wind_core(lua_State* L);




#endif