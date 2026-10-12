<?php
// Repositório de notícias (tabela site_news).

if (!function_exists('news_list')) {
    function news_list(int $limit = 10): array
    {
        $stmt = db()->prepare('SELECT id, title, body, author, created_at FROM site_news ORDER BY created_at DESC, id DESC LIMIT ?');
        $stmt->bindValue(1, $limit, PDO::PARAM_INT);
        $stmt->execute();
        return $stmt->fetchAll();
    }
}

if (!function_exists('news_create')) {
    function news_create(string $title, string $body, string $author): int
    {
        $stmt = db()->prepare('INSERT INTO site_news (title, body, author, created_at) VALUES (?, ?, ?, ?)');
        $stmt->execute([$title, $body, $author, time()]);
        return (int)db()->lastInsertId();
    }
}

if (!function_exists('news_delete')) {
    function news_delete(int $id): void
    {
        $stmt = db()->prepare('DELETE FROM site_news WHERE id = ?');
        $stmt->execute([$id]);
    }
}
