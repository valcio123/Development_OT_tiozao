<?php
declare(strict_types=1);

require __DIR__ . '/../app/bootstrap.php';

$news = [];
$failed = false;
try {
    $news = news_list(10);
} catch (PDOException $e) {
    $failed = true;
    app_log('ERROR', 'news_list falhou', ['code' => $e->getCode()]);
}

if ($failed) {
    http_response_code(503);
    render_error('Site temporariamente indisponível.', 'Indisponível');
    exit;
}

render_header('Notícias', 'index.php');
?>
<section class="pergaminho">
<h2 class="barra-titulo">Notícias</h2>
<p class="boas-vindas">Bem-vindo ao <?= e((string)config('server_name', 'TiozaoOT')) ?>!</p>
<div class="acoes-home">
<a class="btn-ouro btn-grande" href="download.php">Baixar Client</a>
<a class="btn-verde btn-grande" href="criar-conta.php">Criar Conta</a>
</div>
<?php if ($news === []): ?>
<p class="vazio">Nenhuma notícia publicada ainda.</p>
<?php else: ?>
<div class="noticias">
<?php foreach ($news as $n): ?>
<article class="noticia">
<h3><?= e($n['title']) ?></h3>
<p class="meta">
<time datetime="<?= e(date('c', (int)$n['created_at'])) ?>"><?= e(date('d/m/Y H:i', (int)$n['created_at'])) ?></time>
<?php if ((string)$n['author'] !== ''): ?> — por <?= e($n['author']) ?><?php endif; ?>
</p>
<p class="corpo"><?= nl2br(e($n['body'])) ?></p>
</article>
<?php endforeach; ?>
</div>
<?php endif; ?>
</section>
<?php
render_footer();
