<?php
// Layout: cabeçalho, rodapé e mensagens flash.

if (!function_exists('flash')) {
    function flash(?string $msg = null): ?string
    {
        if ($msg !== null) {
            $_SESSION['flash'] = $msg;
            return null;
        }
        $m = $_SESSION['flash'] ?? null;
        unset($_SESSION['flash']);
        return is_string($m) ? $m : null;
    }
}

if (!function_exists('menu_items')) {
    function menu_items(): array
    {
        return [
            'index.php'       => 'Notícias',
            'criar-conta.php' => 'Criar Conta',
            'minha-conta.php' => 'Minha Conta',
            'ranking.php'     => 'Ranking',
            'online.php'      => 'Online',
            'download.php'    => 'Download',
        ];
    }
}

if (!function_exists('render_error')) {
    function render_error(string $message, string $title = 'Erro'): void
    {
        $name = e((string)config('server_name', 'TiozaoOT'));
        echo '<!doctype html><html lang="pt-BR"><head><meta charset="utf-8">'
            . '<meta name="viewport" content="width=device-width, initial-scale=1">'
            . '<meta name="robots" content="noindex">'
            . '<title>' . e($title) . ' — ' . $name . '</title>'
            . '<link rel="stylesheet" href="assets/css/style.css"></head><body>'
            . '<header class="topo"><h1 class="logo">' . $name . '</h1></header>'
            . '<div class="layout layout-erro"><main id="conteudo" class="col-center pergaminho">'
            . '<h2 class="barra-titulo">' . e($title) . '</h2>'
            . '<p>' . e($message) . '</p>'
            . '<p><a class="btn-link" href="index.php">Voltar ao início</a></p>'
            . '</main></div></body></html>';
    }
}

if (!function_exists('render_header')) {
    function render_header(string $title, string $active = ''): void
    {
        $name = e((string)config('server_name', 'TiozaoOT'));
        $tag = e((string)config('tagline', ''));
        $fullTitle = $title === '' ? $name : e($title) . ' — ' . $name;
        ?><!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title><?= $fullTitle ?></title>
<link rel="stylesheet" href="assets/css/style.css">
</head>
<body>
<a class="skip" href="#conteudo">Pular para o conteúdo</a>
<header class="topo">
<h1 class="logo"><?= $name ?></h1>
<?php if ($tag !== ''): ?><p class="tagline"><em><?= $tag ?></em></p><?php endif; ?>
</header>
<div class="layout">
<nav aria-label="Menu principal" class="col-left">
<ul class="menu">
<?php foreach (menu_items() as $file => $label):
    $current = ($file === $active);
    ?>
<li><a href="<?= e($file) ?>"<?= $current ? ' aria-current="page"' : '' ?>><?= e($label) ?></a></li>
<?php endforeach; ?>
</ul>
<?php
        $st = null;
        try {
            $st = server_status();
        } catch (Throwable $e) {
            app_log('ERROR', 'status widget falhou', ['class' => get_class($e)]);
        }
        ?>
<section class="box" aria-labelledby="status-h">
<h2 id="status-h">Status do Servidor</h2>
<?php if ($st === null): ?>
<p>Estado: —</p>
<?php else: ?>
<p class="status-linha">
<span class="dot <?= $st['online'] ? 'dot-on' : 'dot-off' ?>" aria-hidden="true"></span>
<?= $st['online'] ? 'Online' : 'Offline' ?>
</p>
<ul class="status-dados">
<li>Jogadores online: <?= $st['players'] === null ? '—' : (int)$st['players'] ?></li>
<li>Versão: <?= e($st['version']) ?></li>
<li>Recorde: <?= $st['record'] === null ? '—' : (int)$st['record'] ?></li>
</ul>
<?php endif; ?>
</section>
</nav>
<main id="conteudo" class="col-center">
<?php
        $flash = flash();
        if ($flash !== null && $flash !== ''):
            ?>
<div class="flash" role="status"><?= e($flash) ?></div>
<?php endif;
    }
}

if (!function_exists('render_footer')) {
    function render_footer(): void
    {
        $acc = null;
        try {
            $acc = current_account();
        } catch (Throwable $e) {
            app_log('ERROR', 'auth widget falhou', ['class' => get_class($e)]);
        }
        ?>
</main>
<aside class="col-right">
<section class="box" aria-labelledby="login-h">
<h2 id="login-h"><?= $acc ? 'Sua conta' : 'Entrar' ?></h2>
<?php if ($acc): ?>
<p class="ola">Olá, <?= e($acc['email']) ?></p>
<p><a class="btn-link" href="minha-conta.php">Minha Conta</a></p>
<form action="minha-conta.php" method="post" class="form-logout">
<?= csrf_field() ?>
<input type="hidden" name="action" value="logout">
<button type="submit" class="btn-ouro">Sair</button>
</form>
<?php else: ?>
<form action="minha-conta.php" method="post" class="form-login">
<?= csrf_field() ?>
<input type="hidden" name="action" value="login">
<label for="login-email">Email</label>
<input type="text" id="login-email" name="email" inputmode="email" autocomplete="username" maxlength="255">
<label for="login-password">Senha</label>
<input type="password" id="login-password" name="password" autocomplete="current-password" maxlength="256">
<button type="submit" class="btn-ouro">Entrar</button>
</form>
<?php endif; ?>
</section>
<section class="box" aria-labelledby="top5-h">
<h2 id="top5-h">Top 5 Level</h2>
<?php
        $top = null;
        try {
            $top = top_level(5);
        } catch (Throwable $e) {
            app_log('ERROR', 'top5 widget falhou', ['class' => get_class($e)]);
        }
        ?>
<?php if ($top === null): ?>
<p>—</p>
<?php elseif ($top === []): ?>
<p>Nenhum personagem ainda.</p>
<?php else: ?>
<ol class="top5">
<?php foreach ($top as $p): ?>
<li><span class="top-nome"><?= e($p['name']) ?></span> <span class="top-level">lv <?= (int)$p['level'] ?></span></li>
<?php endforeach; ?>
</ol>
<?php endif; ?>
</section>
</aside>
</div>
<footer class="rodape">
<p><?= e((string)config('server_name', 'TiozaoOT')) ?> — servidor para os amigos.</p>
</footer>
</body>
</html>
<?php
    }
}
