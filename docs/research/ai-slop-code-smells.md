# AI Slop and Code-Smell Metrics: Evidence Review

**Status:** Research complete — 2026-09-24  
**Scope:** Supports the decision on whether to add a code-smell analyser to slop-guard

---

## 1. Hypothesis Under Test

> **"The AI slop that slop-guard targets is strongly associated with classic code-smell
> metrics — therefore a code-smell analyser adds detection signal that rule-based linters
> do not already provide."**

This document evaluates that hypothesis against empirical evidence.
The hypothesis has two sub-claims:

- **A.** AI-generated code measurably differs from human-written code on code-smell
  metrics (duplication, complexity, dead code, long methods, excessive parameters,
  deep nesting, churn, comment density).
- **B.** The existing slop-guard linter stack does not already cover the metrics where
  the difference is strongest, so a dedicated tool would add net-new signal.

Both sub-claims must hold for the hypothesis to be confirmed.

---

## 2. Evidence Table

| # | Source | Year | What was measured | Sample / method | Finding | Strength |
|---|--------|------|-------------------|-----------------|---------|----------|
| 1 | GitClear, *AI Copilot Code Quality* (2025 report, PDF) — <https://gitclear-public.s3.us-west-2.amazonaws.com/GitClear-AI-Copilot-Code-Quality-2025.pdf> | 2025 | Duplicated blocks (≥5 lines), moved-vs-copy-pasted lines ratio, churn | 211 M changed lines from Google/Microsoft/Meta and enterprise C-Corp repos, 2020–2024 | 2024 was the first year copy/pasted lines exceeded moved (refactored) lines; frequency of blocks with ≥5 duplicated lines rose **8×** in 2024. Code churn (lines revised within two weeks) reached **5.7%** (up from 3.1% in 2020). | **Strong** |
| 2 | GitClear, *The Maintainability Gap* (2026 report) — <https://www.gitclear.com/the_ai_code_quality_maintainability_gap> | 2026 | Duplicated blocks per million changed lines, moved-code %, copy/paste % | Same corpus, extended through mid-2026 | Block duplication reached 73.0/M lines (81% increase over 2023). Moved code fell to **3.8%** of changed lines in 2026 YTD; copy/paste rose to **15.7%**. | **Strong** |
| 3 | Fang et al., *Investigating the Smells of LLM Generated Code* (arXiv:2510.03029) — <https://arxiv.org/html/2510.03029> | 2025 | Implementation smells, design smells (DesigniteJava + equivalent) | LeetCode-style problems solved by Codex, ChatGPT, Gemini Pro, Falcon vs. reference solutions | LLM code showed a **63.34% higher incidence of code smells** vs. reference; implementation smells +73.35%, design smells +21.42%. Codex worst (+84.97%); Falcon best (+42.28%). Smell rates increased with task complexity. | **Strong** |
| 4 | Chukwuemeka et al., *Assessing the Quality and Security of AI-Generated Code* (arXiv:2508.14727) — <https://arxiv.org/html/2508.14727v1> | 2025 | Cyclomatic complexity, cognitive complexity, LOC, dead/unused code | Multiple LLMs (including Claude Sonnet 4, OpenCoder-8B) on standard benchmarks | Claude Sonnet 4 produced 370,816 LOC with cumulative CC 81,667. Dead/unused code was the most prevalent smell category: **34.82%** of smells in Llama 3.2 90B output, **42.74%** in OpenCoder-8B. LLMs struggled with dead-code elimination because it requires whole-project reference analysis beyond their context window. | **Strong** |
| 5 | Chochlov et al., *Evaluating the Code Quality of AI-Assisted Code Generation Tools* (arXiv:2304.10778) — <https://arxiv.org/abs/2304.10778> | 2023 | SonarQube technical debt (code smells), functional correctness | LeetCode + HackerRank problems; ChatGPT, Copilot, CodeWhisperer | Technical-debt remediation time: ChatGPT 8.9 min avg, Copilot 9.1 min, CodeWhisperer 5.6 min, all higher than hand-written baseline. Correct code rate: ChatGPT 65.2%, Copilot 46.3%, CodeWhisperer 31.1%. | **Suggestive** |
| 6 | CodeRabbit, *State of AI vs Human Code Generation Report* (Dec 2025) — <https://www.coderabbit.ai/blog/state-of-ai-vs-human-code-generation-report> | 2025 | Issue count per PR (structured taxonomy) | 470 open-source GitHub PRs, split AI-authored vs. human-authored | AI-authored PRs produced **10.83 issues/PR vs. 6.45 for humans** (1.7× more). Top categories included maintainability, complexity, and unused constructs. | **Suggestive** (vendor study, not peer-reviewed) |
| 7 | Morales-Ramirez et al., *Faster Code, Deeper Debt?* (ACM TOSEM) — <https://doi.org/10.1145/3820165> | 2025 | Code debt, design debt, documentation debt (multivocal) | 104 sources (31 formal, 73 grey) | LLM-assisted development amplifies traditional code, design, and documentation debt; also introduces LLM-specific debt (prompt configuration, instruction debt). | **Suggestive** |
| 8 | Cheng et al., *Human-Written vs AI-Generated Code: A Large-Scale Study* (arXiv:2508.21634; accepted ISSRE 2025) — <https://arxiv.org/abs/2508.21634> | 2025 | Defects, vulnerabilities, structural complexity (500k code samples) | ChatGPT, DeepSeek-Coder, Qwen-Coder vs. human code; Python + Java | **Partial disconfirmation:** AI code is *structurally simpler* (lower cyclomatic complexity) than human code, but more repetitive and more prone to unused constructs and hardcoded debugging. Human code had *higher* concentration of maintainability issues by some metrics. | **Strong** (ISSRE peer-reviewed — limits hypothesis) |
| 9 | Bauer et al., *Does GitHub Copilot Improve Code Quality?* (GitHub Blog / RCT) — <https://github.blog/news-insights/research/does-github-copilot-improve-code-quality-heres-what-the-data-says/> | 2024 | Functional correctness, readability, reliability, maintainability, conciseness | RCT: 202 experienced Python developers creating APIs; expert code reviewers blind-graded output | **Disconfirmation:** Copilot group scored *higher* — readability +3.62%, reliability +2.94%, maintainability +2.47%, conciseness +4.16%. All differences statistically significant. | **Strong** (RCT; but measures human+AI interaction, not pure LLM output) |
| 10 | Yamashita & Moonen, *How Readable is Copilot Code?* (arXiv:2208.14613) — <https://arxiv.org/pdf/2208.14613> | 2022 | Readability, Halstead difficulty, visual inspection | 65 paired code samples (Copilot-assisted vs human) | Copilot code largely comparable on most maintainability metrics; *more difficult* to comprehend on Halstead difficulty (statistically significant). | **Suggestive** (partial confirmation and partial disconfirmation) |
| 11 | Lin et al., *AI-Generated Smells: LLM- and Agent-Driven Development* (arXiv:2605.02741) — <https://arxiv.org/html/2605.02741v1> | 2026 | Code smells, architectural smells at scale | Comparative analysis of human vs. LLM code; longitudinal study of agentic systems | LLMs show a fundamental preference for high-coupling strategies (monolithic methods for simple tasks; tight module coupling for complex tasks). As scale grows, functionally-correct LLM code degenerates into unmaintainable structures. | **Suggestive** |
| 12 | Islam et al., *Rethinking Code Complexity Through the Lens of LLMs* (arXiv:2602.07882) — <https://arxiv.org/html/2602.07882> | 2026 | Cyclomatic complexity, Halstead, nesting depth vs. LLM performance | Controlled study with partial-correlation analysis (length as covariate) | **Limiting:** Traditional complexity metrics (CC, nesting depth) show **no statistically reliable correlation** with LLM-perceived difficulty once code length is controlled. Authors propose a new LLM-specific metric (LM-CC). | **Suggestive** (limits CC as a discriminator) |

### Notes on the disconfirming evidence

Studies 8, 9, and 12 substantially limit the hypothesis:

- Study 8 (ISSRE 2025, 500k samples) finds AI code is *structurally simpler*, not more complex. This directly contradicts the framing that cyclomatic complexity is universally higher in AI output.
- Study 9 (GitHub RCT) finds human-in-the-loop AI assistance *improves* quality across multiple dimensions. slop-guard targets the pure-AI-generated or lightly-reviewed case; the study is not directly contradictory but a necessary reminder of scope.
- Study 12 shows traditional complexity metrics do not reliably discriminate AI from human code when length is controlled.

The tension between studies 4/SonarSource (higher CC in LLM code) and study 8 (lower CC) is likely explained by sample differences: benchmark-only code (typically shorter, simpler problems) skews toward lower CC; large-scale in-repo code assisted by AI accumulates duplication and complexity differently.

---

## 3. Metric Rankings

Ranked by strength of evidence that the metric distinguishes AI-slop from clean code:

### Tier 1 — Strong evidence, should detect

| Metric | Evidence | Notes |
|--------|----------|-------|
| **Duplicated code blocks** | Studies 1, 2 (very strong, 8× increase); confirmed by SonarSource blog (<https://www.sonarsource.com/blog/the-inevitable-rise-of-poor-code-quality-in-ai-accelerated-codebases/>) | Most consistent signal across all observational studies. Copy-paste exceeding refactoring is a corpus-wide trend with 5-year longitudinal backing. |
| **Dead / unreachable code** | Study 4 (34–43% of smells in some models); study 8 (unused constructs distinctive) | Both independent sources agree. Mechanism is clear: LLMs lack whole-project context to prune unreachable branches and unused helpers. |

### Tier 2 — Suggestive, worth detecting but evidence is partial or task-dependent

| Metric | Evidence | Notes |
|--------|----------|-------|
| **Cyclomatic complexity** | Studies 3, 4, SonarSource (higher in LLM code) vs. study 8 (lower in AI code) and study 12 (not reliable) | Result depends on task type. For complex tasks (OOP, algorithms), CC is elevated; for simple tasks, AI code is simpler. An agent generating non-trivial logic is the likely slop-guard target — CC is still worth checking. |
| **Function length (statements / lines)** | Study 3 (implementation smells 73.35%), study 11 (monolithic methods) | Consistent directional evidence but most studies measure smells as a composite rather than isolating line count. |
| **Churn (lines revised within 2 weeks)** | Studies 1, 2 (churn doubled 2020–2024) | Strong signal but not a source-analysis metric; it requires VCS history. Not detectable from source code in a pre-commit hook. |

### Tier 3 — Anecdotal / not consistently supported

| Metric | Evidence | Notes |
|--------|----------|-------|
| **Parameter count** | Mentioned in study 3 as an implementation smell; study 5 used SonarQube which includes it | No study isolates parameter count as a primary AI discriminator. |
| **Nesting depth** | Study 4 measures it; study 12 finds it uncorrelated with LLM difficulty after length control | Directionally possible but not a strong discriminator. |
| **Comment-to-code ratio** | Noted informally (LLMs generate verbose comments) but no empirical study quantifies this as a slop indicator | LLMs produce both over-commented and under-commented code depending on prompt. Not reliable. |

### Metrics the evidence does NOT support as AI-slop discriminators

- **Comment-to-code ratio**: No peer-reviewed evidence that it reliably separates AI from human code.
- **Nesting depth as a standalone metric**: Study 12 specifically tested this and found no reliable correlation after controlling for length.
- **Parameter count**: Not independently validated as an AI-specific smell; it is a general code smell that humans commit too.

---

## 4. Overlap Analysis — What Existing slop-guard Tools Already Cover

The currently active slop-guard linter stack is: **ruff, ESLint, golangci-lint, PHPStan, Psalm, opengrep, checkov, tflint, hadolint, kube-linter, zizmor**.

### 4.1 Cyclomatic / Cognitive Complexity

| Tool | Rules active | Coverage |
|------|-------------|----------|
| **ruff** | `C90` selector → **`C901`** (McCabe ≤12, `[lint.mccabe] max-complexity = 12`); `PLR0912` (branches ≤12); `PLR0915` (statements ≤50); `PLR0911` (returns ≤6) | Python only; `PLR0913` (too-many-args) is **explicitly ignored** in baseline config. |
| **golangci-lint** | `gocognit` enabled, `min-complexity: 20` | Go only; Sonar-style cognitive complexity, not McCabe. **`gocyclo`** (McCabe) is NOT in the enabled set. |
| **ESLint** | `complexity` rule **not enabled**; `max-lines-per-function` **not enabled**; `max-lines` **not enabled** | No complexity gate for JS/TS. |
| PHPStan | Type-checking only (level 8); no complexity rules | PHP has no complexity coverage. |
| Psalm | Type-checking only; no complexity rules | PHP has no complexity coverage. |
| opengrep / checkov / tflint / hadolint / kube-linter / zizmor | Security and IaC only | Not applicable. |

**Gap:** Complexity is partially covered for Python (ruff C901, PLR*) and Go (gocognit), but completely absent for JS/TS and PHP. Go lacks McCabe cyclomatic (`gocyclo` not enabled); ESLint's `complexity` and `max-lines-per-function` are off.

### 4.2 Code Duplication

| Tool | Rules active | Coverage |
|------|-------------|----------|
| **ruff** | No duplication-detection rule exists in ruff | None |
| **golangci-lint** | `dupl` linter **not enabled** (not in enable list) | None |
| **ESLint** | No duplication plugin active | None |
| PHPStan | No clone detection | None |
| Psalm | No clone detection | None |

**Gap:** Code duplication detection is **entirely absent** across all languages in slop-guard. This is the metric with the strongest evidence (studies 1, 2 — 8× increase, 5-year trend). No tool in the current stack catches it.

### 4.3 Dead / Unreachable Code

| Tool | Rules active | Coverage |
|------|-------------|----------|
| **ruff** | `F` rules: `F401` (unused import), `F811` (redefinition of unused name), `F841` (local variable assigned but never used) | Catches *simple* unused symbols in Python. |
| **golangci-lint** | `unused` (in `default: standard`) catches unused exported and unexported identifiers; `unparam` catches unused function parameters | Moderate coverage for Go. |
| **ESLint** | `no-unused-vars` in `js.configs.recommended` (enabled via `extends: [js.configs.recommended]`) | Catches unused variables/imports in JS/TS. |
| PHPStan | Level 8 catches some unreachable-code patterns; no dedicated dead-code pass | Partial for PHP. |
| Psalm | `UnusedVariable`, `UnusedParam` at strict config levels | Partial for PHP. |

**Gap:** Simple unused-symbol detection is covered. Complex dead code — unreachable branches after always-true conditions, entire unused helper functions in larger context, dead code the LLM generates due to context-window blindness — is not caught. These require whole-program analysis (a PHP dead-code tool, or an IDE-grade analyser). The gap is real but narrower than duplication.

### 4.4 Function Length

| Tool | Rules active | Coverage |
|------|-------------|----------|
| **ruff** | `PLR0915` (max-statements = 50) | Python statements proxy for length. |
| **golangci-lint** | `gocognit` (min-complexity: 20) as an indirect proxy; no dedicated line-count rule | No direct line-count rule for Go. |
| **ESLint** | `max-lines-per-function` **not enabled** | None for JS/TS. |
| PHPStan / Psalm | None | None for PHP. |

**Gap:** Function-length gates are absent for JS/TS and PHP. Python is covered via statement count (PLR0915). Go lacks a dedicated length rule (gocognit is a proxy).

### 4.5 Summary of Genuinely Uncovered Metrics

| Metric | Covered? | Gap severity |
|--------|----------|-------------|
| Duplicated blocks | **No coverage across all languages** | Critical — strongest evidence, zero coverage |
| Dead code (complex) | Partial (simple unused symbols only) | Moderate |
| JS/TS function length | Not covered | Low-moderate (ESLint rule exists but is off) |
| Go cyclomatic complexity (McCabe) | Not covered (`gocyclo` not enabled; only cognitive) | Low |
| PHP complexity | Not covered | Low-moderate |
| Parameter count (Python) | Not covered (`PLR0913` explicitly ignored) | Low |

---

## 5. Verdict

The hypothesis is **partially confirmed** for sub-claim A and **confirmed** for sub-claim B, but with important limitations.

**Sub-claim A** (AI code differs on code-smell metrics): largely supported by multiple independent observational studies (GitClear 2025/2026, arXiv:2510.03029, arXiv:2508.14727, CodeRabbit 2025) for the metrics of duplicated blocks, dead code, and — more contingently — cyclomatic complexity. However, the ISSRE 2025 large-scale controlled study (arXiv:2508.21634, 500k samples) is a significant disconfirmation for cyclomatic complexity specifically: AI code in controlled benchmarks is structurally *simpler*, not more complex. The strongest single piece of evidence is GitClear's longitudinal corpus study (211 M lines, 2020–2026), which shows an 8× increase in duplicated code blocks coinciding with the adoption of AI coding assistants — a signal that is consistent, large in magnitude, and replicated in the follow-up 2026 report.

**Sub-claim B** (existing tools do not already cover the strongest metrics): confirmed. Code duplication detection — the metric with the strongest evidentiary backing — is completely absent from the current slop-guard stack across all languages. golangci-lint's `dupl` linter, ESLint's `max-lines-per-function` and `complexity` rules, and any cross-language clone-detector are all inactive or not installed. A dedicated tool that closes the duplication gap would add genuine, non-redundant detection signal. Complexity is partially covered (ruff C901 for Python, gocognit for Go) but not for JS/TS or PHP, so a supplementary complexity rule for those stacks would also add net-new signal. The other uncovered metrics (nesting depth, comment density, parameter count) are not well-supported by the evidence and should not drive a new tool selection.

---

*Sources indexed by study number in Section 2; all URLs verified at time of research.*
