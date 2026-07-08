# Website Role Switch Report

- date: 2026-06-29
- project: Josh Personal Brand
- status: deployed_and_verified
- live_url: https://josh404dr.github.io/josh-resume/
- da_url: https://josh404dr.github.io/josh-resume/?role=da

## Delivered

- Rebuilt the corrupted page as clean UTF-8 HTML.
- Added an accessible AI PM / Data Analyst role switch.
- Added direct links using `?role=ai-pm` and `?role=da`.
- Kept shared employment facts consistent while changing the professional
  emphasis, skill ordering, experience bullets, project selection, and contact
  message.
- Added a Data Analyst presentation focused on SQL, Hive, Oracle SQL,
  PostgreSQL, Airflow, Google Apps Script, reporting automation, data quality,
  and operational analytics.
- Preserved the existing resume PDF, contact links, background asset, and
  static GitHub Pages-compatible architecture.

## Evidence Boundary

The Data Analyst version does not claim a separate historical DA job title.
It presents verified data responsibilities and outcomes from the existing
resume under a DA-oriented narrative.

## Verification

- AI PM default view: passed
- DA button switch: passed
- `?role=da` deep link: passed on GitHub Pages
- Dynamic title and role copy: passed
- Hidden/visible role panels: passed
- Desktop viewport 1280x720: passed
- Mobile viewport 390x844: passed
- Horizontal overflow: none
- Resume and contact links: present
- UTF-8 Traditional Chinese rendering: passed
- Live browser console errors: none
- GitHub main deployment commit: `6191124`
