<!-- markdownlint-disable MD033 -->
# Pipeline review worksheet

Fill in each `<placeholder>`. This is your deliverable for the lab.

## Part A — Classify the pipelines

For each job in `messy-pipeline.yml` (reproduced in the lab README), write its type
and the real-world effect of running it.

| Job | Type (infra / config / validation) | What changes in the real world? |
|-----|------------------------------------|---------------------------------|
| `scan` | `<type>` | `<effect>` |
| `package-chart` | `<type>` | `<effect>` |
| `apply` | `<type>` | `<effect>` |

## Part B — Find the silent-skip anti-patterns

List every place a check could fail without turning the build red, and why it is
dangerous.

1. `<file:line or step name>` — `<why this hides a failure>`
2. `<file:line or step name>` — `<why this hides a failure>`
3. `<file:line or step name>` — `<why this hides a failure>`

## Part C — A one-page fail-loud policy

Write 5–8 rules your team would adopt. Start from these prompts:

- Gates (scans, policy, plan checks) MUST `<rule>`.
- `continue-on-error` is only allowed when `<condition>`, and must `<rule>`.
- Infrastructure `apply` requires `<review rule>` before it runs.
- Each pipeline does exactly one of: `<list the three types>`.
- A failing platform pipeline notifies `<who / where>`.
- Drift is detected by `<mechanism>` and alerts when `<condition>`.
- `<your own rule>`
- `<your own rule>`

## Part D — Validation evidence

Paste the output of `actionlint validation-pipeline.yml` (should be empty / exit 0):

```text
<actionlint output here>
```
