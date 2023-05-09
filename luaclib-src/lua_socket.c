#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <pthread.h>

#include "lua_socket.h"

#define BACKLOG 32

extern int errno;


int setnonblocking(int sockfd)
{
    int flags = fcntl(sockfd, F_GETFL, 0); 
    if (fcntl(sockfd, F_SETFL, flags | O_NONBLOCK) == -1)
        return -1;
    return 0;
}

static int
l_connect(lua_State *L) {
	const char *ip;
	int fd, port;
	short sin_family;
	struct sockaddr_in dest_addr;


	ip = luaL_checkstring(L, 1);
	port = luaL_checkinteger(L, 2);
	sin_family = (short)luaL_optinteger(L, 3, AF_INET);

	fd = socket(PF_INET, SOCK_STREAM, 0);
	if (fd == -1) {
		perror("socket");
		lua_pushnil(L);
		lua_pushstring(L, strerror(errno));
		return 2;
	}

	bzero(&dest_addr, sizeof(dest_addr));
	dest_addr.sin_addr.s_addr = inet_addr(ip);
	dest_addr.sin_port = htons(port);
	dest_addr.sin_family = sin_family;

	if (connect(fd, (struct sockaddr *)&dest_addr, sizeof(struct sockaddr)) == -1) {
		lua_pushnil(L);
		lua_pushstring(L, strerror(errno));
		return 2;
	}

	lua_pushinteger(L, fd);
	return 1;
}


static int
l_listen(lua_State *L) {
	static int reuse = 1;
	const char * host;
	int port;
	int listener;
	struct sockaddr_in my_addr;
	short sin_family;

	host = luaL_checkstring(L, 1);
	port = luaL_checkinteger(L, 2);
	sin_family = (short)luaL_optinteger(L, 3, AF_INET);

    if ((listener = socket(PF_INET, SOCK_STREAM, 0)) == -1) {
        perror("socket\n");
        return 0;
    }

    bzero(&my_addr, sizeof(my_addr));

    my_addr.sin_family = sin_family;
    my_addr.sin_port = htons(port);
    my_addr.sin_addr.s_addr = inet_addr(host);

	if (setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, (void *)&reuse, sizeof(int)) == -1) {
		perror("setsockopet\n");
		return 0;
	}

    if (bind(listener, (struct sockaddr *)&my_addr, sizeof(struct sockaddr)) == -1) {
        perror("bind\n");
        return 0;
    }

    if (listen(listener, BACKLOG) == -1) {
    	perror("listen\n");
    	return 0;
    }

    lua_pushinteger(L, listener);
    return 1;
}


static int
l_accept(lua_State *L)
{
	static struct sockaddr_in client_addr;
	static socklen_t client_addr_len = sizeof(struct sockaddr_in);

	char * ip;
	int port;
             
	int listener = luaL_checkinteger(L, 1);
	int sock = accept(listener, (struct sockaddr *)&client_addr, &client_addr_len);
	if (sock < 0) {

		if (errno == EAGAIN) {
			lua_pushnil(L);
			lua_pushnil(L);
			lua_pushstring(L, "timeout");
			return 3;
		} else {
			lua_pushnil(L);
			lua_pushnil(L);
			lua_pushstring(L, strerror(errno));
			return 3;
		}
	}

    ip = inet_ntoa(client_addr.sin_addr);
    port = ntohs(client_addr.sin_port);

    int len = strlen(ip);
    char addr[len + 10];
   	memcpy(addr, ip, len);
   	addr[len] = ':';
   	sprintf(addr + len + 1, "%d", port);

	lua_pushinteger(L, sock);
	lua_pushstring(L, addr);
	return 2;
}

static int
l_recv(lua_State *L) {
	int fd = luaL_checkinteger(L, 1);
	int sz = luaL_optinteger(L, 2, 1024);
	char buffer[sz];

	int len = recv(fd, buffer, sz, 0);
	if (len > 0) {
		lua_pushlstring(L, buffer, len);
		return 1;
	} else if (len == 0) {
		lua_pushstring(L, "");
		lua_pushstring(L, "closed");
		return 2;
	} else {
		if (errno == EAGAIN) {
			lua_pushnil(L);
			lua_pushstring(L, "timeout");
			return 2;
		} else {
			lua_pushnil(L);
			lua_pushstring(L, strerror(errno));
			return 2;
		}		
	}
}


static int
l_send(lua_State *L) {
	size_t sz;
	int fd = luaL_checkinteger(L, 1);
	const char *msg = luaL_checklstring(L, 2, &sz);

	int len = send(fd, msg, (int)sz, 0);
	lua_pushinteger(L, len);
	return 1;
}


static int
l_close(lua_State *L) {
	int fd = luaL_checkinteger(L, 1);
	int err = shutdown(fd, 2); // stop both reception and transmission

	if (err == -1) {
		perror("shutdown");
	}

	return 0;
}


static int
l_setnonblocking(lua_State *L) {
	int fd = luaL_checkinteger(L, 1);
	setnonblocking(fd);
	lua_pushinteger(L, fd);
	return 1;
}

int
lua_lib_socket(lua_State *L) {
	static const struct luaL_Reg l[] = {
		{"listen", l_listen},
		{"setnonblocking", l_setnonblocking},
		{"accept", l_accept},
		{"send", l_send},
		{"recv", l_recv},
		{"close", l_close},

		// client
		{"connect", l_connect},
	    {NULL, NULL}
	};

    luaL_newlib(L, l);
    return 1;
}
