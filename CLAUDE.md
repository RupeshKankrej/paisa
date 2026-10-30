# Paisa — personal expense tracker (Flutter, iOS first)

Read docs/SPEC.md before doing anything. It is the source of truth.
Read docs/PROGRESS.md to see which phase is done and any notes from earlier sessions.

Rules
- Work on exactly ONE phase from SPEC.md section 4 per session, the one I name. Do not start the next phase.
- Anything out of scope goes into docs/BACKLOG.md, not into code.
- Parser and budget maths are pure Dart in lib/domain and lib/core, no Flutter imports, with unit tests.
- All amounts are integer paise; all UI formatting goes through the Money helper.
- Run `flutter analyze` and `flutter test` before telling me a phase is done.
- End every session by updating docs/PROGRESS.md: phase, what was built, what to verify on the device, open issues.
- Commit on a branch named phase-N-<short-name>; do not merge to main yourself.
