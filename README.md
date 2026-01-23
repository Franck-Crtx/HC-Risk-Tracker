# HC Risk Tracker

HC Risk Tracker is a lightweight addon designed for **World of Warcraft Hardcore**.

It provides a **real-time risk indicator** that continuously evaluates danger based on your character state, nearby threats, and the surrounding environment — both **before engaging combat** and **dynamically during combat**.

## What the addon evaluates
- Player **health** and relevant **resources**
- Missing **essential buffs** by class
- Missing **pet** (Hunter / Warlock)
- Missing **poisons** (Rogue, after learning the "Poisons" skill)
- Nearby **hostile threats** and enemy density
- **Elites** and dangerous environments (indoors, caves)

> Resource handling is class-aware:
> - Mana and Energy are evaluated when relevant
> - Rage (Warrior) and Focus (Hunter) are intentionally ignored outside combat

---

## Features
- Clean **risk bar** with a **threat counter**
- Informative **tooltip** with detailed scan information
- **No chat spam** (alerts only at high risk levels)
- **Drag & lock** position with saved placement
- Automatic **FR / EN localization**
- Hardcore-friendly design:
  - No sounds
  - No blinking
  - No intrusive UI

---

## Commands
/hcrt lock
/hcrt unlock
/hcrt reset

---

## Designed for Hardcore
HC Risk Tracker focuses on **decision-making and awareness**, not panic.

It helps you read a situation, understand why a zone is dangerous,
and make better choices — without playing the game for you.