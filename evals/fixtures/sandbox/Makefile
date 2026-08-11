.PHONY: verify lint test test-go test-js build

verify: lint test ## Everything CI runs

lint: ## gofmt + go vet + node syntax check
	@test -z "$$(cd services/ledger && gofmt -l .)" || \
		(echo "gofmt: files need formatting:" && cd services/ledger && gofmt -l . && exit 1)
	cd services/ledger && go vet ./...
	cd frontend && npm run lint

test: test-go test-js ## Full test suite

test-go: ## Go tests with the race detector
	cd services/ledger && go test -race ./...

test-js: ## Frontend tests (node:test, no install needed)
	cd frontend && npm test

build: ## Compile the service
	cd services/ledger && go build ./...
