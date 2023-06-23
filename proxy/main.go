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
					fmt.Println("url: " + params["url"].(string))
					do_http_get(client, session, params["url"].(string))
				}
			}
		}()
	}
}

func do_http_get(client net.Conn, session string, url string) {
	resp, err := http.Get(url)
	if err != nil {
		fmt.Println("HTTP GET 请求失败：", err)
		return
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		fmt.Println("读取 HTTP 响应失败：", err)
		return
	}

	r := HttpGetResponse{
		Session: session,
		Body:    string(body),
	}

	response, err := json.Marshal(r)
	if err != nil {
		fmt.Println(err)
		return
	}
	_, err = client.Write(response)
	if err != nil {
		panic(err)
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
	Body    string `json:"body"`
}
