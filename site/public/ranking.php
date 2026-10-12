<?php
declare(strict_types=1);

require __DIR__ . '/../app/bootstrap.php';

$skillRaw = $_GET['skill'] ?? '';
$skill = is_string($skillRaw) ? $skillRaw : '';
if (!isset(SKILL_COLUMNS[$skill])) {
    $skill = 'level';
}

$rows = [];
try {
    $rows = ranking($skill, (int)config('ranking_limit', 50));
} catch (PDOException $e) {
    app_log('ERROR', 'ranking falhou', ['code' => $e->getCode()]);
    http_response_code(503);
    render_error('Site temporariamente indisponível.', 'Indisponível');
    exit;
}

$skills = array_keys(SKILL_COLUMNS);

render_header('Ranking', 'ranking.php');
?>
<section class="pergaminho">
<h2 class="barra-titulo">Ranking</h2>
<nav aria-label="Filtro de skill" class="filtros">
<?php foreach ($skills as $s): ?>
<a href="ranking.php?skill=<?= e($s) ?>"<?= $s === $skill ? ' aria-current="page"' : '' ?>><?= e(skill_label($s)) ?></a>
<?php endforeach; ?>
</nav>

<?php if ($rows === []): ?>
<p class="vazio">Nenhum personagem no ranking ainda.</p>
<?php else: ?>
<div class="tabela-wrap">
<table>
<thead>
<tr><th>#</th><th>Nome</th><th>Vocação</th><th>Level</th><th><?= e(skill_label($skill)) ?></th></tr>
</thead>
<tbody>
<?php foreach ($rows as $i => $r): ?>
<tr>
<td><?= $i + 1 ?></td>
<td><?= e($r['name']) ?></td>
<td><?= e(vocation_name((int)$r['vocation'])) ?></td>
<td><?= (int)$r['level'] ?></td>
<td><?= (int)$r['value'] ?></td>
</tr>
<?php endforeach; ?>
</tbody>
</table>
</div>
<?php endif; ?>
</section>
<?php
render_footer();
