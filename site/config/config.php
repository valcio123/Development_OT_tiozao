<?php
// Configuração do site próprio "Clássico Medieval" do TiozaoOT.
// Este arquivo fica FORA do webroot (site\public) e nunca é servido por HTTP.

return [
    // Identidade exibida
    'server_name'       => 'TiozaoOT',
    'tagline'           => 'Uma nova aventura começa aqui',
    'client_version'    => '15.25',

    // Link do Google Drive para o download do client. Vazio => "Link em breve".
    'download_url'      => '',

    // Credenciais do banco lidas do config.lua do Canary.
    'canary_config_lua' => 'E:/Amigos_OT/canary/config.lua',

    // Status do servidor (conexão TCP no login/status do Canary).
    'status_host'       => '127.0.0.1',
    'status_port'       => 7171,
    'status_timeout'    => 1.0,
    'status_cache_ttl'  => 30,

    // Fuso horário
    'timezone'          => 'America/Sao_Paulo',

    // Samples de personagem por vocação (ids conferidos em vocations.xml/players).
    'samples'           => [
        1 => 'Sorcerer Sample',
        2 => 'Druid Sample',
        3 => 'Paladin Sample',
        4 => 'Knight Sample',
        9 => 'Monk Sample',
    ],

    'max_characters'    => 10,

    // Rate limit por IP
    'login_limit'       => ['max' => 5, 'window' => 900],    // 5 falhas / 15 min
    'register_limit'    => ['max' => 3, 'window' => 3600],   // 3 contas / 1 h

    'ranking_limit'     => 50,
    'session_idle'      => 7200,   // 2 h
];
