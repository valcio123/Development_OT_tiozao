/**
 * Canary - A free and open-source MMORPG server emulator
 * Copyright (©) 2019–present OpenTibiaBR <opentibiabr@outlook.com>
 * Repository: https://github.com/opentibiabr/canary
 * License: https://github.com/opentibiabr/canary/blob/main/LICENSE
 */

#include "creatures/combat/combat_telemetry.hpp"
#include "config/configmanager.hpp"
#include "creatures/creature.hpp"
#include "creatures/players/player.hpp"
#include "items/item.hpp"
#include "lib/logging/log_with_spd_log.hpp"
#include <spdlog/sinks/rotating_file_sink.h>
#include <spdlog/logger.h>
#include <nlohmann/json.hpp>
#ifndef USE_PRECOMPILED_HEADERS
#include <algorithm>
#include <chrono>
#include <filesystem>
#include <sstream>
#endif

namespace {
	thread_local uint64_t telemetryActionId = 0;
	int64_t telemetryEpochMs() {
		return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count();
	}
	nlohmann::json telemetryCreature(const std::shared_ptr<Creature> &creature) {
		if (!creature) { return nullptr; }
		const auto pos = creature->getPosition();
		nlohmann::json result = {{"id", creature->getID()}, {"name", creature->getName()}, {"kind", creature->getPlayer() ? "player" : (creature->getMonster() ? "monster" : "other")}, {"health", creature->getHealth()}, {"mana", creature->getMana()}, {"position", {pos.x, pos.y, pos.z}}};
		if (const auto player = creature->getPlayer()) {
			result["guid"] = player->getGUID();
			result["vocation"] = player->getVocationId();
			result["level"] = player->getLevel();
			result["magic_level"] = player->getMagicLevel();
			result["base_magic_level"] = player->getBaseMagicLevel();
			result["skills"] = {{"sword", player->getSkillLevel(SKILL_SWORD)}, {"axe", player->getSkillLevel(SKILL_AXE)}, {"club", player->getSkillLevel(SKILL_CLUB)}, {"distance", player->getSkillLevel(SKILL_DISTANCE)}};
			result["max_health"] = player->getMaxHealth();
			result["max_mana"] = player->getMaxMana();
			if (const auto weapon = player->getWeapon()) {
				result["weapon"] = {{"id", weapon->getID()}, {"attack", weapon->getAttack()}};
			}
		}
		return result;
	}
}

CombatTelemetry::~CombatTelemetry() { flush(); }

bool CombatTelemetry::accepts(const std::shared_ptr<Creature> &first, const std::shared_ptr<Creature> &second) const {
	if (failed_.load(std::memory_order_relaxed) || !g_configManager().getBoolean(COMBAT_TELEMETRY_ENABLED)) { return false; }
	const auto &filter = g_configManager().getString(COMBAT_TELEMETRY_PLAYERS);
	for (const auto &creature : {first, second}) {
		if (!creature || !creature->getPlayer()) { continue; }
		if (filter.empty()) { return true; }
		std::istringstream names(filter);
		std::string name;
		while (std::getline(names, name, ',')) {
			const auto begin = name.find_first_not_of(" \t");
			if (begin == std::string::npos) { continue; }
			name = name.substr(begin, name.find_last_not_of(" \t") - begin + 1);
			if (name == creature->getName()) { return true; }
		}
	}
	return false;
}

void CombatTelemetry::emit(nlohmann::json event) noexcept {
	try {
		std::lock_guard lock(mutex_);
		if (failed_) { return; }
		if (!logger_) {
			std::filesystem::create_directories("logs/combat-telemetry");
			runId_ = std::to_string(telemetryEpochMs());
			auto sink = std::make_shared<spdlog::sinks::rotating_file_sink_mt>("logs/combat-telemetry/events.jsonl", 16 * 1024 * 1024, 5);
			logger_ = std::make_shared<spdlog::logger>("combat-telemetry", sink);
			logger_->set_pattern("%v");
		}
		event["schema"] = 1;
		event["run_id"] = runId_;
		event["timestamp_ms"] = telemetryEpochMs();
		event["monotonic_ms"] = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now().time_since_epoch()).count();
		event["mode"] = g_configManager().getBoolean(MODERN_COMBAT_SYSTEM) ? "modern" : "traditional";
		logger_->info("{}", event.dump());
	} catch (...) {
		// Telemetry must never reject or modify gameplay if storage fails.
		if (!failed_.exchange(true)) {
			try { g_logger().error("Combat telemetry disabled for this process: failed to write logs/combat-telemetry/events.jsonl"); } catch (...) {}
		}
	}
}

void CombatTelemetry::flush() noexcept {
	try { std::lock_guard lock(mutex_); if (logger_) { logger_->flush(); } } catch (...) {}
}

void CombatTelemetry::impact(const char *event, const std::shared_ptr<Creature> &attacker, const std::shared_ptr<Creature> &target, const CombatDamage &damage, int32_t healthDelta, int32_t manaDelta) noexcept {
	try {
		if (!accepts(attacker, target)) { return; }
		emit({{"event", event}, {"action_id", telemetryActionId}, {"attacker", telemetryCreature(attacker)}, {"target", telemetryCreature(target)}, {"spell", damage.instantSpellName}, {"rune", damage.runeSpellName}, {"origin", static_cast<int>(damage.origin)}, {"health_delta", healthDelta}, {"mana_delta", manaDelta}, {"primary_type", static_cast<int>(damage.primary.type)}, {"primary_value", damage.primary.value}, {"secondary_type", static_cast<int>(damage.secondary.type)}, {"secondary_value", damage.secondary.value}, {"critical", damage.critical}, {"extension", damage.extension}});
	} catch (...) {}
}

void CombatTelemetry::health(const std::shared_ptr<Creature> &target, int32_t before, int32_t after) noexcept {
	try {
		if (before == after || !accepts(target)) { return; }
		emit({{"event", "health_change"}, {"action_id", telemetryActionId}, {"player", telemetryCreature(target)}, {"before", before}, {"after", after}, {"delta", after-before}});
	} catch (...) {}
}

void CombatTelemetry::mana(const std::shared_ptr<Creature> &target, int32_t before, int32_t after) noexcept {
	try {
		if (before == after || !accepts(target)) { return; }
		emit({{"event", "mana_change"}, {"action_id", telemetryActionId}, {"player", telemetryCreature(target)}, {"before", before}, {"after", after}, {"delta", after-before}});
	} catch (...) {}
}

CombatTelemetry::Scope::Scope(CombatTelemetry &owner, const std::shared_ptr<Player> &player, const std::string &name, const char *kind, uint16_t spellId, uint16_t itemId, uint32_t manaCost) noexcept : owner_(owner) {
	try {
		if (!owner.accepts(player)) { return; }
		player_ = player;
		previous_ = telemetryActionId;
		id_ = owner.nextId_.fetch_add(1, std::memory_order_relaxed);
		telemetryActionId = id_;
		owner.emit({{"event", "action_start"}, {"action_id", id_}, {"parent_action_id", previous_}, {"player", telemetryCreature(player)}, {"name", name}, {"kind", kind}, {"spell_id", spellId}, {"item_id", itemId}, {"required_mana", manaCost}});
	} catch (...) {}
}

CombatTelemetry::Scope::~Scope() {
	if (!id_) { return; }
	try {
		owner_.emit({{"event", "action_end"}, {"action_id", id_}, {"success", success_}, {"player", telemetryCreature(player_.lock())}});
		owner_.flush();
	} catch (...) {}
	telemetryActionId = previous_;
}
