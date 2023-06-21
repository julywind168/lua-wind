package main

import (
	"fmt"
	"net"
	"os"
)

const socketPath = "/tmp/windproxy.sock"

func main() {
	//  创建 Unix Socket
	os.Remove(socketPath)
	listener, err := net.Listen("unix", socketPath)
	if err != nil {
		panic(err)
	}
	defer listener.Close()

	fmt.Printf("Listening on Unix Domain Socket %s\n", socketPath)

	for {
		// 等待客户端连接
		client, err := listener.Accept()
		if err != nil {
			panic(err)
		}

		// 接收客户端消息
		buffer := make([]byte, 1024)
		length, err := client.Read(buffer)
		if err != nil {
			panic(err)
		}
		message := string(buffer[:length])
		fmt.Printf("Received message from client: %s\n", message)

		// 处理客户端消息
		// TODO: 在这里编写处理客户端消息的逻辑

		// 向客户端发送消息
		response := []byte("Hello, client!")
		_, err = client.Write(response)
		if err != nil {
			panic(err)
		}
		fmt.Printf("Sent message to client: %s\n", string(response))

		// 关闭连接
		client.Close()
	}
}
