package main

import (
	"log"
	"net"
	"time"

	"github.com/gorilla/websocket"
)

type WsClient struct {
	Client  net.Conn
	Session string
	Url     string
	Conn    *websocket.Conn
}

func (c *WsClient) Start(url string) {
	dialer := websocket.Dialer{
		HandshakeTimeout: 5 * time.Second,
	}
	conn, _, err := dialer.Dial(url, nil)
	if err != nil {
		log.Fatal("dial:", err)
		c.Response(WsClientResponse{
			Session: c.Session,
			Type:    WS_TCONNECT,
			Error:   err.Error(),
		})
		CleanWsClient(c.Session)
		return
	} else {
		c.Response(WsClientResponse{
			Session: c.Session,
			Type:    WS_TCONNECT,
		})
	}

	go func() {
		for {
			_, message, err := conn.ReadMessage()
			if err != nil {
				c.Response(WsClientResponse{
					Session: c.Session,
					Type:    WS_TCLOSE,
					Error:   err.Error(),
				})
				conn.Close()
				CleanWsClient(c.Session)
				return
			}
			c.Response(WsClientResponse{
				Session: c.Session,
				Type:    WS_TMSG,
				Msg:     string(message),
			})
		}
	}()

	c.Url = url
	c.Conn = conn
}

// call by wind
func (c *WsClient) Send(msg string) {
	c.Conn.WriteMessage(websocket.TextMessage, []byte(msg))
}

func (c *WsClient) Shutdown() {
	c.Conn.WriteMessage(websocket.CloseMessage, websocket.FormatCloseMessage(websocket.CloseNormalClosure, ""))
	c.Conn.Close()
}

// end

func (s *WsClient) Response(r interface{}) {
	response(s.Client, r)
}

type WsClientResponse struct {
	Session string `json:"session"`
	Error   string `json:"error"`
	Type    int    `json:"type"`
	Msg     string `json:"msg"`
}
