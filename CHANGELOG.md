# Changelog

## v1.0.2 – Risk calculation fixes & gameplay accuracy

### Fixed
- Fixed incorrect risk penalty for Warriors out of combat.
  - Rage is no longer treated as a missing resource before engagement.
  - Warriors no longer gain artificial risk when starting combat with 0 rage.

### Improved
- Resource-based risk calculation refined for pre-combat evaluation:
  - Mana is checked only for mana-based classes.
  - Energy is checked for Rogues.
  - Rage (Warrior) and Focus (Hunter) are intentionally ignored outside combat.

### Notes
- HC Risk Tracker evaluates danger before engaging combat,
  and continuously updates risk dynamically during combat.

---

## v1.0.1

### Fixed
- Repository structure adjusted to match CurseForge packager requirements
- Automated releases via GitHub Actions now work correctly

_No gameplay or functional changes._

--- 

## v1.0 – Initial release

### Features
- Initial release of HC Risk Tracker.
- Real-time risk indicator based on player state and environment.
- Nearby hostile threat scanning.
- Elite and dangerous environment detection (indoors, caves).
- Essential buff checks by class.
- Missing pet detection (Hunter / Warlock).
- Missing poison detection (Rogue, after learning the "Poisons" skill).
- Automatic FR / EN localization
- No chat spam (alerts only at high risk)

### Interface
- Risk bar with threat counter.
- Tooltip displaying detailed risk information.
- Movable and lockable frame with saved position.

### Notes
- Designed for Hardcore gameplay.
- No sounds, no blinking, no intrusive alerts.