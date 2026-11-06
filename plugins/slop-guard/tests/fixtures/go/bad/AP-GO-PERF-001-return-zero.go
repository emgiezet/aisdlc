package main

import (
	"net/http"
	"time"
)

// Explicit Timeout: 0 in return — literal integer zero is the zero value of
// time.Duration and means no timeout at all.

// Timeout: 0 as the first field, other fields after.
func makeClientZeroFirst() *http.Client {
	// ruleid: slopguard.go.http-client-without-timeout
	return &http.Client{
		Timeout:       0,
		CheckRedirect: func(req *http.Request, via []*http.Request) error { return nil },
	}
}

// Timeout: 0 as the last field, other fields before.
func makeClientZeroLast() *http.Client {
	// ruleid: slopguard.go.http-client-without-timeout
	return &http.Client{
		Transport: http.DefaultTransport,
		Timeout:   0,
	}
}

// Safe counterpart — nonzero timeout must stay silent.
func makeClientBounded() *http.Client {
	// ok: slopguard.go.http-client-without-timeout
	return &http.Client{Timeout: 10 * time.Second}
}
