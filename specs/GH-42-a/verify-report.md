FAIL

# Verify — GH-42-a

Base: `origin/main`  
Head: `3654792`  
Checked: 2026-10-20T09:57:56Z

| check | result | detail |
|---|---|---|
| committed | PASS | the working tree is the commit being shipped |
| `CI= make validate` | PASS | exit 0 |
| `make selftest` | **FAIL** | exit 2 — see verify.log |
| UC coverage | PASS | 7 UC(s), each named by a changed test |
| tests not weakened | PASS | no test deleted, skipped or focused |
