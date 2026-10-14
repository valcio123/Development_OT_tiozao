# Creature and economy rebalance

Startup switch: `rebalanceSystemEnabled = true/false` in `config.lua`.
The same settings are published in `config.lua.dist`. Restart to toggle; do not
partially reload NPCs/monsters to switch a live world. Independent of modernCombatSystem.
This Lua policy reads the standard `config.lua` once (custom CLI config paths are
not supported by this policy).

| Setting | Enabled | Disabled |
| --- | --- | --- |
| All monster/boss attacks | base configured attack rate x1.30 | base configured rate |
| Health/max health of post-7.6 types | definition x1.20, nearest integer | original definition |
| Post-7.6 invisibility detection | condition immunity enabled | original immunity |
| Central loot rolls incl. bonuses/rewards | base factor x0.80 | original factor |
| Ordinary mana potion (268) | NPC buy price 100 gp | original NPC buy price |

Damage uses existing native rates, including bosses; it does not increase monster
healing or change attack intervals/chances. Attached condition.totalDamage (poison/bleed) is additionally scaled at registration. Shared ground field item ticks are unchanged; they are not monster direct attack values. Lua scripted spells should continue
using the engine's monster attack multiplier; scripts with fixed/direct damage
outside that engine path require a separate audit.
Loot reduction affects drop chance; it is not a promise that each individual
corpse/session will contain exactly 20% fewer items. Keep rateLoot=1 for 0.8x base.
Products, equipment and coins all use the central roll; existing loot bonuses remain.
Shop registration overrides parent/child catalogs and dynamic hirelings without
rewriting original catalogs, so false restores original prices after restart.

Historical cutoff is explicit and auditable in
`data/libs/functions/rebalance_legacy_creatures.lua`: Nostalrius 7.72 names,
excluding Morgaroth (post-7.6), plus Cat/Human and renamed Bonelord/Hyena aliases.
Unknown/custom names and modern variants default to modern. A definition can
declare `introducedVersion = 7.6` to override classification; add verified old
names to the catalog. Sprites, race IDs and appearances are never used as dates.
Reference: https://github.com/Ezzz-dev/Nostalrius/blob/master/data/monster/monsters.xml

No commit or automatic server restart is part of installation. In-game validation
must check attack, HP, invisibility, loot over many kills and NPC prices, in both modes.
## Rookgaard species exemption

Species in data/libs/functions/rebalance_rookgaard_creatures.lua are exempt worldwide, including Troll Champion, quest creatures and seasonal bosses. Their direct damage uses the base configured native rate; attached conditions, health, invisibility immunity and central loot keep original definitions. Other types remain rebalanced. Exact-name matching prevents exemptions leaking to unrelated variants. Restart with the rebuilt executable; no commit before gameplay testing.
