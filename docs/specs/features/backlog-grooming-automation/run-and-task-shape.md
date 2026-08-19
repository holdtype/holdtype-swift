# Grooming Run And Task Shape

- Node type: leaf
- Status: Active
- Contract: `holdtype.operations.backlog-grooming.run@1`
- Read when: performing or reviewing one grooming run.
- Do not read when: archiving completed tasks or resolving blockers.
- Maximum size: 100 physical lines.

## Run

1. Read repository workflow and the selected area's Active specs.
2. Read the UI/functionality coverage map and inspect current Swift/tests.
3. Use the historical MVP brief only for behavior left unsettled by Active specs.
4. Add or refine tasks for current missing behavior; use umbrella parents for
   broad areas and small children for executable slices.
5. Change the coverage map only when routing, ownership, or verification needs change.
6. Review each generated diff and split work broader than one agent checkpoint.
7. Run `python3 scripts/backlog_next.py --compact-json` after edits.
8. Commit only groomer-owned backlog/spec/workflow edits.

## Child-task contract

A child normally has one observable output, explicit dependencies and
`allowed_paths`, concrete acceptance criteria, layer-matched verification, and
non-goals where adjacent scope is easy to include. Re-read every new or
materially changed child before commit.

One menu item, service protocol, settings field, fake-backed unit test, or
permission-state mapping are representative sizes. More than one screen,
service, or behavior contract normally requires an umbrella and children.
Split a child that combines UI, service, permissions, network, or persistence.
