<?php
declare(strict_types=1);

require __DIR__ . '/../app/bootstrap.php';

$players = [];
try {
    $players = online_players();
} catch (PDOException $e) {
    app_log('ERROR', 'online falhou', ['code' => $e->getCode()]);
    http_response_code(503);
    render_error('Site temporariamente indisponível.', 'Indisponível');
    exit;
}

render_header('Online', 'online.php');
?>
<section class="pergaminho">
<h2 class="barra-titulo">Jogadores Online</h2>
<p>Total: <?= count($players) ?></p>

<?php if ($players === []): ?>
<p class="vazio">Nenhum jogador online no momento.</p>
<?php else: ?>
<div class="tabela-wrap">
<table>
<thead><tr><th>Nome</th><th>Vocação</th><th>Level</th></tr></thead>
<tbody>
<?php foreach ($players as $p): ?>
<tr>
<td><?= e($p['name']) ?></td>
<td><?= e(vocation_name((int)$p['vocation'])) ?></td>
<td><?= (int)$p['level'] ?></td>
</tr>
<?php endforeach; ?>
</tbody>
</table>
</div>
<?php endif; ?>
</section>
<?php
render_footer();
