package main

import (
	"net/http"
	"time"
)

// Returning an &http.Client{} literal with no Timeout field — same as zero value.
func makeDefaultClient() *http.Client {
	// ruleid: slopguard.go.http-client-without-timeout
	return &http.Client{}
}

// Returning with no Timeout field but with other fields set.
func makeNoTimeoutWithCheckRedirect() *http.Client {
	// ruleid: slopguard.go.http-client-without-timeout
	return &http.Client{
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			return nil
		},
	}
}

// Safe: nonzero timeout — must remain silent.
func makeSafeClient() *http.Client {
	// ok: slopguard.go.http-client-without-timeout
	return &http.Client{Timeout: 5 * time.Second}
}
