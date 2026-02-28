# Fodder Remake - Game Design Document

## 1. Overview
A top-down/isometric tactical run-and-gun shoot 'em up. A modern remake targeting Mobile (Android/iOS) and Desktop (macOS/Windows) simultaneously, built with **Flutter + Flame**. We will use Flame's native component hierarchy, the FCS (Flame Component System).

## 2. Scope (Phase 1 MVP)
- **World:** Single tile-based map with traversable/impassable terrain.
- **Characters:** 1 controllable player soldier and immobile/basic patrolling enemies.
- **Movement:** Point-and-click pathfinding across the map.
- **Combat:** Basic directional shooting, bullet travel, and hit-detection.
- **Camera:** The camera actively tracks the player.

## 3. Controls & UX
**Desktop UX:**
- **Move:** Left-Click on the terrain.
- **Fire Weapon:** Right-Click (or hold) in a direction to spray bullets.

**Mobile Touch UX:**
- **Move:** Single Tap on the map.
- **Fire Weapon:** Tap-and-Hold (Long Press) or Drag on the screen. The soldier continuously fires towards that coordinate until released.

## 4. Technical Architecture
- **Engine:** Flutter + Flame.
- **Architecture:** Flame Component System (FCS).
- **Core Packages:** `flame`, `flame_tiled` (for rendering TMX maps).
- **Pathfinding:** 2D grid logic utilizing A* algorithm.
