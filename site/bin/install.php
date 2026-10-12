<?php
declare(strict_types=1);

// CLI: cria a tabela site_news (idempotente) e insere o seed inicial se estiver vazia.

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require __DIR__ . '/../app/bootstrap.php';

$pdo = db();
$pdo->exec(
    'CREATE TABLE IF NOT EXISTS site_news ('
    . ' id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,'
    . ' title VARCHAR(120) NOT NULL,'
    . ' body TEXT NOT NULL,'
    . ' author VARCHAR(64) NOT NULL DEFAULT \'\','
    . ' created_at INT UNSIGNED NOT NULL,'
    . ' KEY idx_created (created_at)'
    . ') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
);

$count = (int)$pdo->query('SELECT COUNT(*) FROM site_news')->fetchColumn();
if ($count === 0) {
    news_create(
        'Servidor aberto para os amigos!',
        "O servidor TiozaoOT está no ar. Crie sua conta, baixe o client e boa aventura!",
        (string)config('server_name', 'TiozaoOT')
    );
    fwrite(STDOUT, "site_news criada e semeada.\n");
} else {
    fwrite(STDOUT, "site_news já existe ({$count} notícia(s)). Nada a fazer.\n");
}

fwrite(STDOUT, "OK\n");
