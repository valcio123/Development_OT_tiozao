<?php
declare(strict_types=1);

// CLI: apaga APENAS a conta de teste (email terminando em @tiozaoot.test) e seus
// personagens, numa transação, verificando as contagens antes de confirmar.

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require __DIR__ . '/../app/bootstrap.php';

$email = '';
foreach ($argv as $arg) {
    if (str_starts_with($arg, '--email=')) {
        $email = substr($arg, 8);
    }
}
$email = mb_strtolower(trim($email));

if ($email === '' || !str_ends_with($email, '@tiozaoot.test')) {
    fwrite(STDERR, "Recusado: só emails @tiozaoot.test podem ser apagados.\n");
    exit(2);
}

$pdo = db();

$accBefore = (int)$pdo->query('SELECT COUNT(*) FROM accounts')->fetchColumn();
$playersBefore = (int)$pdo->query('SELECT COUNT(*) FROM players')->fetchColumn();

$stmt = $pdo->prepare('SELECT id FROM accounts WHERE email = ?');
$stmt->execute([$email]);
$ids = array_map('intval', $stmt->fetchAll(PDO::FETCH_COLUMN));

if ($ids === []) {
    fwrite(STDOUT, "Nada a apagar para {$email}.\n");
    exit(0);
}

$in = implode(',', array_fill(0, count($ids), '?'));
$stmt = $pdo->prepare("SELECT id FROM players WHERE account_id IN ({$in})");
$stmt->execute($ids);
$playerIds = array_map('intval', $stmt->fetchAll(PDO::FETCH_COLUMN));

$pdo->beginTransaction();
try {
    if ($playerIds !== []) {
        $pin = implode(',', array_fill(0, count($playerIds), '?'));
        $stmt = $pdo->prepare("DELETE FROM player_items WHERE player_id IN ({$pin})");
        $stmt->execute($playerIds);
    }

    $stmt = $pdo->prepare("DELETE FROM players WHERE account_id IN ({$in})");
    $stmt->execute($ids);

    $stmt = $pdo->prepare("DELETE FROM accounts WHERE id IN ({$in})");
    $stmt->execute($ids);

    $accAfter = (int)$pdo->query('SELECT COUNT(*) FROM accounts')->fetchColumn();
    $playersAfter = (int)$pdo->query('SELECT COUNT(*) FROM players')->fetchColumn();

    if ($accAfter !== $accBefore - count($ids) || $playersAfter !== $playersBefore - count($playerIds)) {
        $pdo->rollBack();
        fwrite(STDERR, "Contagens inesperadas; rollback feito.\n");
        exit(3);
    }

    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    fwrite(STDERR, "Falha ao apagar: " . $e->getMessage() . "\n");
    exit(4);
}

fwrite(STDOUT, 'Apagado: ' . count($ids) . ' conta(s), ' . count($playerIds) . " personagem(ns).\n");
