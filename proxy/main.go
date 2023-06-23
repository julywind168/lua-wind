package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
)

const socketPath = "/tmp/windproxy.sock"

func main() {
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

		// 接收客户端消息
		go func() {
			for {
				buffer := make([]byte, 1024)
				length, err := client.Read(buffer)
				if err != nil {
					fmt.Println(err)
					client.Close()
					return
				}
				message := string(buffer[:length])
				fmt.Printf("Received message from client: %s\n", message)

				// 处理客户端消息
				// TODO: 在这里编写处理客户端消息的逻辑
				var data []interface{}
				err = json.Unmarshal([]byte(message), &data)
				if err != nil {
					fmt.Println(err)
				}

				session := data[0].(string)
				cmd := data[1].(string)
				params := data[2].(map[string]interface{})

				if cmd == "http_get" {
					do_http_get(client, session, params)
				}
			}
		}()
	}
}

func do_http_get(client net.Conn, session string, params map[string]interface{}) {

	url := params["url"].(string)
	headers := params["headers"].(map[string]interface{})

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		response(client, HttpGetResponse{
			Session: session,
			Error:   err.Error(),
		})
		return
	}

	for key, value := range headers {
		req.Header.Set(key, value.(string))
	}

	httpc := &http.Client{}
	resp, err := httpc.Do(req)
	if err != nil {
		response(client, HttpGetResponse{
			Session: session,
			Error:   err.Error(),
		})
		return
	}

	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		response(client, HttpGetResponse{
			Session: session,
			Error:   err.Error(),
		})
	} else {
		response(client, HttpGetResponse{
			Session: session,
			Body:    string(body),
		})
	}
}

func response(client net.Conn, r interface{}) {
	response, err := json.Marshal(r)
	if err != nil {
		fmt.Println(err)
		return
	}
	_, err = client.Write(response)
	if err != nil {
		fmt.Println(err)
		return
	}
	fmt.Printf("Sent message to client: %s\n", string(response))
}

func cleanup() {
	if _, err := os.Stat(socketPath); err == nil {
		if err := os.RemoveAll(socketPath); err != nil {
			fmt.Println(err)
		}
	}
}

type HttpGetResponse struct {
	Session string `json:"session"`
	Error   string `json:"error"`
	Body    string `json:"body"`
}
