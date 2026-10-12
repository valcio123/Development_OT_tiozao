/**
 * Canary - A free and open-source MMORPG server emulator
 * Copyright (©) 2019–present OpenTibiaBR <opentibiabr@outlook.com>
 * Repository: https://github.com/opentibiabr/canary
 * License: https://github.com/opentibiabr/canary/blob/main/LICENSE
 */

#pragma once

#include <cstddef>
#include <cstdint>
#include <string_view>

// Pure policy: callers read MODERN_COMBAT_SYSTEM from ConfigManager.
// Audit and historical aliases: docs/systems/traditional-combat.md.
namespace CombatMode {

inline constexpr uint32_t traditionalCooldownMs = 2000;

constexpr bool sameSpellName(std::string_view left, std::string_view right) {
	if (left.size() != right.size()) {
		return false;
	}
	for (std::size_t i = 0; i < left.size(); ++i) {
		const char ch = left[i] >= 'A' && left[i] <= 'Z' ? left[i] + ('a' - 'A') : left[i];
		if (ch != right[i]) {
			return false;
		}
	}
	return true;
}

constexpr bool isSpellAvailable(bool modern, std::string_view name) {
	if (modern) {
		return true;
	}
	constexpr std::string_view allowed[] = {
		"light healing", "intense healing", "ultimate healing", "heal friend", "mass healing", "cure poison",
		"light", "great light", "ultimate light", "magic rope", "levitate", "find person", "food",
		"magic shield", "haste", "strong haste", "invisibility", "cancel invisibility", "creature illusion", "summon creature",
		"berserk", "challenge", "fire wave", "energy wave", "energy beam", "great energy beam", "flame strike", "energy strike",
		"conjure arrow", "conjure poisoned arrow", "conjure explosive arrow", "conjure bolt", "conjure power bolt", "enchant staff",
		"house guest list", "house subowner list", "house door list", "house kick",
		"antidote rune", "cure poison rune", "intense healing rune", "ultimate healing rune",
		"light magic missile rune", "heavy magic missile rune", "fireball rune", "great fireball rune", "explosion rune", "sudden death rune",
		"poison field rune", "poison bomb rune", "poison wall rune", "fire field rune", "fire bomb rune", "fire wall rune",
		"energy field rune", "energybomb rune", "energy bomb rune", "energy wall rune", "soulfire rune",
		"animate dead rune", "convince creature rune", "chameleon rune", "destroy field rune", "desintegrate rune", "disintegrate rune",
		"magic wall rune", "paralyze rune",
	};
	for (auto candidate : allowed) {
		if (sameSpellName(name, candidate)) {
			return true;
		}
	}
	return false;
}

constexpr bool isVocationAvailable(bool modern, uint16_t vocationId) {
	return modern || (vocationId != 9 && vocationId != 10);
}

constexpr bool isItemAvailable(bool modern, uint16_t itemId) {
	if (modern) {
		return true;
	}
	// Healing/mixed potions, upgraded mana potions and their random dispenser.
	// Ordinary mana potion (268) has only the existing item exhaustion.
	switch (itemId) {
		case 236: case 237: case 238: case 239: case 266: case 6558:
		case 7642: case 7643: case 7876: case 23373: case 23374: case 23375:
		// Instant health/mana recovery foods (including hireling dishes).
		case 9079: case 9086: case 11586: case 11587:
		case 28484: case 28485: case 29414: case 29415:
			return false;
		default:
			return true;
	}
}

} // namespace CombatMode
