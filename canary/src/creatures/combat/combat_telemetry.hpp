/**
 * Canary - A free and open-source MMORPG server emulator
 * Copyright (©) 2019–present OpenTibiaBR <opentibiabr@outlook.com>
 * Repository: https://github.com/opentibiabr/canary
 * License: https://github.com/opentibiabr/canary/blob/main/LICENSE
 */

#pragma once

#ifndef USE_PRECOMPILED_HEADERS
#include <atomic>
#include <cstdint>
#include <memory>
#include <mutex>
#include <string>
#endif
#include <nlohmann/json_fwd.hpp>

class Creature;
class Player;
struct CombatDamage;
namespace spdlog { class logger; }

// Owned by Game; stores serialized values only, never gameplay object pointers.
class CombatTelemetry {
public:
	CombatTelemetry() = default;
	~CombatTelemetry();
	bool accepts(const std::shared_ptr<Creature> &first, const std::shared_ptr<Creature> &second = nullptr) const;
	void impact(const char *event, const std::shared_ptr<Creature> &attacker, const std::shared_ptr<Creature> &target, const CombatDamage &damage, int32_t healthDelta, int32_t manaDelta) noexcept;
	void health(const std::shared_ptr<Creature> &target, int32_t before, int32_t after) noexcept;
	void mana(const std::shared_ptr<Creature> &target, int32_t before, int32_t after) noexcept;
	void flush() noexcept;

	class Scope {
	public:
		Scope(CombatTelemetry &owner, const std::shared_ptr<Player> &player, const std::string &name, const char *kind, uint16_t spellId, uint16_t itemId, uint32_t manaCost) noexcept;
		~Scope();
		Scope(const Scope &) = delete;
		Scope &operator=(const Scope &) = delete;
		Scope(Scope &&) = delete;
		Scope &operator=(Scope &&) = delete;
		void finish(bool success) { success_ = success; }
	private:
		CombatTelemetry &owner_;
		std::weak_ptr<Player> player_;
		uint64_t id_ = 0, previous_ = 0;
		bool success_ = false;
	};

private:
	void emit(nlohmann::json event) noexcept;
	std::mutex mutex_;
	std::shared_ptr<spdlog::logger> logger_;
	std::atomic<uint64_t> nextId_ { 1 };
	std::string runId_;
	std::atomic_bool failed_ { false };
};
