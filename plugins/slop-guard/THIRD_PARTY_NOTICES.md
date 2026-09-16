# Third-Party Notices

This file lists third-party content, taxonomies and tools that Slop Guard
references, uses at runtime, or cites in documentation.

---

## MITRE CWE (Common Weakness Enumeration)

Slop Guard's anti-pattern catalogue maps entries to CWE identifiers.

> Use of CWE identifiers, names and descriptions is permitted under the
> [CWE Terms of Use](https://cwe.mitre.org/about/termsofuse.html).
> CWE is a trademark of The MITRE Corporation.
> Copyright © 2006–2026 The MITRE Corporation.

CWE content is not reproduced in this repository; only identifiers
(e.g. CWE-89, CWE-798) and their short names appear in the catalogue.

---

## OWASP Cheat Sheet Series

The anti-pattern catalogue and skills reference OWASP Cheat Sheet Series
guidance on topics including injection, authentication, and secrets management.

- Source: <https://cheatsheetseries.owasp.org/>
- Licence: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
- Attribution: © OWASP Foundation contributors

All references are paraphrased and linked; no verbatim text from the Cheat
Sheets is reproduced in this repository. The CC BY-SA share-alike clause does
not apply to paraphrase.

---

## nodebestpractices

The Node.js anti-pattern catalogue draws on the nodebestpractices project for
guidance on event-loop blocking, error handling and dependency hygiene.

- Source: <https://github.com/goldbergyoni/nodebestpractices>
- Licence: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
- Attribution: © Yoni Goldberg and contributors

All references are paraphrased and linked; no verbatim text is reproduced in
this repository.

---

## Run-Only Tools

The following tools are downloaded at install time by `slopguard doctor --install`
and executed as separate processes. Their source code and licences are not
distributed in this repository and do not affect the licence of this plugin.

| Tool | Licence | Source |
|---|---|---|
| golangci-lint | GNU General Public Licence v3 (GPLv3) | <https://github.com/golangci/golangci-lint> |
| hadolint | GNU General Public Licence v3 (GPLv3) | <https://github.com/hadolint/hadolint> |
| Opengrep | GNU Lesser General Public Licence v2.1 (LGPL-2.1) | <https://github.com/opengrep/opengrep> |
| njsscan (rules) | GNU Lesser General Public Licence v2.1 (LGPL-2.1) | <https://github.com/ajinabraham/njsscan> |

Each binary is pinned to a specific version and sha256 hash in
`tools/tools.lock.json`. A hash mismatch aborts the installation.
