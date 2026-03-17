# Copilot Progress Reminder

Purpose:
- Keep delivery status in sync with actual implementation progress.

Before updating roadmap visuals or diagram model:
1. Review completed work since last update.
2. Compare completed work against `delivery.workItems` in `docs/architecture/diagram-model.json`.
3. Identify candidate items to move between statuses (`backlog`, `in_progress`, `done`).
4. Ask the user for confirmation before changing any status.

Required user confirmation prompt:
- "I can see progress in Tech Tree/Kanban. Do you agree we should move item(s) X from backlog to done (or in progress)?"

Update flow after user confirmation:
1. Update `docs/architecture/diagram-model.json` statuses.
2. Regenerate artifacts with:
   - `python scripts/generate_mermaid_from_model.py`
3. Verify sync with:
   - `python scripts/generate_mermaid_from_model.py --check`
4. Show changed files and summarize what moved.

Important rule:
- Do not move roadmap status automatically without explicit user agreement.
