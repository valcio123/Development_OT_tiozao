# Requisitos: site próprio "Clássico Medieval" do TiozaoOT

Fonte autoritativa: `E:\Amigos_OT\canary\.agents\tasks\site-proprio-brief.md`. Em caso de conflito, o brief vence. Esta versão parte do rascunho anterior (`.agents\pipeline\2026-10-12_12-43-52\01-requirements.md`) e incorpora, como requisitos, os pontos da revisão `03-design-review.md` (1 HIGH, 5 MEDIUM, 8 NIT) que afetam o comportamento esperado. As respostas a cada finding estão no fim.

## Resumo
Criar do zero um site PHP próprio para o servidor Canary "TiozaoOT", no visual "Clássico Medieval" aprovado pelo usuário. Ele passa a ser o site público na porta 7180 e lê e escreve no banco `canary` em produção. As funções são notícias, cadastro de conta e personagem, minha conta, ranking, online, download e status. A restrição principal é que `C:\xampp\htdocs\login.php` (MyAAC customizado, usado pelo OTClient 15.25) continue respondendo exatamente como hoje, em 127.0.0.1 e na 7180. Todo o texto do site e o relatório final ficam em português do Brasil.

## Requisitos funcionais

### RF1 Estrutura e integração
- RF1.1 O código fica em `E:\Amigos_OT\site` (ainda não existe), com webroot público separado (ex.: `site\public`). Config, includes, logs e dados de rate limit ficam fora do webroot.
- RF1.2 `http://<host>:7180/` serve o site novo. `http://<host>:7180/login.php` continua servindo o login.php do MyAAC sem alteração, e os includes relativos dele continuam funcionando. A porta 80 local pode continuar com o MyAAC.
- RF1.3 Regra única para o fallback `/site`:
  - se o `httpd -t` falhar com a integração na raiz da 7180, restaura-se o backup e tenta-se o fallback `/site`;
  - se o fallback também falhar no `httpd -t`, restaura-se o backup, o Apache fica sem nenhuma mudança e isso é reportado;
  - se o `httpd -t` passar, a integração na raiz é mantida. Trocar para o fallback depois do restart é decisão do usuário, e o relatório traz o bloco pronto e o procedimento.
- RF1.4 Todos os assets e links usam URLs relativas ou relativas à raiz, nunca com host fixo. O site funciona via 127.0.0.1, 192.168.0.100:7180 e 191.13.180.9:7180.
- RF1.5 São configuráveis, num config fora do webroot: o nome exibido (padrão "TiozaoOT") e a URL do Google Drive do download (padrão vazio).
- RF1.6 Antes de alterar qualquer arquivo existente (ex.: httpd.conf), faz-se um backup com data e hora em `E:\Amigos_OT\backups\`.
- RF1.7 Se for feito backup do banco `canary` antes das escritas de teste, ele tem de ser restaurável: UTF-8 (não UTF-16), blobs preservados (ex.: em hex), gravado direto pelo `mysqldump` e não por redirecionamento do PowerShell 5.1. A validade é conferida (bytes iniciais e "Dump completed" no fim). Nenhuma senha vai para a linha de comando.

### RF2 Visual e layout
- RF2.1 Fundo em gradiente de céu noturno para marrom, com silhueta de castelo no topo.
- RF2.2 Cabeçalho com o logo do nome configurado em serifa dourada (#e8c46a), contorno marrom-escuro, e subtítulo em itálico "Uma nova aventura começa aqui".
- RF2.3 Três colunas no desktop:
  - esquerda: menu em madeira (#2b1d10, borda #8a6326) com Notícias, Criar Conta, Minha Conta, Ranking, Online e Download, mais a caixa "Status do Servidor";
  - centro: painel de pergaminho (#f3e2b8→#e2c98f), barra de título #5a3c16 e texto em serifa;
  - direita: caixa de login (Email, Senha, botão em gradiente #b8862b→#7a5414) e "Top 5 Level".
- RF2.4 Na home, botões grandes "Baixar Client" (dourado) e "Criar Conta" (verde #3a6b2a).
- RF2.5 Fontes serifadas com Georgia como fallback. Nenhum recurso de CDN ou host externo.
- RF2.6 Responsivo: no celular as colunas empilham.
- RF2.7 Acessibilidade:
  - label associada em todo input;
  - alt em toda imagem;
  - foco de teclado visível;
  - contraste mínimo 4,5:1 para texto normal. Texto sobre os gradientes dourados (inclusive o botão de login) usa texto grande/bold ou cor escura, para atingir pelo menos 3:1 como texto grande;
  - o status online/offline não depende só da cor: o ponto colorido vem sempre acompanhado do texto "Online"/"Offline".

### RF3 Notícias (Início)
- RF3.1 Lista de notícias, da mais nova para a mais antiga, guardada em tabela `site_news` (não existe hoje) ou em arquivo. O design decide.
- RF3.2 Seed inicial: "Servidor aberto para os amigos!".
- RF3.3 Publicação mínima por contas com `type >= 5` no site, ou via arquivo. O design decide e documenta. Hoje as contas existentes têm `type = 6`, então todas poderiam publicar. O relatório lista quais contas têm permissão, para o usuário confirmar.

### RF4 Criar conta
- RF4.1 Campos: email, senha, confirmação de senha, nome do primeiro personagem, vocação e sexo.
- RF4.2 Vocações oferecidas: Sorcerer, Druid, Paladin, Knight e Monk (id 9, confirmado em `vocations.xml` e com "Monk Sample" no banco).
- RF4.3 Compatível com o Canary: login por email, senha em SHA1 hex minúsculo, `authType = "password"`. Todas as colunas NOT NULL sem default são preenchidas, inclusive as do MyAAC (ex.: `accounts.name` é UNIQUE e obrigatório; `players.conditions` é obrigatório).
- RF4.4 O personagem é criado copiando o "<Vocação> Sample" existente em `players` (e seus `player_items`), como o MyAAC faz. O sexo feminino usa o looktype feminino correspondente.
- RF4.5 Validações, com mensagens em pt-BR:
  - email: trim e minúsculas, formato válido, até 255 caracteres, único (o índice de `email` não é UNIQUE, então o site garante isso);
  - senha: no mínimo 8 caracteres, igual à confirmação, SEM trim (espaços nas pontas fazem parte da senha);
  - nome: letras e espaços simples, de 3 a 20 caracteres, único sem diferenciar maiúsculas;
  - nomes reservados (GOD, GM, CM, Sample) proibidos como palavra inteira;
  - vocação e sexo dentro da lista permitida.
- RF4.6 Conta e personagem são criados numa transação: se um falhar, nada fica gravado. Num cadastro concorrente do mesmo email ou nome, só um vence. O perdedor (inclusive por deadlock, MySQL 1213/SQLSTATE 40001) recebe a mensagem de duplicidade, e não um erro genérico.

### RF5 Minha conta
- RF5.1 Login por email e senha (SHA1) com sessão PHP, também pela caixa da coluna direita. Se houver mais de uma conta com o mesmo email (dado legado), vale a de menor id.
- RF5.2 Lista de personagens com nome, vocação, level e status online.
- RF5.3 Criar personagem adicional com as regras do RF4.4/RF4.5, no máximo 10 por conta.
- RF5.4 Trocar senha: pede a atual, a nova e a confirmação, com as mesmas regras do RF4.5.
- RF5.5 Logout destrói a sessão.
- RF5.6 A sessão expira por inatividade num tempo configurado, e a coleta de lixo do PHP não pode encerrá-la antes desse tempo.

### RF6 Online
- RF6.1 Lista via `players_online` + `players` (nome, vocação, level) e o total. Mostra mensagem quando não há ninguém.

### RF7 Ranking
- RF7.1 Top por level, excluindo `group_id >= 4` e os personagens Sample.
- RF7.2 Filtro opcional por skill: magic, sword, club, axe, distance, shielding e fishing, só por whitelist. Valor inválido cai em level.
- RF7.3 Top 50 ou paginação. O design decide.
- RF7.4 O "Top 5 Level" da lateral usa os mesmos critérios de exclusão.

### RF8 Download
- RF8.1 Botão para a URL configurada do Google Drive. Se ela estiver vazia, mostra "Link em breve".
- RF8.2 Seção "Como jogar", estática, com os passos: baixar o client, extrair o arquivo, abrir o otclient e entrar com email e senha (com link para Criar Conta).

### RF9 Status do servidor
- RF9.1 Online se uma conexão TCP em 127.0.0.1:7171 abrir em até 1 s. Senão, offline.
- RF9.2 Mostra jogadores online (`players_online`), versão "15.25", recorde (`server_config.players_record`) e uptime, se houver fonte confiável (opcional; se não houver, é omitido sem erro).

### RF10 Comportamento em falhas
- RF10.1 Falha de banco (inclusive de conexão) numa página que precisa dele: resposta HTTP 503 com mensagem genérica em pt-BR, sem stack trace, e registro no log. Para isso, a página faz as operações de banco antes de enviar qualquer saída.
- RF10.2 Falha de banco nos widgets do layout (status, Top 5, saudação): a página continua com HTTP 200 e mostra "—" no widget, com um único log por requisição. Páginas que não precisam de banco (Download, página de erro) nunca dão 503 por causa dele.

## Requisitos não funcionais

### RNF1 Segurança (obrigatório)
- PDO com prepared statements em todas as queries, charset utf8mb4.
- Credenciais lidas do `canary\config.lua` ou de um config fora do webroot. A senha nunca aparece em saída, log, linha de comando ou relatório.
- Token CSRF validado em todo POST.
- Cookie de sessão HttpOnly e SameSite=Lax, com `session_regenerate_id(true)` no login.
- `htmlspecialchars` em toda saída dinâmica.
- Rate limit por IP no login e no cadastro.
- Sem listagem de diretório e sem acesso HTTP a config, includes, logs e dados.
- Erros nunca mostram stack trace: vão para um log fora do webroot, e o usuário recebe uma mensagem genérica.

### RNF2 Operação
- O Canary está rodando e não pode ser parado nem reiniciado.
- O processo do Apache não pode ser morto. Mudanças de config são validadas com `httpd.exe -t`. A checagem considera o exit code e o texto "Syntax OK", que sai no stderr. Se for preciso reiniciar, o usuário faz isso pelo painel do XAMPP, e a verificação final fica pendente.
- Até lá, os testes usam `php -S 127.0.0.1:<porta livre> -t <public>`, encerrado no final.
- O MyAAC e o login.php não são modificados.
- Stack: PHP 8.2 do XAMPP e MariaDB 10.4, sem frameworks nem dependências externas (Composer/CDN).
- Os scripts de verificação podem ser executados de novo: limpam os buckets de rate limit de login e cadastro de 127.0.0.1 no início e no fim, e não deixam dados de teste.

## Critérios de aceite
1. `php -l` passa sem erros em todos os arquivos PHP do site.
2. Com o site servido, Início, Criar Conta, Minha Conta, Ranking, Online e Download retornam HTTP 200. O CSS retorna 200 com content-type `text/css`. Não há "Warning/Notice/Deprecated/Fatal error" no corpo, e nenhuma linha nova desses tipos (nem CRITICAL) aparece nos logs de PHP e da aplicação durante os GETs.
3. O HTML não contém URLs absolutas com host (`http://…` ou `//…`) para assets ou links internos.
4. Um POST sem token CSRF válido é rejeitado e não grava nada no banco.
5. Pelo formulário, com WebSession e token CSRF, cria-se uma conta e um personagem de teste. No banco, a senha está em SHA1 hex minúsculo, e o personagem e os itens foram copiados do Sample da vocação escolhida.
6. Entradas inválidas são recusadas com mensagem em pt-BR: email duplicado, senha menor que 8, confirmação diferente, nome com dígitos, nome reservado e nome duplicado.
7. O login no site mostra o personagem de teste na Minha Conta, e o ID de sessão muda após o login.
8. A troca de senha funciona: o login funciona com a nova e falha com a antiga. O logout encerra a sessão, e a Minha Conta volta a pedir login.
9. O login no jogo funciona com a conta de teste: um POST `{"type":"login","email":<teste>,"password":<senha>}` em `http://127.0.0.1/login.php` retorna o personagem novo.
10. Depois de exceder o limite de logins falhos por IP, novas tentativas são bloqueadas temporariamente com mensagem em pt-BR.
11. A conta de teste e os personagens dela são apagados do banco, e nenhum outro registro é alterado (contagens de `accounts` e `players` iguais às de antes do teste).
12. A regressão do login.php passa depois de cada mudança e no final:
    - `http://127.0.0.1/login.php` → `externaladdressprotected = 127.0.0.1`, com 7 personagens;
    - `http://192.168.0.100:7180/login.php` → `191.13.180.9:7172`.
13. Se o Apache foi alterado: `httpd.exe -t` termina com exit code 0 e "Syntax OK", e existe backup com data e hora em `E:\Amigos_OT\backups\`. A necessidade de reiniciar aparece no relatório como pendência do usuário.
14. Se foi feito dump do banco: o arquivo começa com bytes UTF-8 ("-- ", sem BOM UTF-16) e termina com "Dump completed".
15. Ranking: nenhum personagem com `group_id >= 4` nem Sample aparece, e o filtro de skill ordena pela skill escolhida. Um valor de skill inválido não causa erro e cai em level.
16. A caixa de Status mostra o ponto e o texto "Online" com o Canary rodando, e o número de jogadores bate com `players_online`.
17. Download mostra "Link em breve" com a URL vazia e mostra o botão com a URL quando ela está configurada. A seção "Como jogar" aparece nos dois casos.
18. Com o banco indisponível (simulado, ex.: credencial inválida num config de teste), Ranking responde 503 com mensagem genérica, e Download responde 200 com "—" nos widgets. Nenhum stack trace aparece no corpo.
19. Acessibilidade básica: todo input tem label associada, toda `<img>` tem alt, e o CSS define estilo de `:focus`/`:focus-visible`.
20. Requisições HTTP a config, includes e logs não são servidas, e um diretório sem index não é listado.
21. Uma senha com espaço nas pontas, cadastrada pelo site, funciona no login do site e no login.php do jogo (pode ser coberto por teste unitário dos validadores, mais a verificação do critério 9).
22. Se houver Edge ou Chrome headless, ficam salvos screenshots da home em desktop e em mobile, com os caminhos no relatório. Se não der, o motivo vai para o relatório.
23. O relatório `E:\Amigos_OT\canary\.agents\tasks\site-proprio-report.md` existe em pt-BR e contém:
    - arquivos criados;
    - mudanças no Apache e se é preciso reiniciar;
    - URLs local e `http://191.13.180.9:7180/`;
    - backups;
    - como configurar o link do Drive;
    - como postar notícias e quais contas têm permissão;
    - itens não verificados;
    - o aviso de que a 7180 é HTTP sem TLS (as senhas trafegam sem criptografia), com as opções futuras.

## Fora do escopo
- Modificar o MyAAC, o login.php ou o Canary, e reiniciar o Canary.
- Implementar TLS/HTTPS (só citar as opções no relatório).
- Recuperação de senha por email, verificação de email e captcha.
- Painel admin completo, guilds, houses, highscores além dos listados, loja ou doações, fórum, páginas de personagem ou de mortes.
- Migrar para um hash de senha mais forte (o Canary exige SHA1).
- Abrir portas no roteador ou no firewall.
- Tornar `accounts.email` UNIQUE no schema (alteração de schema de produção).

## Premissas
- A1 Monk (id 9) e "Monk Sample" existem (a revisão conferiu). Se deixarem de existir, o Monk sai do formulário e isso é reportado.
- A2 `E:\Amigos_OT\backups\` existe. `E:\Amigos_OT\site` ainda não existe (conferido).
- A3 Nome reservado vale como palavra inteira, sem diferenciar maiúsculas ("Gm Joao" proibido, "Gmail" permitido).
- A4 Limites padrão do rate limit: 5 logins falhos por IP em 15 min e 3 cadastros por IP por hora, configuráveis.
- A5 Sexo: 0 = feminino, 1 = masculino, como no Canary.
- A6 Não há proxy na 7180, então `REMOTE_ADDR` é o IP real do cliente.
- A7 O uptime é opcional.
- A8 Tempo de inatividade da sessão padrão: 2 h, configurável.
- A9 O backup do banco não é exigido pelo brief, mas é recomendado antes das escritas de teste em produção. Se for feito, vale o RF1.7.

## Respostas aos findings da revisão anterior
Os findings tratam do design, mas os que mudam o comportamento esperado viraram requisito aqui. Os puramente de implementação ficam para o design.
1. HIGH, dump do banco corrompido: atendido como requisito (RF1.7, critério 14). O comando exato fica no design.
2. MEDIUM, "Como jogar" ausente: reforçado (RF8.2, critério 17).
3. MEDIUM, checagem de warnings inócua: atendido (critério 2 exige conferir os logs).
4. MEDIUM, gatilho do fallback contraditório: atendido com uma regra única (RF1.3).
5. MEDIUM, assinaturas dos helpers: as assinaturas ficam para o design. Aqui viram requisito as regras de comportamento (senha sem trim, trim e normalização no email e no nome; RF4.5, critério 21) e a testabilidade do rate limit (RNF2).
6. MEDIUM, 503 x "—": atendido (RF10, critério 18).
7. NIT, deadlock no cadastro concorrente: atendido (RF4.6).
8. NIT, email não único no login: atendido (RF5.1, RF4.5).
9. NIT, GC da sessão: atendido (RF5.6, A8).
10. NIT, smoke esbarra no limite de cadastro: atendido (RNF2, script reexecutável).
11. NIT, "Syntax OK" no stderr: atendido (RNF2, critério 13).
12. NIT, contagem de contas com type 6: fato corrigido (RF3.3), e a lista de contas vai para o relatório (critério 23).
13. NIT, contraste do botão: atendido (RF2.7).
14. NIT, ponto de status: atendido (RF2.7, critério 16).
