package main

import (
	"net/http"
	"time"
)

// 0 * time.X is syntactically a duration expression but evaluates to zero —
// semantically identical to omitting Timeout or setting it to 0.

// Sole field: 0 * time.Second.
func makeClientZeroSecond() *http.Client {
	// ruleid: slopguard.go.http-client-without-timeout
	return &http.Client{Timeout: 0 * time.Second}
}

// Sole field: 0 * time.Millisecond.
func makeClientZeroMillis() *http.Client {
	// ruleid: slopguard.go.http-client-without-timeout
	return &http.Client{Timeout: 0 * time.Millisecond}
}

// Zero-duration expression with other fields after.
func makeClientZeroExprFirst() *http.Client {
	// ruleid: slopguard.go.http-client-without-timeout
	return &http.Client{
		Timeout:   0 * time.Second,
		Transport: http.DefaultTransport,
	}
}

// Zero-duration expression with other fields before.
func makeClientZeroExprLast() *http.Client {
	// ruleid: slopguard.go.http-client-without-timeout
	return &http.Client{
		Transport: http.DefaultTransport,
		Timeout:   0 * time.Millisecond,
	}
}

// Safe counterpart — nonzero multiplier must stay silent.
func makeClientNonzeroExpr() *http.Client {
	// ok: slopguard.go.http-client-without-timeout
	return &http.Client{Timeout: 30 * time.Second}
}
