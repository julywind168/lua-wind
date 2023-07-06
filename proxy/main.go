package main

import (
	"bufio"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"os"

	"github.com/gorilla/websocket"
	"github.com/sevlyar/go-daemon"
)

const socketPath = "/tmp/windproxy.sock"
const MAX_PACKSIZE = 65535

var httpserver_session = make(map[string]*HttpServer)
var wsserver_session = make(map[string]*WsServer)
var wsclient_session = make(map[string]*WsClient)

func main() {
	cntxt := &daemon.Context{
		PidFileName: "echo.pid",
		PidFilePerm: 0644,
		LogFileName: "server.log",
		LogFilePerm: 0640,
		WorkDir:     "./",
		Umask:       027,
		Args:        []string{"[wind-proxy]"},
	}

	d, err := cntxt.Reborn()
	if err != nil {
		log.Fatal("Unable to run: ", err)
	}
	if d != nil {
		return
	}
	defer cntxt.Release()

	log.Print("- - - - - - - - - - - - - - -")
	log.Print("daemon started")

	if _, err := os.Stat(socketPath); err == nil {
		if err := os.RemoveAll(socketPath); err != nil {
			fmt.Println(err)
			return
		}
	}
	cleanup()
	listener, err := net.Listen("unix", socketPath)
	if err != nil {
		panic(err)
	}
	defer listener.Close()

	log.Printf("Listening on Unix Domain Socket %s\n", socketPath)
	for {
		client, err := listener.Accept()
		if err != nil {
			panic(err)
		}
		go handleClient(client)
	}
}

func handleClient(c net.Conn) {
	defer c.Close()
	reader := bufio.NewReader(c)
	for {
		pkgLenBuf := make([]byte, 2)
		if _, err := io.ReadFull(reader, pkgLenBuf); err != nil {
			if err != io.EOF {
				log.Printf("Error reading package length from socket: %v\n", err)
			}
			break
		}
		pkgLen := binary.BigEndian.Uint16(pkgLenBuf)
		pkgBuf := make([]byte, pkgLen)
		if _, err := io.ReadFull(reader, pkgBuf); err != nil {
			if err != io.EOF {
				log.Printf("Error reading package body from socket: %v\n", err)
			}
			break
		}
		// log.Printf("Received package with length %v: %v\n", pkgLen, string(pkgBuf))
		go handleRequest(c, pkgBuf)
	}
	// disconnect to wind, cleanup
	cleanup()
}

func handleRequest(c net.Conn, message []byte) {
	var data []interface{}
	err := json.Unmarshal([]byte(message), &data)
	if err != nil {
		fmt.Println(err)
	}

	session := data[0].(string)
	cmd := data[1].(string)
	params := data[2].(map[string]interface{})

	// ===================== http-request =====================
	if cmd == "http_request" {
		go func() {
			body, header, err := do_http_request(params)
			if err != nil {
				response(c, HttpRequestResponse{
					Session: session,
					Error:   err.Error(),
				})
			} else {
				response(c, HttpRequestResponse{
					Session: session,
					Header:  header,
					Body:    body,
				})
			}
		}()

		// ===================== httpserver =====================
	} else if cmd == "httpserver_create" {
		host := params["host"].(string)
		port := params["port"].(string)
		timeout := params["timeout"].(float64)
		s := HttpServer{
			Client:     c,
			Session:    session,
			ReqSession: 0,
			ReqChan:    make(map[int]chan HttpServerReqResult),
			Address:    host + ":" + port,
		}
		go s.Start(s.Address, int(timeout))
		httpserver_session[session] = &s

	} else if cmd == "httpserver_response" {
		req_session := params["req_session"].(float64)
		statuscode := params["statuscode"].(float64)
		body := params["body"].(string)
		s := httpserver_session[session]
		s.OnHttpResponse(int(req_session), HttpServerReqResult{int(statuscode), body})
	} else if cmd == "httpserver_shutdown" {
		s := httpserver_session[session]
		s.Shutdown()
		CleanHttpServer(session)

		// ===================== websockt server =====================
	} else if cmd == "wsserver_create" {
		host := params["host"].(string)
		port := params["port"].(string)
		path := params["path"].(string)
		s := WsServer{
			Client:  c,
			Session: session,
			connMap: make(map[string]*websocket.Conn),
			Address: host + ":" + port,
		}
		go s.Start(s.Address, path)
		wsserver_session[session] = &s
	} else if cmd == "wsserver_send" {
		client := params["client"].(string)
		msg := params["msg"].(string)
		s := wsserver_session[session]
		s.Send(client, msg)
	} else if cmd == "wsserver_close" {
		client := params["client"].(string)
		s := wsserver_session[session]
		s.Close(client)
	} else if cmd == "wsserver_shutdown" {
		s := wsserver_session[session]
		s.Shutdown()
		CleanWsServer(session)

		// ===================== websockt client =====================
	} else if cmd == "wsclient_connect" {
		url := params["url"].(string)
		ws := WsClient{
			Client:  c,
			Session: session,
		}
		go ws.Start(url)
		wsclient_session[session] = &ws
	} else if cmd == "wsclient_send" {
		msg := params["msg"].(string)
		ws := wsclient_session[session]
		ws.Send(msg)
	} else if cmd == "wsclient_shutdown" {
		ws := wsclient_session[session]
		ws.Shutdown()
		CleanWsClient(session)
	}
}

func CleanWsClient(session string) {
	delete(wsclient_session, session)
}

func CleanWsServer(session string) {
	delete(wsserver_session, session)
}

func CleanHttpServer(session string) {
	delete(httpserver_session, session)
}

func response(client net.Conn, r interface{}) {
	response, err := json.Marshal(r)
	if err != nil {
		log.Println("response error", err)
		return
	}
	_, err = client.Write(string_pack(response))
	if err != nil {
		log.Println("response error", err)
		return
	}
	// log.Printf("Sent message to client: %s\n", string(response))
}

func cleanup() {
	for key, value := range httpserver_session {
		value.Shutdown()
		delete(httpserver_session, key)
	}
	for key, value := range wsserver_session {
		value.Shutdown()
		delete(wsserver_session, key)
	}
	for key, value := range wsclient_session {
		value.Shutdown()
		delete(wsclient_session, key)
	}
}

// 大端2字节
func string_pack(data []byte) []byte {
	var length int = len(data)
	if length > MAX_PACKSIZE {
		panic(fmt.Sprintf("Value %d is out of range for uint16", length))
	}
	pack := make([]byte, 2, 2+length)
	binary.BigEndian.PutUint16(pack, uint16(length))
	return append(pack, data...)
}
