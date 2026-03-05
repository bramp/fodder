# Cannon Fodder Audio Map

This document tracks the mapping of extracted `.VOC` audio files from the original game.

## Global Sounds (`ALL*.VOC`)

These sounds apply to all missions and are loaded into specific hex indices globally.

| Filename | Hex ID | Known Description | Reverse-Engineering Context / Notes |
| :--- | :--- | :--- | :--- |
| `ALL02.VOC` | `0x02` | **Tank Engine / Movement** | Triggers in `Sprite_Handle_Tank_Human` via `Sprite_Map_Sound_Play(Data0)` where Data0 = 2. |
| `ALL03.VOC` | `0x03` | *Unknown* | Still investigating. Possibly a UI element or another movement sound. |
| `ALL04.VOC` | `0x04` | **Helicopter Engine (Idle)** | Defined in `mSprite_Helicopter_Sounds` array. Used when choppers are low/idle. |
| `ALL05.VOC` | `0x05` | **Explosion** | Used inside `Sprite_Handle_Explosion` (`5 + mInterruptTick & 3`). |
| `ALL06.VOC` | `0x06` | **Explosion** | Used inside `Sprite_Handle_Explosion`. |
| `ALL07.VOC` | `0x07` | **Explosion** | Used inside `Sprite_Handle_Explosion`. |
| `ALL08.VOC` | `0x08` | **Explosion** | Used inside `Sprite_Handle_Explosion`. |
| `ALL09.VOC` | `0x09` | *Unknown* | Still investigating. |
| `ALL11.VOC` | `0x0B` | **Death Scream 1** | Mapped in `mSprite_Civilian_Sound_Death`. Used for soldiers and civilians. |
| `ALL12.VOC` | `0x0C` | **Death Scream 2** | Mapped in `mSprite_Civilian_Sound_Death`. Used for soldiers and civilians. |
| `ALL13.VOC` | `0x0D` | **Death Scream 3** | Mapped in `mSprite_Civilian_Sound_Death`. Used for soldiers and civilians. |
| `ALL15.VOC` | `0x0F` | **Grenade Explosion** | Mapped to `eSound_Effect_Grenade` enum (`0x0F`). Used in `Sprite_Handle_Explosion`/weapon hits. |
| `ALL16.VOC` | `0x10` | **Building Door / Low Gunshot** | Mapped to `eSound_Effect_BuildingDoor2` enum and randomly used for bullet impacts/shots (`Data4 = 0x10`). |
| `ALL17.VOC` | `0x11` | **Gunshot / Impact** | Randomly selected (`Data0 = tool_RandomGet() & 1`, giving `0x10` or `0x11`) when firing weapons. |
| `ALL18.VOC` | `0x12` | *Unknown* | Still investigating. |
| `ALL19.VOC` | `0x13` | *Unknown* | Still investigating. |
| `ALL20.VOC` | `0x14` | **Death Scream 4** | Mapped in `mSprite_Civilian_Sound_Death`. Used for soldiers and civilians. |
| `ALL21.VOC` | `0x15` | **Death Scream 5** | Mapped in `mSprite_Civilian_Sound_Death`. Used for soldiers and civilians. |
| `ALL22.VOC` | `0x16` | **Death Scream 6** | Mapped in `mSprite_Civilian_Sound_Death`. Used for soldiers and civilians. |
| `ALL46.VOC` | `0x2D` / `0x2E` | **Missile / Rocket Launch** | Mapped to `eSound_Effect_Missile_Launch` (`0x2D`) & `Rocket` (`0x2E`). |
| `ALL51.VOC` | `0x33` | **Helicopter Rotor / Fast** | Mapped in `mSprite_Helicopter_Sounds` for varying flight status. |
| `ALL52.VOC` | `0x34` | **Helicopter Rotor / Fast** | Mapped in `mSprite_Helicopter_Sounds` for varying flight status. |
| `ALL53.VOC` | `0x35` | **Helicopter Rotor / Fast** | Mapped in `mSprite_Helicopter_Sounds` for varying flight status. |
| `ALL54.VOC` | `0x36` | **Helicopter Rotor / Fast** | Mapped in `mSprite_Helicopter_Sounds` for varying flight status. |
| `ALL56.VOC` | `0x38` | **Jeep Engine / Speed 1** | Computed in `Sprite_Handle_Vehicle` (`Data0 += 0x38`) scaling with speed. |
| `ALL57.VOC` | `0x39` | **Jeep Engine / Speed 2** | Computed in `Sprite_Handle_Vehicle`. |
| `ALL58.VOC` | `0x3A` | **Jeep Engine / Speed 3** | Computed in `Sprite_Handle_Vehicle`. |
| `ALL59.VOC` | `0x3B` | **Jeep Engine / Speed 4** | Computed in `Sprite_Handle_Vehicle`. |

---

## Biome Specific Sounds

Loaded into the `0x00`-`0x04` tile maps conditionally depending on the current environment.

| Filename | Hex ID | Map Category | Known Description | Reverse-Engineering Context / Notes |
| :--- | :--- | :--- | :--- | :--- |
| `JUN26.VOC` | `0x1A` | Jungle (`0x00`) | **Bird Ambience** | Triggered randomly by environmental birds passing horizontally (`Sprite_Native_Sound_Play`). |
| `JUN27.VOC` | `0x1B` | Jungle (`0x00`) | *Unknown* | Likely generic jungle fauna ambiance. |
| `JUN28.VOC` | `0x1C` | Jungle (`0x00`) | *Unknown* | Likely generic jungle fauna ambiance. |
| `DES26.VOC` | `0x1A` | Desert (`0x01`) | **Desert Bird Ambience** | Triggered randomly by environmental birds. |
| `ICE26.VOC` | `0x1A` | Ice (`0x02`) | **Ice Bird Ambience** | Triggered randomly by environmental birds. |
| `ICE30.VOC` | `0x1E` | Ice (`0x02`) | **Seal / Footsteps** | `Sprite_Native_Sound_Play` calls `0x1E` on Ice/AFX maps (Seals). |
| `ICE31.VOC` | `0x1F` | Ice (`0x02`) | **Ice Ambience / Bird variation** | Triggered repeatedly on Ice tile sets at `13102`. |
| `MOR26.VOC` | `0x1A` | Moor (`0x03`) | **Moor Bird Ambience** | Triggered randomly by environmental birds. |
| `MOR28.VOC` | `0x1C` | Moor (`0x03`) | *Unknown* | Likely Moor fauna ambiance (like Sheep?). |
| `INT26.VOC` | `0x1A` | Interior (`0x04`) | **Interior Bird Ambience?** | Found at index `0x1A` similar to the bird calls. Possibly echoes or drips. |

## Unidentified Sounds

The following `.VOC` files have been extracted but their exact usage in the source code has not yet been fully identified. Continuing to trace their Hex IDs or looking for missing mappings might reveal their purpose:

- `ALL03.VOC` (Hex ID: `0x03`)
- `ALL09.VOC` (Hex ID: `0x09`)
- `ALL18.VOC` (Hex ID: `0x12`)
- `ALL19.VOC` (Hex ID: `0x13`)
- `JUN27.VOC` (Hex ID: `0x1B`, Jungle)
- `JUN28.VOC` (Hex ID: `0x1C`, Jungle)
- `MOR28.VOC` (Hex ID: `0x1C`, Moor)
