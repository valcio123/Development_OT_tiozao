/**
 * Canary - A free and open-source MMORPG server emulator
 * Copyright (©) 2019–present OpenTibiaBR <opentibiabr@outlook.com>
 * Repository: https://github.com/opentibiabr/canary
 * License: https://github.com/opentibiabr/canary/blob/main/LICENSE
 */

#include "creatures/combat/combat_mode.hpp"

#ifdef COMBAT_MODE_STANDALONE
	#include <cassert>
	#define MODE_TEST(name) void name()
	#define MODE_EXPECT(value) assert(value)
#else
	#include <gtest/gtest.h>
	#define MODE_TEST(name) TEST(CombatModeTest, name)
	#define MODE_EXPECT(value) EXPECT_TRUE(value)
#endif

MODE_TEST(ModernRestoresEveryItemAndVocation) {
	for (uint32_t id = 0; id <= UINT16_MAX; ++id) {
		MODE_EXPECT(CombatMode::isItemAvailable(true, static_cast<uint16_t>(id)));
		MODE_EXPECT(CombatMode::isVocationAvailable(true, static_cast<uint16_t>(id)));
	}
	MODE_EXPECT(CombatMode::isSpellAvailable(true, "future spell"));
}

MODE_TEST(TraditionalPreservesOrdinaryManaAndFood) {
	MODE_EXPECT(CombatMode::isItemAvailable(false, 268));
	MODE_EXPECT(CombatMode::isItemAvailable(false, 3582)); // ham
	MODE_EXPECT(CombatMode::isItemAvailable(false, 3600)); // bread
	MODE_EXPECT(!CombatMode::isItemAvailable(false, 266));
	MODE_EXPECT(!CombatMode::isItemAvailable(false, 237));
	MODE_EXPECT(!CombatMode::isItemAvailable(false, 7642));
	MODE_EXPECT(!CombatMode::isItemAvailable(false, 23373));
	MODE_EXPECT(!CombatMode::isItemAvailable(false, 9079));
	MODE_EXPECT(!CombatMode::isItemAvailable(false, 29414));
	MODE_EXPECT(!CombatMode::isItemAvailable(false, 29415));
}

MODE_TEST(TraditionalRunesAreIndependentOfParalyzeWalking) {
	MODE_EXPECT(CombatMode::traditionalCooldown(true) == 1000);
	MODE_EXPECT(CombatMode::traditionalCooldown(false) == 2000);
	MODE_EXPECT(!CombatMode::requiresWalkExhaustion(false, true, true));
	MODE_EXPECT(CombatMode::requiresWalkExhaustion(true, true, true));
	MODE_EXPECT(CombatMode::requiresWalkExhaustion(false, false, true));
	MODE_EXPECT(CombatMode::requiresWalkExhaustion(true, false, true));
	MODE_EXPECT(!CombatMode::requiresWalkExhaustion(false, false, false));
	MODE_EXPECT(!CombatMode::requiresWalkExhaustion(true, false, false));
}

MODE_TEST(GreatFireballRemainsAvailableInBothModes) {
	MODE_EXPECT(CombatMode::isItemAvailable(false, 3191));
	MODE_EXPECT(CombatMode::isItemAvailable(true, 3191));
	MODE_EXPECT(CombatMode::isSpellAvailable(false, "great fireball rune"));
	MODE_EXPECT(CombatMode::isSpellAvailable(true, "great fireball rune"));
}

MODE_TEST(TraditionalRejectsBothMonkVocationsOnly) {
	for (uint16_t id = 0; id <= 10; ++id) {
		MODE_EXPECT(CombatMode::isVocationAvailable(false, id) == (id != 9 && id != 10));
	}
}

MODE_TEST(AvailabilityHasNoSubstringOrCaseEscape) {
	MODE_EXPECT(CombatMode::isSpellAvailable(false, "Ultimate Healing"));
	MODE_EXPECT(CombatMode::isSpellAvailable(false, "ULTIMATE HEALING RUNE"));
	MODE_EXPECT(CombatMode::isSpellAvailable(false, "Magic Wall Rune"));
	MODE_EXPECT(CombatMode::isSpellAvailable(false, "Fire Wave"));
	MODE_EXPECT(!CombatMode::isSpellAvailable(false, "Ultimate Healing Extra"));
	MODE_EXPECT(!CombatMode::isSpellAvailable(false, "Restoration"));
	MODE_EXPECT(CombatMode::isSpellAvailable(false, "Avalanche Rune"));
	MODE_EXPECT(CombatMode::isSpellAvailable(false, "Thunderstorm Rune"));
	MODE_EXPECT(!CombatMode::isSpellAvailable(false, "Swift Jab"));
	MODE_EXPECT(!CombatMode::isSpellAvailable(false, ""));
	MODE_EXPECT(CombatMode::traditionalCooldownMs == 2000);
}

#ifdef COMBAT_MODE_STANDALONE
int main() {
	ModernRestoresEveryItemAndVocation();
	TraditionalPreservesOrdinaryManaAndFood();
	TraditionalRunesAreIndependentOfParalyzeWalking();
	GreatFireballRemainsAvailableInBothModes();
	TraditionalRejectsBothMonkVocationsOnly();
	AvailabilityHasNoSubstringOrCaseEscape();
}
#endif
