// Package ledger holds account state. Amounts are minor units (cents).
package ledger

import "errors"

// ErrNotFound is returned when no account matches the given id.
var ErrNotFound = errors.New("account not found")

// Account is a customer's ledger account.
type Account struct {
	ID       string
	Name     string
	Currency string
	Balance  int64 // minor units
}

// Store is an in-memory account store.
type Store struct {
	accounts map[string]Account
}

// NewStore returns a Store seeded with the demo accounts.
func NewStore() *Store {
	return &Store{accounts: map[string]Account{
		"acc-1001": {ID: "acc-1001", Name: "Northwind Trading", Currency: "EUR", Balance: 1250050},
		"acc-1002": {ID: "acc-1002", Name: "Eastwind Supply", Currency: "EUR", Balance: 0},
	}}
}

// Get returns the account with the given id, or ErrNotFound.
func (s *Store) Get(id string) (Account, error) {
	acc, ok := s.accounts[id]
	if !ok {
		return Account{}, ErrNotFound
	}
	return acc, nil
}

// Deposit adds amount (minor units) to the account balance.
func (s *Store) Deposit(id string, amount int64) (Account, error) {
	acc, err := s.Get(id)
	if err != nil {
		return Account{}, err
	}
	if amount <= 0 {
		return Account{}, errors.New("deposit amount must be positive")
	}
	acc.Balance += amount
	s.accounts[id] = acc
	return acc, nil
}
