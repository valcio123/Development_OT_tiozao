# Canary local changes

Follow the user's Canary guidance in `../../.agents/pipeline/Agents_valcio.md`.

## Combat mode invariants

- Do not replace registered spell cooldowns or delete NPC catalogs to implement a mode switch. Preserve modern definitions and apply the traditional policy at execution and presentation boundaries.
- Do not implement mode restrictions only in individual Lua scripts: direct item use, hotkeys, NPC transactions and exposed spell lists must use the central policy.
- Validate both modes, cross-group spell/rune exhaustion, ordinary mana/food, both Monk vocations, and restoration of the original definitions. Cooldown reductions must never bypass the traditional shared interval.
- Treat `modernCombatSystem` as startup-only. Keep characters and account lists intact; reject unsupported world login before full gameplay loading.

- Repeated blocked item attempts must not refresh an on-screen warning indefinitely. Identify the item by name/ID and deduplicate notices for the Player lifetime while rejecting every attempt.
