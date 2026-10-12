<?php
// Repositório de personagens (leitura/escrita em players e player_items).

if (!function_exists('insert_character_row')) {
    // Cria a linha do personagem copiando o sample. Deve ser chamada dentro de transação.
    function insert_character_row(PDO $pdo, int $accountId, int $sampleId, string $charName, int $sex, int $created): int
    {
        $sql = 'INSERT INTO players (name, account_id, group_id, sex, vocation, level, experience, '
            . 'health, healthmax, mana, manamax, manaspent, maglevel, soul, cap, town_id, '
            . 'posx, posy, posz, conditions, looktype, lookhead, lookbody, looklegs, lookfeet, '
            . 'lookaddons, stamina, skill_fist, skill_club, skill_sword, skill_axe, skill_dist, '
            . 'skill_shielding, skill_fishing, balance, created) '
            . 'SELECT ?, ?, 1, ?, vocation, level, experience, health, healthmax, mana, manamax, '
            . 'manaspent, maglevel, soul, cap, town_id, 0, 0, 0, conditions, '
            . 'CASE WHEN ? = 0 THEN 136 ELSE looktype END, lookhead, lookbody, looklegs, lookfeet, '
            . 'lookaddons, stamina, skill_fist, skill_club, skill_sword, skill_axe, skill_dist, '
            . 'skill_shielding, skill_fishing, 0, ? FROM players WHERE id = ?';
        $stmt = $pdo->prepare($sql);
        $stmt->execute([$charName, $accountId, $sex, $sex, $created, $sampleId]);

        if ($stmt->rowCount() !== 1) {
            throw new RuntimeException('insert_character_row: nenhuma linha copiada do sample');
        }

        $playerId = (int)$pdo->lastInsertId();

        $stmt = $pdo->prepare('INSERT INTO player_items (player_id, pid, sid, itemtype, count, attributes) '
            . 'SELECT ?, pid, sid, itemtype, count, attributes FROM player_items WHERE player_id = ?');
        $stmt->execute([$playerId, $sampleId]);

        return $playerId;
    }
}

if (!function_exists('find_sample_id')) {
    function find_sample_id(PDO $pdo, string $sampleName): ?int
    {
        $stmt = $pdo->prepare('SELECT id FROM players WHERE name = ? LIMIT 1');
        $stmt->execute([$sampleName]);
        $row = $stmt->fetch();
        return $row ? (int)$row['id'] : null;
    }
}

if (!function_exists('create_character')) {
    /**
     * Cria um personagem adicional para uma conta existente.
     * @return array{ok:bool,field:?string,error:?string,name:?string}
     */
    function create_character(int $accountId, string $charName, int $vocation, int $sex): array
    {
        $samples = (array)config('samples', []);
        if (!isset($samples[$vocation])) {
            app_log('ERROR', 'vocação sem sample', ['vocation' => $vocation]);
            return ['ok' => false, 'field' => 'vocation', 'error' => 'Escolha uma vocação válida.'];
        }
        $sampleName = (string)$samples[$vocation];

        $pdo = db();
        $pdo->beginTransaction();
        try {
            $stmt = $pdo->prepare('SELECT COUNT(*) FROM players WHERE account_id = ? FOR UPDATE');
            $stmt->execute([$accountId]);
            $count = (int)$stmt->fetchColumn();
            if ($count >= (int)config('max_characters', 10)) {
                $pdo->rollBack();
                return ['ok' => false, 'field' => null, 'error' => 'Limite de ' . (int)config('max_characters', 10) . ' personagens por conta atingido.'];
            }

            $stmt = $pdo->prepare('SELECT 1 FROM players WHERE name = ? LIMIT 1');
            $stmt->execute([$charName]);
            if ($stmt->fetchColumn()) {
                $pdo->rollBack();
                return ['ok' => false, 'field' => 'name', 'error' => 'Este nome já está em uso.'];
            }

            $sampleId = find_sample_id($pdo, $sampleName);
            if ($sampleId === null) {
                $pdo->rollBack();
                app_log('ERROR', 'sample ausente', ['sample' => $sampleName]);
                return ['ok' => false, 'field' => null, 'error' => 'Não foi possível criar o personagem agora. Tente mais tarde.'];
            }

            insert_character_row($pdo, $accountId, $sampleId, $charName, $sex, time());
            $pdo->commit();
            return ['ok' => true, 'field' => null, 'error' => null, 'name' => $charName];
        } catch (PDOException $e) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            if (is_unique_violation($e)) {
                return ['ok' => false, 'field' => 'name', 'error' => 'Este nome já está em uso.'];
            }
            app_log('ERROR', 'create_character falhou', ['code' => $e->getCode(), 'msg' => $e->getMessage()]);
            return ['ok' => false, 'field' => null, 'error' => 'Não foi possível criar o personagem agora. Tente mais tarde.'];
        }
    }
}

if (!function_exists('characters_of')) {
    function characters_of(int $accountId): array
    {
        $sql = 'SELECT p.name, p.vocation, p.level, (o.player_id IS NOT NULL) AS online '
            . 'FROM players p LEFT JOIN players_online o ON o.player_id = p.id '
            . 'WHERE p.account_id = ? AND p.deletion = 0 ORDER BY p.name ASC';
        $stmt = db()->prepare($sql);
        $stmt->execute([$accountId]);
        return $stmt->fetchAll();
    }
}

if (!function_exists('count_characters')) {
    function count_characters(int $accountId): int
    {
        $stmt = db()->prepare('SELECT COUNT(*) FROM players WHERE account_id = ? AND deletion = 0');
        $stmt->execute([$accountId]);
        return (int)$stmt->fetchColumn();
    }
}

if (!function_exists('ranking')) {
    function ranking(string $skill, int $limit): array
    {
        [$col, $tie] = skill_columns($skill);
        $sql = "SELECT name, vocation, level, {$col} AS value FROM players "
            . "WHERE group_id < 4 AND deletion = 0 AND name NOT LIKE '% Sample' "
            . "ORDER BY {$col} DESC, {$tie} DESC, name ASC LIMIT ?";
        $stmt = db()->prepare($sql);
        $stmt->bindValue(1, $limit, PDO::PARAM_INT);
        $stmt->execute();
        return $stmt->fetchAll();
    }
}

if (!function_exists('top_level')) {
    function top_level(int $limit): array
    {
        return ranking('level', $limit);
    }
}

if (!function_exists('online_players')) {
    function online_players(): array
    {
        $sql = 'SELECT p.name, p.vocation, p.level FROM players_online o '
            . 'JOIN players p ON p.id = o.player_id ORDER BY p.level DESC, p.name ASC';
        return db()->query($sql)->fetchAll();
    }
}
