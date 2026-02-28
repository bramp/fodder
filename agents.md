# Agent Rules for Vibe Coding in Fodder

- **Commit Policy**: You must fully tested all code before commmiting. Do not commit changes automatically. Wait for the user to review and ask for a commit.
- **Code Style**: Prefer modern Dart syntax, strict typing, and test-driven development.
- **Linting**: Code MUST adhere to `very_good_analysis` rules. Fix all linter warnings before considering a file completed.
- **Architecture**: Always prefer Flame's Component System (FCS) by subclassing `Component`, `PositionComponent`, `SpriteAnimationGroupComponent`, etc.
- **Testing**: Code should be designed to be testable. Write `flutter test` compatible tests. When testing Flame components, utilize `flame_test` package if necessary (though plain unit tests map logic are preferred and run faster).
- **Git**: Prefer `git add [file]` over `git add .` to ensure atomic and precise commits. Never run a command that wipes out uncommited work. No `git reset --hard` unless explicitly asked.
- **File Safety**: DO NOT forcefully delete files (e.g. `rm -f`, `git rm -f`). If a file is in the way or causing issues, ask the user or use safer alternatives (e.g. moving/renaming or unstaging).
- **Pre-commit**: We use `pre-commit` to format (`dart format`), analyze (`flutter analyze`), and test (`flutter test`). Ensure nothing is broken before handing off.
- **Test Naming**: Tests for a file `name.dart` should be named `name_test.dart` and located in the corresponding directory in `test/`.
