package main

import (
	"bytes"
	"io"
	"net/http"
)

type HttpRequestResponse struct {
	Session string      `json:"session"`
	Error   string      `json:"error"`
	Header  http.Header `json:"header"`
	Body    string      `json:"body"`
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
