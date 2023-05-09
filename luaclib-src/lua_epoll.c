#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include <fcntl.h>
#include <sys/epoll.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>

#include "lua_epoll.h"


typedef enum EPOLL_EVENTS EVENTMASK;

#define DSERR() \
    lua_pushnil(L); \
    lua_pushstring(L,strerror(errno)); \
    return 2 \

static int setnonblocking(lua_State *L){
    int flags,fd;

    fd=luaL_checkinteger(L,1);

    if((flags=fcntl(fd,F_GETFL,0))==-1){
        DSERR();
    }
    flags|=O_NONBLOCK;
    if(fcntl(fd,F_SETFL,flags)==-1){
        DSERR();
    }
    lua_pushboolean(L,1);
    return 1;
}

static int ep_create(lua_State *L){
    int epfd;

    if((epfd=epoll_create(1))==-1){
        DSERR();
    }
    lua_pushinteger(L, epfd);
    return 1;
}

static int ep_event_add(lua_State *L){
    int epfd,fd;
    EVENTMASK eventmask;
    
    epfd=luaL_checkinteger(L,1);
    fd=luaL_checkinteger(L,2);
    eventmask=luaL_checknumber(L,3);

    struct epoll_event ev;
    ev.data.fd=fd;
    ev.events=eventmask;

    if(epoll_ctl(epfd,EPOLL_CTL_ADD,fd,&ev)==-1){
        DSERR();
    }
    lua_pushboolean(L,1);
    return 1;
}


static int ep_event_mod(lua_State *L){
    int epfd,fd;
    EVENTMASK eventmask;
    
    epfd=luaL_checkinteger(L,1);
    fd=luaL_checkinteger(L,2);
    eventmask=luaL_checknumber(L,3);

    struct epoll_event ev;
    ev.data.fd=fd;
    ev.events=eventmask;

    if(epoll_ctl(epfd,EPOLL_CTL_MOD,fd,&ev)==-1){
        DSERR();
    }
    lua_pushboolean(L,1);
    return 1;
}


static int ep_event_del(lua_State *L){
    int epfd,fd;

    epfd=luaL_checkinteger(L,1);
    fd=luaL_checkinteger(L,2);

    if(epoll_ctl(epfd,EPOLL_CTL_DEL,fd,NULL)==-1){
        DSERR();
    }
    lua_pushboolean(L,1);
    return 1;
}

static int ep_wait(lua_State *L){
    int i,n,epfd,timeout,max_events;

    epfd=luaL_checkinteger(L,1);
    timeout=luaL_checkinteger(L,2);
    max_events=luaL_checkinteger(L,3);

    struct epoll_event events[max_events];

    if((n=epoll_wait(epfd,events,max_events,timeout))==-1){
        DSERR();
    }
    lua_newtable(L);
    for(i=0;i<n;++i){
        lua_pushinteger(L,events[i].data.fd);
        lua_pushinteger(L,events[i].events);         // old is lua_pushnumber
        lua_settable(L,-3);
    }
    return 1;
}

static int ep_close(lua_State *L){
    int fd;

    fd=luaL_checkinteger(L,1);

    if(close(fd)==-1){
        DSERR();
    }
    lua_pushboolean(L,1);
    return 1;
}


int
lua_lib_epoll(lua_State* L)
{
    static const struct luaL_Reg epoll[]={
        {"setnonblocking",setnonblocking},
        {"create",ep_create},
        {"register",ep_event_add},
        {"modify",ep_event_mod},
        {"unregister",ep_event_del},
        {"wait",ep_wait},
        {"close",ep_close},
        {NULL,NULL},
    };
    luaL_newlib(L, epoll);
    
#define SETCONST(EVENT) \
    lua_pushnumber(L,EVENT); \
    lua_setfield(L,-2,#EVENT) \

    SETCONST(EPOLLIN);
    SETCONST(EPOLLPRI);
    SETCONST(EPOLLOUT);
    SETCONST(EPOLLRDNORM);
    SETCONST(EPOLLRDBAND);
    SETCONST(EPOLLWRNORM);
    SETCONST(EPOLLWRBAND);
    SETCONST(EPOLLMSG);
    SETCONST(EPOLLERR);
    SETCONST(EPOLLHUP);
    SETCONST(EPOLLRDHUP);
    SETCONST(EPOLLONESHOT);
    SETCONST(EPOLLET);

    return 1;
}
