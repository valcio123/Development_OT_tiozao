<?php
// Repositório de contas (accounts) e criação atômica de conta + primeiro personagem.

if (!function_exists('is_unique_violation')) {
    function is_unique_violation(PDOException $e): bool
    {
        return ($e->errorInfo[1] ?? null) === 1062 || $e->getCode() === '23000';
    }
}

if (!function_exists('is_deadlock')) {
    function is_deadlock(PDOException $e): bool
    {
        return ($e->errorInfo[1] ?? null) === 1213 || $e->getCode() === '40001';
    }
}

if (!function_exists('create_account_with_character')) {
    /**
     * Cria a conta e o primeiro personagem numa transação.
     * @return array{ok:bool,field:?string,error:?string,account_id:?int}
     */
    function create_account_with_character(string $email, string $password, string $charName, int $vocation, int $sex): array
    {
        $samples = (array)config('samples', []);
        if (!isset($samples[$vocation])) {
            return ['ok' => false, 'field' => 'vocation', 'error' => 'Escolha uma vocação válida.'];
        }
        $sampleName = (string)$samples[$vocation];

        $pdo = db();
        $pdo->beginTransaction();
        try {
            // 1) Email (índice não-único): o deadlock do FOR UPDATE + INSERT impede duplicata.
            $stmt = $pdo->prepare('SELECT id FROM accounts WHERE email = ? FOR UPDATE');
            $stmt->execute([$email]);
            if ($stmt->fetchColumn()) {
                $pdo->rollBack();
                return ['ok' => false, 'field' => 'email', 'error' => 'Este email já está cadastrado.'];
            }

            // 2) Nome do personagem.
            $stmt = $pdo->prepare('SELECT 1 FROM players WHERE name = ? LIMIT 1');
            $stmt->execute([$charName]);
            if ($stmt->fetchColumn()) {
                $pdo->rollBack();
                return ['ok' => false, 'field' => 'name', 'error' => 'Este nome já está em uso.'];
            }

            // 3) Sample da vocação.
            $sampleId = find_sample_id($pdo, $sampleName);
            if ($sampleId === null) {
                $pdo->rollBack();
                app_log('ERROR', 'sample ausente', ['sample' => $sampleName]);
                return ['ok' => false, 'field' => null, 'error' => 'Não foi possível criar o personagem agora. Tente mais tarde.'];
            }

            // 4) Conta.
            $accName = 'w' . bin2hex(random_bytes(7));
            $now = time();
            $stmt = $pdo->prepare('INSERT INTO accounts (name, password, email, `key`, created, creation, rlname, location, country, type, premdays, lastday) '
                . "VALUES (?, ?, ?, '', ?, ?, '', '', '', 1, 0, 0)");
            $stmt->execute([$accName, sha1($password), $email, $now, $now]);
            $accountId = (int)$pdo->lastInsertId();

            // 5) e 6) Primeiro personagem (copia o sample) e os itens.
            insert_character_row($pdo, $accountId, $sampleId, $charName, $sex, $now);

            $pdo->commit();
            app_log('INFO', 'conta criada', ['account_id' => $accountId]);
            return ['ok' => true, 'field' => null, 'error' => null, 'account_id' => $accountId];
        } catch (PDOException $e) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            if (is_deadlock($e)) {
                return ['ok' => false, 'field' => 'email', 'error' => 'Este email já está cadastrado.'];
            }
            if (is_unique_violation($e)) {
                return ['ok' => false, 'field' => 'name', 'error' => 'Este nome já está em uso.'];
            }
            app_log('ERROR', 'create_account falhou', ['code' => $e->getCode(), 'msg' => $e->getMessage()]);
            return ['ok' => false, 'field' => null, 'error' => 'Não foi possível criar a conta agora. Tente mais tarde.'];
        }
    }
}

if (!function_exists('find_account_by_email')) {
    function find_account_by_email(string $email): ?array
    {
        $stmt = db()->prepare('SELECT id, email, type, password FROM accounts WHERE email = ? ORDER BY id LIMIT 1');
        $stmt->execute([$email]);
        $row = $stmt->fetch();
        return $row ?: null;
    }
}

if (!function_exists('change_password')) {
    function change_password(int $accountId, string $newPassword): void
    {
        $stmt = db()->prepare('UPDATE accounts SET password = ? WHERE id = ?');
        $stmt->execute([sha1($newPassword), $accountId]);
    }
}
