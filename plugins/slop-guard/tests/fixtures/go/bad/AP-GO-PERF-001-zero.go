package main

import (
	"net/http"
)

// Timeout: 0 is the zero value of time.Duration, meaning no timeout at all.
// This is semantically identical to omitting the field entirely.

func clientZeroExplicit() *http.Client {
	// ruleid: slopguard.go.http-client-without-timeout
	return &http.Client{Timeout: 0}
}

func clientZeroWithOtherField() *http.Client {
	// ruleid: slopguard.go.http-client-without-timeout
	client := &http.Client{
		Transport: http.DefaultTransport,
		Timeout:   0,
	}
	return client
}
