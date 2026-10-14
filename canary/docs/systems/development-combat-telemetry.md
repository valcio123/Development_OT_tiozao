# Development combat telemetry

The server can collect structured combat events for balancing in either combat
mode. This is diagnostic collection, not a general audit of chat, movement,
trading or all database changes. Production defaults to disabled.

## Configuration

In `config.lua`, before a controlled restart:

```lua
combatTelemetryEnabled = true
combatTelemetryPlayers = "" -- all players, or "Knight Sample,Sorcerer Sample"
```

The filter is a comma-separated list of exact character names. Player-versus-
monster and player-versus-player events are recorded when either participant
matches. Monster-only combat is excluded. Configuration is startup-only.
Set `combatTelemetryEnabled = false` and restart to disable collection.

## Files and lifetime

Output: `logs/combat-telemetry/events.jsonl`, relative to the Canary working
directory. Each line is a JSON event. The sink rotates at 16 MiB and retains
five previous files (approximately 96 MiB total). Copy sessions elsewhere
before rotation discards them. Files remain local and must be ignored by Git.

The sink is owned by Game, uses buffered synchronous writes, flushes at the
end of item/spell use and on destruction, and has no gameplay callbacks or
background worker. Collection has overhead and is intended for development.
Storage errors cannot alter combat; file initialization errors disable the
collector for that process and report an error in the server log. A forced
process termination can lose the last buffered events.

## Event semantics

- `action_start` / `action_end`: attempts to cast instant spells or use runes
  and items, including rejected attempts that reach these execution handlers.
  Each action has an ID; nested rune use links to its parent item action.
  The result reports success/failure, not a precise rejection reason.
- `damage` / `heal`: actual health delta after applying the hit or heal.
  Overkill and overheal are capped to the actual health change.
- `blocked`: damage blocked in the central combat health path, with zero
  applied damage. This is not a comprehensive record of every immunity,
  range/PZ rejection or cancelled event.
- `health_change`: actual player health mutations, including direct regeneration.
  These overlap with `damage`/`heal`; do not sum both for combat totals.
- `mana_change`: actual player mana mutations, including consumption,
  restoration, regeneration and drain. Zero changes are omitted.
- `mana_restore`, `mana_drain`, `mana_shield`: attributed combat mana outcomes.
  These overlap with `mana_change`; do not add both when calculating totals.

Events include wall-clock and monotonic milliseconds, server run ID, combat
mode, participants, character GUID, vocation, level, current/base ML, effective
weapon skills, weapon ID/attack, position, health/mana and maximum pools.
Impact events include source spell/rune name when supplied by combat, origin,
critical/extension flags and damage components at the recording point.
Components are not the original formula roll; use `health_delta` for actual
damage. IDs and names never include account credentials or network addresses.

Synchronous hits link to the action ID. Delayed effects and condition ticks
can have action ID zero; a source name may still be available, but attribution
to a particular earlier cast is not guaranteed. Neither reconnecting nor
switching profiles resets the file: run IDs distinguish server restarts.

## Export

From the Canary directory, after saving/closing a test session:

```powershell
python tools/combat_telemetry_report.py --duration 120
```

Uses only Python's standard library. Reads active and rotated JSONL files,
selects the newest run by default, and exports `logs/combat-telemetry/report.csv`.
`--run <run_id>` selects an earlier retained run; `--output <path>` chooses an
export path. Rows group character, vocation, level, ML, highest melee skill,
distance skill and action. Parent item actions that also executed a rune are
not counted as duplicate cast attempts.

The CSV contains attempts/successes, per-target hits, blocks, damage minimum,
maximum and mean, damage/healing totals, mana spent/restored during actions,
test duration and DPS. Summing per-target hits measures total area damage;
compare equal targets/resistances and target counts. Separate `unlinked` rows
can contain auto-attacks/conditions and delayed damage.

Supply the complete measured test duration, including mana refill and idle
time, to compare sustained DPS. Without `--duration`, DPS uses the span of all
events in the selected server run, which can include unrelated sessions.
For isolated balance tests use one character/session and save the log before
the next experiment. The exporter does not reconstruct base formula damage,
automatically infer hunts or compensate for different monsters/equipment.
