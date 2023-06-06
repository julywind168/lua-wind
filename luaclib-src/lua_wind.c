#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <string.h>
#include <unistd.h>
#include <stdatomic.h>
#include <sys/time.h>

#include "lua_wind.h"
#include "lua_epoll.h"
#include "lua_serialize.h"
#include "lua_socket.h"
#include "lua_timerfd.h"
#include "lua_eventfd.h"

#include "queue.h"

#define THREAD_MAIN 0


#define MAX_WORKER 128
#define MAX_THREAD (MAX_WORKER+1)

// 0 is main
// other is worker
static struct Proc g_processes[MAX_THREAD] = {0};
static int last_proc_idx = 0;


/////////////////////////////////// wind.core ///////////////////////////////////
static struct Proc *
getself(lua_State *L) {
	lua_getfield(L, LUA_REGISTRYINDEX, "_PID");
	int pid = lua_tointeger(L, -1);
	lua_pop(L, 1);
	return g_processes + pid;
}

static int
l_self(lua_State *L) {
	struct Proc *self = getself(L);
	lua_pushinteger(L, self->id);
	if (self->id == THREAD_MAIN) {
		return 1;
	}
	lua_pushinteger(L, self->efd);
	return 2;
}

static int
l_recv(lua_State *L) {
	struct Proc *self = getself(L);
	void * data = q_pop(self->queue);
	if (data) {
		lua_pushlightuserdata(L, data);
		return 1;
	} else {
		return 0;
	}
}

static int 
l_send(lua_State *L) {
	int pid = luaL_checkinteger(L, 1);
	void *data = lua_touserdata(L, 2);
	if (data == NULL) {
		luaL_error(L, "send error: data is NULL");
		return 0;
	}
	struct Proc *to = g_processes + pid;
	if (to == NULL) {
		luaL_error(L, "send error: thread %d is no-exist", pid);
		return 0;
	}
	if (q_push(to->queue, data)) {
		// write eventfd to root or worker, to wake up thread
		if (to->id > THREAD_MAIN) {
			static uint64_t increment = 1;
			write(to->efd, &increment, sizeof(increment));
		}
		lua_pushboolean(L, 1);
	} else {
		lua_pushboolean(L, 0);
	}
	return 1;
}

static int
l_nthread(lua_State *L) {
	lua_pushinteger(L, last_proc_idx+1);
	return 1;
}

static int
l_time(lua_State *L)
{   
    struct timeval start;
    gettimeofday( &start, NULL );
    lua_pushinteger(L, 1000*start.tv_sec + start.tv_usec/1000);
    return 1;  /* number of results */
}

static int
l_sleep(lua_State *L) {
	lua_Integer time = lua_tointeger(L, 1);
	sleep(time);
	return 0;
}

int
lua_lib_wind_core(lua_State* L) {
	static const struct luaL_Reg l[] = {
		{"recv", l_recv},
		{"send", l_send},
		{"self", l_self},
		{"nthread", l_nthread},
		{"time", l_time},
		{"sleep", l_sleep},
		{NULL, NULL}
	};
    luaL_newlib(L, l);
    return 1;
}

/////////////////////////////////// wind.main ///////////////////////////////////
static void * ll_thread(void *arg) {
	struct Proc *self = (struct Proc *)arg;
	lua_State *L = self->L;

	// open libs
	luaL_openlibs(L);
	luaL_requiref(L, "wind.epoll", lua_lib_epoll, 0);
	lua_pop(L, 1);
	luaL_requiref(L, "wind.timerfd", lua_lib_timerfd, 0);
	lua_pop(L, 1);
	luaL_requiref(L, "wind.eventfd", lua_lib_eventfd, 0);
	lua_pop(L, 1);
	luaL_requiref(L, "wind.socket", lua_lib_socket, 0);
	lua_pop(L, 1);
	luaL_requiref(L, "wind.serialize", lua_lib_serialize, 0);
	lua_pop(L, 1);
	luaL_requiref(L, "wind.core", lua_lib_wind_core, 0);
	lua_pop(L, 1);
	// end

	if (lua_pcall(L, 0, 0, 0) != 0) {
		luaL_traceback(L, L, lua_tostring(L, -1), 1);
		fprintf(stderr, "worker[%d] error: %s\n", self->id, lua_tostring(L, -1));
	} 
	
	return NULL;
}

static int 
l_fork(lua_State *L) {   
	if (last_proc_idx == MAX_THREAD - 1) {
		luaL_error(L, "the number of threads exceeds the limit");
		return 0;
	}
	int id = ++last_proc_idx;

	const char *filename = luaL_checkstring(L, 1);

	lua_State *L1 = luaL_newstate();

	struct Proc *self = g_processes + id;

	lua_pushinteger(L1, id);
	lua_setfield(L1, LUA_REGISTRYINDEX, "_PID");

	self->id      = id;
	self->L       = L1;
	self->thread  = -1;
	self->queue   = q_initialize();
	self->efd 	  = eventfd(0, 0);

	if (self->efd == -1) {
		perror("eventfd");
		luaL_error(L, "unable to create eventfd");
	}

	if (L1 == NULL)
		luaL_error(L, "unable to create new state");

	if (luaL_loadfile(L1, filename) != 0 )
		luaL_error(L, "error starting thread: %s", lua_tostring(L1, -1));

	if (pthread_create(&self->thread, NULL, ll_thread, self) != 0)
		luaL_error(L, "unable to create new state");

	lua_pushinteger(L, id);
    return 1; 
}

// join root and workers thread
static int
l_join_threads(lua_State *L) {
	int err;
	for (int i = 1; i <= last_proc_idx; i++) {
		err = pthread_join(g_processes[i].thread, NULL);
		if (err) {
			luaL_error(L, "error joining thread: %d\n", err);
			exit(-1);
		}
	}

	// clean worker
	for (int i = 1; i < last_proc_idx; i++) {
		close(g_processes[i].efd);
		lua_close(g_processes[i].L);
		q_free(g_processes[i].queue);
	}

	// clean main
	q_free(g_processes->queue);
	return 0;
}

int
lua_lib_wind_main(lua_State* L)
{
	static const struct luaL_Reg l[] = {
		{"fork", l_fork},
		{"join_threads", l_join_threads},
		{NULL, NULL}
	};
	int pid = 0;
	lua_pushinteger(L, pid);
	lua_setfield(L, LUA_REGISTRYINDEX, "_PID");

	struct Proc *self = g_processes;
	self->id      = pid;
	self->L       = L;
	self->thread  = 0;
	self->queue   = q_initialize();

    luaL_newlib(L, l);
    return 1;
}