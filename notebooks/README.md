# `notebooks/`

Jupyter notebooks for exercises that benefit from an interactive, runnable format
— for example, exploring cost data (FinOps), querying metrics, or analyzing SLO
burn rates.

## Conventions

- **Clear outputs before committing** to keep diffs small and avoid leaking data:
  `jupyter nbconvert --clear-output --inplace notebook.ipynb`.
- **Reproducible.** Pin dependencies (a `requirements.txt` next to the notebook)
  and read any data from [`../datasets/`](../datasets/).
- **No secrets.** Never hard-code credentials; read them from the environment.

> 🚧 Populated as interactive modules land. See the [ROADMAP](../ROADMAP.md).
