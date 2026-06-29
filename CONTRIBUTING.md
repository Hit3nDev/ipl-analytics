# Contributing

Thanks for your interest in improving this project!

## Development Setup

```bash
git clone https://github.com/YOUR_USERNAME/ipl-analytics.git
cd ipl-analytics
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
```

## Making Changes

### Adding a new dbt model

1. Decide which layer it belongs in:
   - **staging/** — only references `source()`, renames columns, casts types
   - **intermediate/** — business logic, joins between staging models
   - **marts/** — business-ready tables for BI tools; should be the only layer Looker connects to

2. Add it to the appropriate directory
3. Add documentation and tests to the `_*.yml` file in the same directory
4. Run `dbt run --select your_model_name` and `dbt test --select your_model_name`

### SQL Style

We follow the [dbt SQL style guide](https://docs.getdbt.com/best-practices/how-we-style/2-how-we-style-our-sql):

- Lowercase SQL keywords
- Trailing commas
- CTEs for readability (`with source as (...), renamed as (...), final as (...)`)
- `ref()` for models, `source()` for raw tables — never hardcoded table names

Run `sqlfluff lint models/` before committing.

### Branching

- `main` — production; CI runs on every PR
- `feat/your-feature` — new models or features
- `fix/your-fix` — bug fixes

### PR Checklist

- [ ] `dbt run` passes
- [ ] `dbt test` passes
- [ ] New models have YAML documentation
- [ ] `sqlfluff lint` passes
- [ ] README updated if adding a new mart or dashboard page
