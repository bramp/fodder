/// Central game constants converted from the original Amiga engine values
/// to modern real-time units (seconds, pixels/second).
///
/// ## Conversion factors
///
/// The original engine ran at ~16.67 engine ticks/sec (~60 ms per tick).
/// All "tick" values in the spec docs are converted here using:
///
/// - **Durations:** `ticks × 0.06 = seconds`
/// - **Speeds:** `original_speed × 5.0 = pixels/second`
///   (accounts for 2× render scale and the sin-table >> 16 shift)
/// - **Probabilities:** kept as original ratios (e.g. 1/8, 1/32)
///
/// See `docs/ENGINE.md` and the project `agents.md` for details.
library;

// ---------------------------------------------------------------------------
// Timing
// ---------------------------------------------------------------------------

/// Duration of one original engine tick in seconds.
const double tickDuration = 0.06;

/// Engine ticks per second (~16.67).
const double tickRate = 1.0 / tickDuration;

/// Multiplier to convert an original speed value to pixels/second.
const double speedScale = 5;

/// Converts an original tick count to seconds.
double ticksToSeconds(int ticks) => ticks * tickDuration;

/// Converts an original per-tick speed to pixels/second.
double speedToPixelsPerSecond(double speed) => speed * speedScale;

// ---------------------------------------------------------------------------
// Player movement speeds  (PLAYER.md §2.1)
// ---------------------------------------------------------------------------

/// Player speed mode 0 — halted/slow.
/// Original: 8 per tick → 40 px/s.
const double playerSpeedHalted = 8 * speedScale; // 40

/// Player speed mode 1 — normal walk.
/// Original: 16 per tick → 80 px/s.
const double playerSpeedNormal = 16 * speedScale; // 80

/// Player speed mode 2 — running (default).
/// Original: 24 per tick → 120 px/s.
const double playerSpeedRunning = 24 * speedScale; // 120

/// Speed when in water or sinking.
/// Original: 6 per tick → 30 px/s.
const double playerSpeedWater = 6 * speedScale; // 30

// ---------------------------------------------------------------------------
// Enemy movement  (ENEMY_AI.md §6.1)
// ---------------------------------------------------------------------------

/// Maximum enemy movement speed (original cap: 26 → 130 px/s).
const double enemySpeedMax = 26 * speedScale; // 130

/// Enemy base speed offset (original: 12).
const int enemySpeedBase = 12;

// ---------------------------------------------------------------------------
// Detection ranges  (ENEMY_AI.md §5, PLAYER.md §3.1)
// ---------------------------------------------------------------------------

/// Enemy detection range (pixels). Beyond this, players are invisible.
const double detectionRange = 200;

/// Close-range threshold — enemies always engage, ignore LOS.
const double closeRange = 64;

/// Always-engage range — tighter threshold for guaranteed engagement.
const double alwaysEngageRange = 40;

/// Auto-fire detection range for non-selected player squads.
const double autoFireRange = 210;

// ---------------------------------------------------------------------------
// Combat timing
// ---------------------------------------------------------------------------

/// Post-fire pause for enemy bullets (original: 15 ticks).
const double enemyPostFirePauseBullet = 15 * tickDuration; // 0.9 s

/// Post-fire pause for enemy grenades (original: 12 ticks).
const double enemyPostFirePauseGrenade = 12 * tickDuration; // 0.72 s

/// Firing hold duration for player soldiers (seconds).
const double playerFiringHoldDuration = 0.3;

// ---------------------------------------------------------------------------
// Bullet defaults
// ---------------------------------------------------------------------------

/// Player bullet speed (pixels/second). Overridden by rank-based weapon data.
const double defaultPlayerBulletSpeed = 120 * speedScale; // 600

/// Maximum concurrent bullets per faction.
const int maxBulletsPerFaction = 20;

/// Enemy bullet spread (deviation) — fixed at 24 (original units).
const int enemyBulletSpread = 24;

// ---------------------------------------------------------------------------
// Dodge  (PLAYER.md §1.2)
// ---------------------------------------------------------------------------

/// Probability of dodging a bullet when moving (1 in N).
const int dodgeChanceOneIn = 8;

/// Minimum bullet proximity (ticks→distance) below which dodge is impossible.
/// Original: field_3A ≤ 4 means bullet has been alive ≤ 4 ticks.
const double dodgeMinBulletAge = 4 * tickDuration; // 0.24 s

// ---------------------------------------------------------------------------
// Squads  (PLAYER.md §4)
// ---------------------------------------------------------------------------

/// Maximum number of squads.
const int maxSquads = 3;

/// Maximum soldiers in a single squad.
const int maxSoldiersPerSquad = 8;

/// Maximum soldiers across all squads in one mission.
const int maxSoldiersPerMission = 9;

/// Maximum waypoints per squad.
const int maxWaypointsPerSquad = 30;

// ---------------------------------------------------------------------------
// Ammo  (PLAYER.md §4.2)
// ---------------------------------------------------------------------------

/// Grenades per soldier at mission start.
const int grenadesPerSoldier = 2;

/// Rockets per soldier at mission start.
const int rocketsPerSoldier = 1;

/// Grenades added by a grenade box pickup.
const int grenadeBoxAmount = 4;

/// Rockets added by a rocket box pickup.
const int rocketBoxAmount = 4;

// ---------------------------------------------------------------------------
// Rank  (PLAYER.md §5)
// ---------------------------------------------------------------------------

/// Maximum soldier rank.
const int maxRank = 15;

/// Total recruit pool size — game over when all are killed.
const int totalRecruits = 360;

// ---------------------------------------------------------------------------
// Death sequence
// ---------------------------------------------------------------------------

/// Death animation duration before fade-out starts (seconds).
const double deathAnimDuration = 0.5;

/// Fade-out duration after death animation (seconds).
const double deathFadeDuration = 0.5;

/// Phase completion delay after all objectives met (original: 100 ticks).
const double phaseCompletionDelay = 100 * tickDuration; // 6.0 s

// ---------------------------------------------------------------------------
// Sprite limits  (ENGINE.md §4)
// ---------------------------------------------------------------------------

/// Maximum sprites in the original engine. Used as a soft guideline.
const int maxSprites = 45;

/// Maximum enemies allowed on the map at once.
const int maxEnemiesOnMap = 10;

// ---------------------------------------------------------------------------
// Auto-fire  (PLAYER.md §3.1)
// ---------------------------------------------------------------------------

/// Chance per frame to skip auto-fire (1 in N).
const int autoFireIgnoreChanceOneIn = 32;
