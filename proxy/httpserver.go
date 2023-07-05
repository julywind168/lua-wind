package main

import (
	"context"
	"io"
	"net"
	"net/http"
	"time"

	"github.com/labstack/echo/v4"
	"github.com/labstack/gommon/log"
)

type Server interface {
	Close()
}

/*
wind => golang
 1. httpserver_create {port = 8080}
 2. httpserver_response {req_session = 1, statuscode = 200, body = ""}
 3. httpserver_close

golang => wind

	1.{req_session = 0, ok = true} 		// create listener ok
	2.{req_session = 1, method = "get", ...}
*/
type HttpServer struct {
	Client     net.Conn
	Session    string
	ReqSession int
	ReqChan    map[int]chan HttpServerReqResult // req_session => chan
	Echo       *echo.Echo
	Address    string
}

func (s *HttpServer) Start(addr string, timeout int) {
	e := echo.New()
	e.Logger.SetLevel(log.INFO)

	handle := func(c echo.Context) error {
		s.ReqSession += 1
		ch := make(chan HttpServerReqResult)
		s.ReqChan[s.ReqSession] = ch

		ctx, cancel := context.WithTimeout(c.Request().Context(), time.Duration(timeout)*time.Second)
		defer cancel()

		query := make(map[string]string)
		for key, value := range c.Request().URL.Query() {
			query[key] = value[0]
		}

		body, err := io.ReadAll(c.Request().Body)
		if err != nil {
			return err
		}

		s.Response(HttpServerResponse{
			Session:    s.Session,
			ReqSession: s.ReqSession,
			Method:     c.Request().Method,
			Path:       c.Request().URL.Path,
			Query:      query,
			Header:     c.Request().Header,
			Body:       string(body),
		})

		select {
		case result := <-ch:
			return c.String(result.StatusCode, result.Body)
		case <-ctx.Done():
			return echo.NewHTTPError(http.StatusGatewayTimeout, "Timeout")
		}
	}

	e.GET("/*", handle)
	e.POST("/*", handle)

	s.Echo = e
	if err := e.Start(addr); err != nil && err != http.ErrServerClosed {
		e.Logger.Fatalf("Failed to start server: %v", err)
		s.Response(HttpServerResponse{
			Session: s.Session,
			Error:   err.Error(),
		})
		CleanHttpServer(s.Session)
	}
}

// call by wind
func (s *HttpServer) OnHttpResponse(req_session int, result HttpServerReqResult) {
	ch := s.ReqChan[req_session]
	ch <- result
}

// send 2 wind
func (s *HttpServer) Response(r interface{}) {
	response(s.Client, r)
}

func (s *HttpServer) Shutdown() {
	println("HttpServer.Shutdown =========================", s.Address)
	s.Echo.Shutdown(context.Background())
}

type HttpServerResponse struct {
	Session string `json:"session"`

	// create_failed
	Error string `json:"error"`

	// new_http_request
	ReqSession int               `json:"req_session"` // http_request session
	Method     string            `json:"method"`      // 'GET' 'POST'
	Path       string            `json:"path"`        // '/hello'
	Query      map[string]string `json:"query"`
	Header     http.Header       `json:"header"`
	Body       string            `json:"body"`
}

type HttpServerReqResult struct {
	StatusCode int
	Body       string
}
