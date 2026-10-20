FAIL

# Verify — GH-44

Base: `origin/main`  
Head: `758e96c`  
Checked: 2026-10-20T09:32:49Z

| check | result | detail |
|---|---|---|
| committed | PASS | the working tree is the commit being shipped |
| `CI= make validate` | **FAIL** | exit 2 — see verify.log |
| `make selftest` | PASS | exit 0 |
| UC coverage | PASS | 8 UC(s), each named by a changed test |
| tests not weakened | PASS | no test deleted, skipped or focused |
