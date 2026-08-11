package httpapi

import (
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"

	"example.com/ledger/internal/ledger"
)

func newTestServer() *Server {
	return New(ledger.NewStore(), slog.New(slog.NewJSONHandler(io.Discard, nil)))
}

func do(t *testing.T, method, path string) (*http.Response, map[string]any) {
	t.Helper()
	req := httptest.NewRequest(method, path, nil)
	rec := httptest.NewRecorder()
	newTestServer().Routes().ServeHTTP(rec, req)
	res := rec.Result()
	var body map[string]any
	if err := json.NewDecoder(res.Body).Decode(&body); err != nil {
		t.Fatalf("decoding body: %v", err)
	}
	return res, body
}

func TestHealthz(t *testing.T) {
	res, body := do(t, http.MethodGet, "/healthz")
	if res.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want 200", res.StatusCode)
	}
	if body["status"] != "ok" {
		t.Fatalf("status field = %v, want ok", body["status"])
	}
}

func TestGetAccount(t *testing.T) {
	res, body := do(t, http.MethodGet, "/v1/accounts/acc-1001")
	if res.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want 200", res.StatusCode)
	}
	if body["id"] != "acc-1001" || body["currency"] != "EUR" {
		t.Fatalf("unexpected body: %v", body)
	}
}

func TestGetAccount_NotFound(t *testing.T) {
	res, body := do(t, http.MethodGet, "/v1/accounts/acc-9999")
	if res.StatusCode != http.StatusNotFound {
		t.Fatalf("status = %d, want 404", res.StatusCode)
	}
	errObj, ok := body["error"].(map[string]any)
	if !ok || errObj["code"] != "account_not_found" {
		t.Fatalf("unexpected error body: %v", body)
	}
}
