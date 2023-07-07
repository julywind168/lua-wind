CFLAG = -Wall -g
INC = -I3rd/lua-5.4.6/src -Isrc -Iluaclib-src 
LIB = -L3rd/lua-5.4.6/src -llua -lm -DLUA_USE_READLINE -ldl -pthread

THIRDINC = -I3rd/lua-cjson \
		-I3rd/lua-md5 \
		-I3rd/lua-bson \
		-I3rd/lua-mongo \

SRC = main.c \
	queue.c \

LUALIB = lua_wind.c \
	lua_serialize.c \
	lua_socket.c \
	lua_epoll.c \
	lua_eventfd.c \
	lua_timerfd.c \
	lua_sha1.c \
	lua_crypt.c \

LUA_CJSON = lua_cjson.c \
	strbuf.c \
	fpconv.c \

LUA_MD5 = md5.c \
	md5lib.c \
	compat-5.2.c \

LUA_BSON = bson.c

LUA_MONGO = lua-mongo.c \
			lua-socket.c \


THIRDLIBS = $(addprefix 3rd/lua-cjson/,$(LUA_CJSON)) \
			$(addprefix 3rd/lua-md5/,$(LUA_MD5)) \
			$(addprefix 3rd/lua-bson/,$(LUA_BSON)) \
			$(addprefix 3rd/lua-mongo/,$(LUA_MONGO)) \


.PHONY: wind

all:
	$(CC) $(CFLAG) -o wind $(addprefix src/,$(SRC)) $(addprefix luaclib-src/,$(LUALIB)) $(THIRDLIBS) $(INC) $(THIRDINC) $(LIB)