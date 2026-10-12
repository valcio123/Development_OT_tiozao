<?php
// Nomes de vocação e whitelist das colunas de skill do ranking.

if (!defined('VOCATION_NAMES')) {
    define('VOCATION_NAMES', [
        0  => 'Sem vocação',
        1  => 'Sorcerer',
        2  => 'Druid',
        3  => 'Paladin',
        4  => 'Knight',
        5  => 'Master Sorcerer',
        6  => 'Elder Druid',
        7  => 'Royal Paladin',
        8  => 'Elite Knight',
        9  => 'Monk',
        10 => 'Exalted Monk',
    ]);
}

if (!function_exists('vocation_name')) {
    function vocation_name(int $id): string
    {
        return VOCATION_NAMES[$id] ?? 'Desconhecida';
    }
}

if (!defined('SKILL_COLUMNS')) {
    // chave do GET => [coluna de ordenação, coluna de desempate]
    define('SKILL_COLUMNS', [
        'level'     => ['level', 'experience'],
        'magic'     => ['maglevel', 'manaspent'],
        'sword'     => ['skill_sword', 'skill_sword_tries'],
        'club'      => ['skill_club', 'skill_club_tries'],
        'axe'       => ['skill_axe', 'skill_axe_tries'],
        'distance'  => ['skill_dist', 'skill_dist_tries'],
        'shielding' => ['skill_shielding', 'skill_shielding_tries'],
        'fishing'   => ['skill_fishing', 'skill_fishing_tries'],
    ]);
}

if (!function_exists('skill_columns')) {
    // Devolve as colunas seguras para a chave pedida, ou as de level.
    function skill_columns(?string $key): array
    {
        if (is_string($key) && isset(SKILL_COLUMNS[$key])) {
            return SKILL_COLUMNS[$key];
        }
        return SKILL_COLUMNS['level'];
    }
}

if (!function_exists('skill_label')) {
    function skill_label(string $key): string
    {
        return match ($key) {
            'magic'     => 'Magic Level',
            'sword'     => 'Sword',
            'club'      => 'Club',
            'axe'       => 'Axe',
            'distance'  => 'Distance',
            'shielding' => 'Shielding',
            'fishing'   => 'Fishing',
            default     => 'Level',
        };
    }
}
