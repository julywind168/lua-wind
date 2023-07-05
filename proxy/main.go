package main

import (
	"bufio"
	"bytes"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"net"
	"net/http"
	"os"

	"github.com/gorilla/websocket"
)

const socketPath = "/tmp/windproxy.sock"

var httpserver_session = make(map[string]*HttpServer)
var wsserver_session = make(map[string]*WsServer)
var wsclient_session = make(map[string]*WsClient)

func main() {
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

	fmt.Printf("Listening on Unix Domain Socket %s\n", socketPath)
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
				fmt.Printf("Error reading package length from socket: %v\n", err)
			}
			break
		}
		pkgLen := binary.BigEndian.Uint16(pkgLenBuf)
		pkgBuf := make([]byte, pkgLen)
		if _, err := io.ReadFull(reader, pkgBuf); err != nil {
			if err != io.EOF {
				fmt.Printf("Error reading package body from socket: %v\n", err)
			}
			break
		}
		fmt.Printf("Received package with length %v: %v\n", pkgLen, string(pkgBuf))
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
		c := wsclient_session[session]
		c.Send(msg)
	} else if cmd == "wsclient_shutdown" {
		c := wsclient_session[session]
		c.Shutdown()
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

func do_http_request(params map[string]interface{}) (string, http.Header, error) {
	method := params["method"].(string)
	url := params["url"].(string)
	body := params["body"].(string)
	header := params["header"].(map[string]interface{})

	req, err := http.NewRequest(method, url, bytes.NewBuffer([]byte(body)))
	if err != nil {
		return "", nil, err
	}
	for key, value := range header {
		req.Header.Set(key, value.(string))
	}

	httpc := &http.Client{}
	resp, err := httpc.Do(req)
	if err != nil {
		return "", nil, err
	}
	defer resp.Body.Close()

	result, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", nil, err
	} else {
		return string(result), resp.Header, nil
	}
}

func response(client net.Conn, r interface{}) {
	response, err := json.Marshal(r)
	if err != nil {
		fmt.Println(err)
		return
	}
	_, err = client.Write(string_pack(response))
	if err != nil {
		fmt.Println(err)
		return
	}
	fmt.Printf("Sent message to client: %s\n", string(response))
}

func cleanup() {
	fmt.Println("cleanup =======================================")
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
	if length > (int(math.Pow(2, 16)) - 1) {
		panic(fmt.Sprintf("Value %d is out of range for uint16", length))
	}
	headerBytes := make([]byte, 2)
	binary.BigEndian.PutUint16(headerBytes, uint16(length))
	newData := append(headerBytes, data...)
	return newData
}

type HttpRequestResponse struct {
	Session string      `json:"session"`
	Error   string      `json:"error"`
	Header  http.Header `json:"header"`
	Body    string      `json:"body"`
}
