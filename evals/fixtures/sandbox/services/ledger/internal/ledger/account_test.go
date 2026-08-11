package ledger

import (
	"errors"
	"testing"
)

func TestStore_Get(t *testing.T) {
	s := NewStore()
	tests := []struct {
		name    string
		id      string
		want    int64
		wantErr error
	}{
		{name: "known account", id: "acc-1001", want: 1250050},
		{name: "zero balance account", id: "acc-1002", want: 0},
		{name: "unknown account", id: "acc-9999", wantErr: ErrNotFound},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			acc, err := s.Get(tt.id)
			if !errors.Is(err, tt.wantErr) {
				t.Fatalf("err = %v, want %v", err, tt.wantErr)
			}
			if tt.wantErr == nil && acc.Balance != tt.want {
				t.Fatalf("balance = %d, want %d", acc.Balance, tt.want)
			}
		})
	}
}

func TestStore_Deposit(t *testing.T) {
	s := NewStore()
	acc, err := s.Deposit("acc-1002", 5000)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if acc.Balance != 5000 {
		t.Fatalf("balance = %d, want 5000", acc.Balance)
	}
}

func TestStore_Deposit_RejectsNonPositive(t *testing.T) {
	s := NewStore()
	if _, err := s.Deposit("acc-1001", 0); err == nil {
		t.Fatal("expected an error for a zero deposit")
	}
}

func TestStore_Deposit_UnknownAccount(t *testing.T) {
	s := NewStore()
	if _, err := s.Deposit("acc-9999", 100); !errors.Is(err, ErrNotFound) {
		t.Fatalf("err = %v, want ErrNotFound", err)
	}
}
