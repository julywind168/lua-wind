package main

import (
	"fmt"
	"net"
	"net/http"

	"github.com/gorilla/websocket"
	"github.com/labstack/echo/v4"
	"github.com/labstack/gommon/log"
)

var (
	upgrader = websocket.Upgrader{}
)

type WsServer struct {
	Client  net.Conn
	Session string
	connMap map[string]*websocket.Conn
	Echo    *echo.Echo
	Address string
}

func (s *WsServer) Start(addr string, path string) {
	e := echo.New()
	e.Logger.SetLevel(log.INFO)

	handle := func(c echo.Context) error {
		ws, err := upgrader.Upgrade(c.Response(), c.Request(), nil)

		if err != nil {
			return err
		}
		defer ws.Close()
		fmt.Println("Websocket client connect from:", ws.RemoteAddr().String())

		id := fmt.Sprintf("%p", ws)
		s.connMap[id] = ws

		// connected
		s.Response(WsServerResponse{
			Session: s.Session,
			Client:  id,
			Type:    WS_TCONNECT,
			Addr:    ws.RemoteAddr().String(),
		})

		for {
			_, msg, err := ws.ReadMessage()
			if err != nil {
				c.Logger().Error(err)

				// closed
				s.Response(WsServerResponse{
					Session: s.Session,
					Client:  id,
					Type:    WS_TCLOSE,
					Error:   err.Error(),
				})

				// cleanup
				delete(s.connMap, id)

				return err
			}
			// fmt.Printf("message: %s\n", msg)
			// message
			s.Response(WsServerResponse{
				Session: s.Session,
				Client:  id,
				Type:    WS_TMSG,
				Msg:     string(msg),
			})
		}
	}

	e.GET(path, handle)
	s.Echo = e
	if err := e.Start(addr); err != nil && err != http.ErrServerClosed {
		e.Logger.Fatalf("Failed to start server: %v", err)
		s.Response(WsServerResponse{
			Session: s.Session,
			Client:  "0",
			Error:   err.Error(),
		})
		CleanHttpServer(s.Session)
	}
}

// call by wind
func (s *WsServer) Send(client string, msg string) {
	ws := s.connMap[client]
	ws.WriteMessage(websocket.TextMessage, []byte(msg))
}

func (s *WsServer) Close(client string) {
	ws := s.connMap[client]
	ws.Close()
}

func (s *WsServer) Shutdown() {
	println("WsServer.Shutdown =========================", s.Address)
	s.Echo.Close()
}

// end

// send 2 wind
func (s *WsServer) Response(r interface{}) {
	response(s.Client, r)
}

/*
	msg: {
		client = 0,                 -- client id
		addr = "127.0.0.1:8888"     -- client address
		error = "start failed",
		type = 1,                   -- 1:connect  2:msg  3:error  4:close
		msg = "hello server",
	}
*/

const (
	WS_TCONNECT = iota + 1
	WS_TMSG
	WS_TERROR
	WS_TCLOSE
)

type WsServerResponse struct {
	Session string `json:"session"`
	Client  string `json:"client"`
	Addr    string `json:"addr"`
	Error   string `json:"error"`
	Type    int    `json:"type"`
	Msg     string `json:"msg"`
}
