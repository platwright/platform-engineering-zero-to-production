# Contributing

Thank you for helping make free, high-quality platform engineering education
available to everyone. This course is built in the open, and contributions of all
sizes are welcome — from fixing a typo to authoring an entire module.

## Ways to contribute

- **Fix or clarify** existing content (typos, broken links, outdated commands).
- **Improve labs** — better instructions, additional edge cases, solution notes.
- **Add diagrams** that explain something hard to express in prose.
- **Write new modules** from the [ROADMAP](./ROADMAP.md), following the content model.
- **Report problems** via [issues](../../issues) — content errors, unclear
  explanations, or things that didn't work.
- **Share feedback** on what helped you learn and what didn't.

## Ground rules (the course philosophy)

Contributions must uphold the course's core principle:

> Understand the problem first. Build the smallest solution yourself.
> Then use the production tool. Know **why** every component exists.

Please **avoid**:

- Tool-first teaching that skips the problem being solved.
- Copy-paste configuration without explaining the parameters.
- Pretending `kubectl apply` equals platform engineering.
- Treating any single product as the definition of platform engineering.
- Deferring security and cost "until later" — they are structural, not bolt-on.
- "Works on my laptop" labs with no production consideration.

## The content model

Every teaching module follows the same arc. Start from the template:
[`shared/templates/module-template.md`](./shared/templates/module-template.md).

```text
Concept → Why it matters for platform engineering → Mental model →
Minimal implementation → Hands-on lab → Production considerations →
Common mistakes → Assessment → Further reading
```

Labs follow [`shared/templates/lab-template.md`](./shared/templates/lab-template.md),
and significant project decisions are recorded as ADRs using
[`shared/templates/adr-template.md`](./shared/templates/adr-template.md).

### Module folder layout

```text
NN-module-name/
├── README.md          # the lesson (follows the module template)
└── lab/
    ├── README.md      # the hands-on lab (follows the lab template)
    └── ...            # worksheets, starter files, templates, solutions
```

## Style guide

- **Audience:** assume a competent engineer who is new to this specific topic.
  Explain the *why*, not just the *how*.
- **Voice:** direct, practical, second person ("you"). Short paragraphs.
- **Markdown:** linted with [markdownlint](./.markdownlint.json). Use dash (`-`)
  bullets, fenced code blocks with a language hint, and sentence-case headings.
- **Line endings:** LF (enforced by [`.gitattributes`](./.gitattributes)); 2-space
  indentation (see [`.editorconfig`](./.editorconfig)).
- **Links:** use relative links within the repo so they work on GitHub and locally.
- **Commands:** prefer runnable, copy-pasteable commands. Note the OS when it matters
  (most labs assume Linux; Windows users can use WSL2).
- **Diagrams:** ASCII/Mermaid in Markdown is fine; put image sources in
  [`diagrams/`](./diagrams/).
- **No secrets, ever:** never commit real credentials, tokens, or private keys —
  not even "example" ones that are real. See [SECURITY.md](./SECURITY.md).

## Development workflow

1. **Fork** the repository and create a branch:
   `git checkout -b content/01-platform-foundations-clarify-dx`.
2. **Make your change.** Keep pull requests focused — one logical change per PR.
3. **Check your Markdown** locally (optional but appreciated):

   ```bash
   npx markdownlint-cli2 "**/*.md"
   ```

4. **Commit** with a clear message (see below) and open a pull request using the
   [PR template](./.github/pull_request_template.md).
5. A maintainer will review. Expect a conversation — we optimize for learner clarity.

### Commit messages

Use short, imperative subject lines, optionally prefixed with the area:

```text
docs(01-foundations): clarify the TVP principle with a worked example
fix(00-orientation): correct kind install link for Windows
feat(shared): add ADR template
```

### Developer Certificate of Origin

By contributing, you certify that you wrote the content or have the right to submit
it under the project licenses, and you agree to license your contribution under the
same terms (see below). We may ask you to sign off commits with `git commit -s`.

## Licensing of contributions

By submitting a contribution you agree that it will be licensed under the same terms
as the repository (see [LICENSE](./LICENSE)):

- **Course content** (prose, diagrams, exercises): CC BY-SA 4.0.
- **Source code** (scripts, config, manifests, code samples): MIT.

Only contribute material you have the right to license this way. Do **not** paste
proprietary content, paid-course material, or text you do not own. When you reference
external sources, cite them in "Further reading" rather than copying them.

## Questions

Open a [discussion](../../discussions) or an issue. Please also read our
[Code of Conduct](./CODE_OF_CONDUCT.md) — it applies to all project spaces.
