# Agent Rules for Vibe Coding in Fodder

- **Commit Policy**: You must fully tested all code before commmiting. Do not commit changes automatically. Wait for the user to review and ask for a commit.
- **Code Style**: Prefer modern Dart syntax, strict typing, and test-driven development.
- **Linting**: Code MUST adhere to `very_good_analysis` rules. Fix all linter warnings before considering a file completed.
- **Architecture**: Always prefer Flame's Component System (FCS) by subclassing `Component`, `PositionComponent`, `SpriteAnimationGroupComponent`, etc.
  - **Systems as Components**: Game-wide systems (audio, AI managers, etc.) MUST be `Component` subclasses added to the `FlameGame` tree — never plain classes stored as fields on the game. This ensures proper lifecycle management (`onLoad`, `onRemove`) and makes systems accessible via ancestor queries.
  - **Decoupled access via mixins**: Components that need a system should use a `Has<System>` mixin (e.g. `HasAudioSystem`) that looks up the system in the component tree, rather than coupling to a concrete game class via `HasGameReference<FodderGame>`. This keeps components testable and reusable.
  - **Test doubles**: Each system component should provide a silent/mock subclass (e.g. `SilentAudioSystem`) that records calls for test assertions without loading real resources.
- **Testing**: Code should be designed to be testable. Write `flutter test` compatible tests. When testing Flame components, utilize `flame_test` package if necessary (though plain unit tests map logic are preferred and run faster).
- **Git**: Prefer `git add [file]` over `git add .` to ensure atomic and precise commits. Never run a command that wipes out uncommited work. No `git reset --hard` unless explicitly asked.
- **File Safety**: DO NOT forcefully delete files (e.g. `rm -f`, `git rm -f`). If a file is in the way or causing issues, ask the user or use safer alternatives (e.g. moving/renaming or unstaging).
- **Pre-commit**: We use `pre-commit` to format (`dart format`), analyze (`flutter analyze`), and test (`flutter test`). Ensure nothing is broken before handing off.
- **Test Naming**: Tests for a file `name.dart` should be named `name_test.dart` and located in the corresponding directory in `test/`.
- **Modern Units**: While the original Amiga engine used 50 Hz interrupts and fixed-point tick-based math, this remake uses real-time `dt` (seconds) and floating-point pixels/second. Convert all original values:
  - **Durations**: `original_ticks × 0.06 = seconds` (1 engine tick ≈ 60 ms).
  - **Speeds**: `original_speed × 5 = pixels/second` (established conversion factor accounting for 2× render scale and vector-table scaling). [See `game_config.dart` for all converted constants.]
  - **Probabilities**: Keep original ratios (e.g. 1/8, 1/32) but evaluate per-frame, adjusting for higher frame rates if needed.
  - Do **not** replicate the 50 Hz interrupt loop, 16.16 fixed-point arithmetic, or 512-unit direction circle. Use standard `atan2`, `Vector2`, and frame-rate-independent `dt`.
