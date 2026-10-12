# Requisitos: site próprio "Clássico Medieval" do TiozaoOT

Fonte: `E:\Amigos_OT\canary\.agents\tasks\site-proprio-brief.md` (autoritativo). Este documento organiza o brief em requisitos testáveis. Se houver conflito, o brief vence.

## Resumo
Criar do zero um site PHP próprio para o servidor Canary "TiozaoOT", com o visual "Clássico Medieval" aprovado pelo usuário. O site substitui o MyAAC como site público na porta 7180. Ele lê e escreve no banco `canary` em produção: cadastro de conta e personagem, minha conta, ranking, online, download, notícias e status. Restrição principal: o `C:\xampp\htdocs\login.php` (MyAAC customizado, usado pelo OTClient 15.25) tem de continuar respondendo exatamente como hoje, em 127.0.0.1 e em 7180. Todo o texto do site e o relatório final ficam em português do Brasil.

## Requisitos funcionais

### RF1 Estrutura e integração
- RF1.1 Código em `E:\Amigos_OT\site`, com webroot público separado (ex.: `site\public`). Config, includes, logs e dados de rate-limit ficam fora do webroot.
- RF1.2 `http://<host>:7180/` serve o site novo. `http://<host>:7180/login.php` continua servindo o login.php do MyAAC sem alterações, e os includes relativos dele continuam funcionando. A porta 80 local pode continuar com o MyAAC.
- RF1.3 Se a integração na raiz da 7180 se mostrar frágil, o fallback aceito é o subpath `/site`, com a escolha documentada.
- RF1.4 Todos os assets e links usam URLs relativas ou relativas à raiz, nunca com host fixo. O site funciona via 127.0.0.1, 192.168.0.100:7180 e 191.13.180.9:7180.
- RF1.5 O nome exibido do servidor é configurável, com padrão "TiozaoOT". A URL do Google Drive para o download também é configurável.
- RF1.6 Antes de alterar qualquer arquivo existente (ex.: httpd.conf), faz-se um backup com data e hora em `E:\Amigos_OT\backups\`.

### RF2 Visual e layout
- RF2.1 Fundo em gradiente de céu noturno para marrom, com silhueta de castelo no topo.
- RF2.2 Cabeçalho com o logo "TiozaoOT" em serifa dourada (#e8c46a) com contorno marrom-escuro e o subtítulo em itálico "Uma nova aventura começa aqui".
- RF2.3 Três colunas no desktop:
  - esquerda: menu em madeira (#2b1d10, borda #8a6326) com Notícias, Criar Conta, Minha Conta, Ranking, Online e Download, mais a caixa "Status do Servidor";
  - centro: painel de pergaminho (#f3e2b8→#e2c98f) com barra de título #5a3c16 e texto em serifa;
  - direita: caixa de login (Email, Senha, botão em gradiente #b8862b→#7a5414) e "Top 5 Level".
- RF2.4 Na home, botões grandes "Baixar Client" (dourado) e "Criar Conta" (verde #3a6b2a).
- RF2.5 Fontes serifadas com Georgia como fallback. Nenhum recurso de CDN ou host externo.
- RF2.6 Responsivo: no celular, as colunas empilham.
- RF2.7 Acessibilidade: label em todos os inputs, contraste adequado, foco de teclado visível e alt em todas as imagens.

### RF3 Notícias (Início)
- RF3.1 Lista de notícias, com armazenamento em tabela `site_news` ou em arquivo (o design decide).
- RF3.2 Seed inicial: "Servidor aberto para os amigos!".
- RF3.3 Publicação mínima: contas com `type >= 5` postam pelo site, ou a publicação é feita via arquivo (o design decide e documenta).

### RF4 Criar conta
- RF4.1 Campos: email, senha, confirmação de senha, nome do primeiro personagem, vocação e sexo.
- RF4.2 Vocações oferecidas: Sorcerer, Druid, Paladin, Knight e Monk. O Monk (id 9) foi confirmado em `vocations.xml`.
- RF4.3 A conta é compatível com o Canary: login por email, senha em SHA1 hexadecimal minúsculo e as colunas obrigatórias preenchidas, inclusive as extras do MyAAC (`key`, `created`, `rlname` etc.). O schema é conferido em `accounts`/`players` e em `src/account`.
- RF4.4 O personagem é criado copiando o "<Vocação> Sample" existente em `players`, como o MyAAC faz.
- RF4.5 Validações:
  - email válido e único;
  - senha com 8 ou mais caracteres, igual à confirmação;
  - nome só com letras e espaços simples, de 3 a 20 caracteres, único sem diferenciar maiúsculas;
  - proibidos os nomes reservados (GOD, GM, CM, Sample) como palavra;
  - vocação e sexo dentro da lista permitida.
- RF4.6 Conta e personagem são criados de forma atômica (transação): se um falhar, nada é gravado.

### RF5 Minha conta
- RF5.1 Login por email e senha (SHA1) com sessão PHP. O login também pode ser feito pela caixa da coluna direita.
- RF5.2 Lista de personagens com nome, vocação, level e status online.
- RF5.3 Criar personagem adicional (mesmas regras do RF4.4/RF4.5), com no máximo 10 por conta.
- RF5.4 Trocar senha: pede a atual, a nova e a confirmação, com a mesma regra de tamanho.
- RF5.5 Logout, que destrói a sessão.

### RF6 Online
- RF6.1 Lista via `players_online` + `players` com nome, vocação e level, mais o total. Mostra mensagem quando não houver ninguém.

### RF7 Ranking
- RF7.1 Top por level, excluindo `group_id >= 4` e os personagens Sample.
- RF7.2 Filtro opcional por skill: magic, sword, club, axe, distance, shielding e fishing. Só valores de uma whitelist; qualquer valor inválido cai em level.
- RF7.3 Top 50 ou paginação (o design decide).
- RF7.4 "Top 5 Level" da lateral usa os mesmos critérios de exclusão.

### RF8 Download
- RF8.1 Botão para a URL configurada do Google Drive. Se ela estiver vazia, mostra "Link em breve".
- RF8.2 Seção "Como jogar": baixe, extraia, abra o otclient e entre com email e senha.

### RF9 Status do servidor
- RF9.1 Online se uma conexão TCP em 127.0.0.1:7171 abrir dentro de um timeout curto (≤ 1 s). Caso contrário, offline.
- RF9.2 Jogadores online via `players_online`, versão "15.25", recorde via `server_config` se existir e uptime se der (opcional).

## Requisitos não funcionais

### RNF1 Segurança (obrigatório)
- PDO com prepared statements em todas as queries, charset utf8mb4.
- Credenciais lidas do `canary\config.lua` ou de um config fora do webroot. A senha nunca é impressa em saída, log ou relatório.
- Token CSRF validado em todo POST.
- Cookie de sessão HttpOnly e SameSite=Lax, com `session_regenerate_id(true)` no login.
- `htmlspecialchars` em toda saída dinâmica.
- Rate limiting por IP no login e no cadastro.
- Sem listagem de diretório e sem acesso HTTP a config, includes e logs.
- Erros nunca mostram stack trace ao usuário: vão para um log fora do webroot, e o usuário recebe uma mensagem genérica.

### RNF2 Operação
- O Canary está rodando e não pode ser parado nem reiniciado.
- O processo do Apache não pode ser morto. Mudanças de config são validadas com `httpd.exe -t`. Se for preciso reiniciar, o usuário faz isso pelo painel do XAMPP, e a verificação final fica pendente.
- Até lá, os testes usam `php -S 127.0.0.1:<porta livre> -t <public>`, encerrado ao final.
- O MyAAC e o login.php não são modificados.
- Stack: PHP do XAMPP, sem frameworks nem dependências externas (Composer/CDN).

## Critérios de aceite
1. `php -l` passa sem erros em todos os arquivos PHP do site.
2. Com o site servido, todas as páginas (Início, Criar Conta, Minha Conta, Ranking, Online, Download) retornam HTTP 200 sem warnings ou notices PHP no corpo, e o CSS retorna 200 com content-type text/css.
3. O HTML não contém URLs absolutas com host (http://… ou //…) para assets ou links internos.
4. Um POST sem token CSRF válido é rejeitado e não grava nada no banco.
5. Pelo formulário, com WebSession e token CSRF, cria-se uma conta e um personagem de teste. No banco, a senha está em SHA1 hex minúsculo, e o personagem foi copiado do Sample da vocação escolhida.
6. Entradas inválidas são recusadas com mensagem em pt-BR: email duplicado, senha menor que 8, confirmação diferente, nome com dígitos, nome reservado e nome duplicado.
7. O login no site mostra o personagem de teste na Minha Conta, e o ID de sessão muda após o login.
8. A troca de senha funciona: o login funciona com a nova e falha com a antiga. O logout encerra a sessão, e a Minha Conta volta a pedir login.
9. O login no jogo funciona com a conta de teste: um POST `{"type":"login","email":<teste>,"password":<senha>}` em `http://127.0.0.1/login.php` retorna o personagem novo.
10. Depois de exceder o limite de tentativas de login por IP, novas tentativas são bloqueadas temporariamente.
11. A conta de teste e os personagens dela são apagados do banco, e nenhum outro registro é alterado.
12. A regressão do login.php passa depois de cada mudança e no final:
    - `http://127.0.0.1/login.php` → `externaladdressprotected = 127.0.0.1`, com 7 personagens;
    - `http://192.168.0.100:7180/login.php` → `191.13.180.9:7172`.
13. Se o Apache foi alterado: `httpd.exe -t` retorna "Syntax OK", e existe backup com data e hora em `E:\Amigos_OT\backups\`. Se for preciso reiniciar, o relatório deixa isso explícito como pendência do usuário.
14. Ranking: nenhum personagem com `group_id >= 4` nem Sample aparece, e o filtro de skill ordena pela skill escolhida.
15. A caixa de Status mostra online com o Canary rodando, e o número de jogadores bate com `players_online`.
16. Download mostra "Link em breve" quando a URL está vazia e mostra o botão com a URL quando ela está configurada.
17. Acessibilidade básica: todo input tem label associada, toda `<img>` tem alt, e o CSS define estilo de `:focus`/`:focus-visible`.
18. Requisições HTTP a arquivos de config, includes e logs não são servidas, e um diretório sem index não é listado.
19. Se houver Edge ou Chrome headless, ficam salvos screenshots da home em desktop e em mobile, com os caminhos no relatório.
20. O relatório `E:\Amigos_OT\canary\.agents\tasks\site-proprio-report.md` existe em pt-BR e contém:
    - arquivos criados;
    - mudanças no Apache e se é preciso reiniciar;
    - URLs local e `http://191.13.180.9:7180/`;
    - backups;
    - como configurar o link do Drive;
    - como postar notícias;
    - itens não verificados;
    - o aviso de que a 7180 é HTTP sem TLS, com as opções futuras.

## Fora do escopo
- Modificar o MyAAC, o login.php ou o servidor Canary, e reiniciar o Canary.
- Implementar TLS/HTTPS (só citar as opções no relatório).
- Recuperação de senha por email, verificação de email e captcha.
- Painel admin completo, guilds, houses, highscores além dos listados, loja ou doações, fórum, páginas de personagem ou de mortes.
- Migrar para hash de senha mais forte (o Canary exige SHA1).
- Abrir portas no roteador ou firewall.

## Premissas
- A1 Monk está disponível (id 9 em `vocations.xml`), e existe um "Monk Sample" em `players`. Se não existir, o Monk é omitido do formulário e isso é reportado.
- A2 O backup em `E:\Amigos_OT\backups\` já existe como diretório. `E:\Amigos_OT\site` ainda não existe.
- A3 O "nome reservado" vale como palavra inteira, sem diferenciar maiúsculas (ex.: "Gm Joao" proibido, "Gmail" não). O design pode endurecer essa regra.
- A4 Valores padrão aceitos para o rate limit: no máximo 5 logins falhos por IP em 15 minutos e 3 cadastros por IP por hora. O armazenamento fica fora do webroot ou no banco.
- A5 Sexo: 0 = feminino, 1 = masculino, conforme o Canary.
- A6 O site atrás da 7180 vê os acessos externos com o IP real do cliente, porque não há proxy.
- A7 O uptime é opcional. Se não houver fonte confiável, ele é omitido sem erro.
