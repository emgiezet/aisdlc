// Package httpapi exposes the ledger over HTTP.
package httpapi

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"

	"example.com/ledger/internal/ledger"
)

// Server routes HTTP requests to the ledger store.
type Server struct {
	store *ledger.Store
	log   *slog.Logger
}

// New returns a Server backed by store.
func New(store *ledger.Store, log *slog.Logger) *Server {
	return &Server{store: store, log: log}
}

// Routes returns the mux with every route registered.
func (s *Server) Routes() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", s.handleHealthz)
	mux.HandleFunc("GET /v1/accounts/{id}", s.handleGetAccount)
	return mux
}

func (s *Server) handleHealthz(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *Server) handleGetAccount(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	acc, err := s.store.Get(id)
	if errors.Is(err, ledger.ErrNotFound) {
		writeError(w, http.StatusNotFound, "account_not_found", "no account with that id")
		return
	}
	if err != nil {
		s.log.Error("get account", "id", id, "err", err)
		writeError(w, http.StatusInternalServerError, "internal_error", "unexpected error")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"id":       acc.ID,
		"name":     acc.Name,
		"currency": acc.Currency,
	})
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}

func writeError(w http.ResponseWriter, status int, code, message string) {
	writeJSON(w, status, map[string]any{
		"error": map[string]string{"code": code, "message": message},
	})
}
