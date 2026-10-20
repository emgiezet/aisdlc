FAIL

# Verify — GH-43-a

Base: `origin/main`  
Head: `da148cd`  
Checked: 2026-10-20T09:57:49Z

| check | result | detail |
|---|---|---|
| committed | PASS | the working tree is the commit being shipped |
| `CI= make validate` | PASS | exit 0 |
| `make selftest` | **FAIL** | exit 2 — see verify.log |
| UC coverage | PASS | 5 UC(s), each named by a changed test |
| tests not weakened | PASS | no test deleted, skipped or focused |
