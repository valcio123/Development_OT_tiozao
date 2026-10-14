# Modo de combate tradicional

## Visual e elemento das ultimates tradicionais

No modo tradicional, Mas Vis usa `CONST_ME_EXPLOSIONAREA` (5) e Mas Tera usa
`CONST_ME_POISONAREA` (21). Ambas causam dano fisico, conforme pedido do usuario.
As formulas, area, custo de 1200 mana e cooldown tradicional permanecem vigentes.
Mas Tera usa a animacao de veneno com dano fisico imediato; nao aplica poison.
No modo moderno, Mas Vis conserva energia/Big Clouds e Mas Tera terra/Small Plants.
Os efeitos existentes no cliente 15.25 ainda dependem de validacao visual em jogo.

## Calibracao recente do Exori com mana potion (2026-10-13)

Esta decisao substitui as calibracoes anteriores de Exori em 60% do Mas Vis.
O custo permanece `max(225, ceil(2.8 * level))`. Para os perfis de referencia,
o dano medio por Exori e calibrado para que o DPS sustentavel seja 90% do DPS
do Mas Tera (ED), exceto no ponto especifico definido pelo usuario: level 300,
skill 100, DPS 144. Considerando mana potion comum ID 268 com recuperacao media
100 por segundo e regeneracao natural: +1/s para ED e +2/6 por segundo para EK.
Mas Tera custa 1200 mana. Assim, `ED DPS = ED dano medio * 101 / 1200`, e
`Exori dano medio alvo = 0.90 * ED DPS * custo Exori / (100 + 2/6)`.
Os fatores de dano sao ancorados nos perfis abaixo e interpolados por level;
skill, ataque da arma e ML do proprio knight seguem contribuindo na formula.
Esse alvo conserva o custo progressivo que limita o EK e corrige o DPS que
caia nos levels maiores. Dano e DPS seguem por alvo; Exori atinge uma area.

| Level | Skill/ML EK | Custo mana | Exori min/medio/max | DPS EK alvo | DPS ED referencia |
|---:|---:|---:|---:|---:|---:|
| 50 | 90/4 | 225 | 62/79/96 | 35.20 | 39.11 |
| 80 | 100/5 | 225 | 84/109/134 | 48.68 | 54.09 |
| 100 | 110/6 | 280 | 127/165/204 | 59.17 | 65.74 |
| 200 | 120/8 | 560 | 406/535/664 | 95.87 | 106.52 |
| 300 | 100/9 | 840 | 911/1206/1500 | 144.00 | 144.80 |
| 400 | 140/10 | 1120 | 1388/1839/2291 | 164.78 | 183.08 |

## MS/EK damage calibration (2026-10-13, supersedes prior Exori damage examples)

Traditional Mas Vis (Rage of the Skies) is explicitly allowed and uses
F = 2*level + 3*ML; min = 2.26*F, max = 3.39*F, mean = 2.825*F.
This is 1.13 times Nostalrius Ultimate Explosion's damage formula. Current
Canary energy type, area, level 55 and mana 600 are preserved. Traditional
attack exhaustion remains 2 seconds; modern retains its original damage.

Traditional Exori multiplies the existing min/max by a level calibration
factor. Reference profiles (level/mage ML/knight skill/knight ML), at weapon
attack 50: 50/45/90/4, 80/55/100/5, 100/65/110/6, 200/80/120/8,
300/90/130/9, 400/100/140/10. Each anchor factor is 0.60 * Mas Vis mean /
previous Exori reference mean. Factors interpolate linearly between anchors;
outside levels 50--400 the nearest endpoint factor is kept. The 60% target
is exact at these reference anchors, approximate between them, and is not a
universal ratio across arbitrary skills, ML, gear or targets. Skill, equipped
weapon attack and the knight's own ML still affect actual Exori damage.
Highest effective melee skill and the 13.08% bonus from skill 100 to 120 remain.
Exori mana remains max(225, ceil(2.8*level)); modern damage is unchanged.
At level 300/skill 130/ML 9/attack 50, Exori mean is 1474.65 and MS at
level 300/ML 90 has mean 2457.75. DPS at an observed 8-second Exori interval
is 184.33 per target; this interval is an observation, not the spell cooldown.

The earlier audit entry excluding Rage of the Skies as a substitute is
superseded by this explicit approval. ED 70% remains a balance target;
ED spells and RP/rune formulas are not changed in this MS/EK update.


## Exori and Stone Shower calibration (2026-10-13)

Traditional Berserk uses the highest effective sword/axe/club skill. Skill
bonus = 0.30 * (min(skill, 90) - 10) and bonus = skill bonus + 0.10 * equipped
weapon attack + 0.10 * ML. Above skill 90, apply skill multiplier =
1 + 0.007 * (skill - 90). Raw damage minimum = (3.12 * level + bonus) * 1.30
* skill multiplier; maximum = (5.20 * level + bonus) * 1.30 * skill multiplier.
At fixed level/ML/weapon, skill 100 to 120 raises damage by 13.08%. The final
1.30 multiplier addresses low sustained Exori DPS while preserving linear
level scaling.
Mana cost = max(225, ceil(2.8 * level)), checked and charged centrally by getManaCost;
modern Berserk retains its original formula and 115 mana definition.
Traditional mode removes the explicit level requirement through getLevel;
the equipped weapon requirement remains. The 225 mana floor matches the
project's Knight Sample at level 35 (90 mana at level 8, +5 per level).
The floor applies through level 80; level 81 costs 227 mana. Characters with
extra mana can qualify earlier; eligibility is determined by available mana.
At level 100, skill 90, attack 50 and ML 6, raw damage is 444.08--714.48
and mana cost is 280.

Stone Shower is available in traditional mode and uses the shared area-rune
formula and vocation factors. Its earth element, area and requirements remain.
Modern mode restores its original damage. Shared attack exhaustion remains 2s.
Lua tests cover both modes, highest skill, skill cap, weapon/ML/level scaling,
and all four area runes. Final damage and mana/cooldown displays require an
in-game test before commit/push.

## Configuração

`modernCombatSystem = true` mantém as regras existentes. `false` aplica as
restrições tradicionais deste documento. O padrão é `true`; a configuração local
está em `false`. A chave é lida na inicialização: mudar o arquivo e executar
reload não troca o modo. É necessário um reinício controlado do servidor.

O executável antigo não reconhece essa chave; é necessário compilar o código
alterado. O cliente continua usando o protocolo atual. Essa opção não converte
o servidor inteiro, o mapa ou as fórmulas de dano para Tibia 7.4.

## Cooldown e magias

Todas as magias e runas permitidas compartilham uma exaustao determinada pela
ultima acao: cura/UH (grupo healing) aplica 1000 ms; ataque, suporte, conjuracao
e comandos de casa aplicam 2000 ms. Depois de um uso bem-sucedido, as tres
condicoes padrao de grupo e a condicao individual recebem a mesma duracao.
Exemplo: ataque -> 2s -> cura/UH -> 1s -> ataque. Nao sao grupos independentes.
As condições de grupo também atualizam os indicadores do cliente. Taxa de
cooldown, equipamento, Momentum, roda e limpeza de cooldown não reduzem esse
intervalo no modo tradicional. Falhas não consomem a nova condição.

Fix em 12/10/2026: a implementacao usava 2000 ms tambem para cura/UH. A politica
central agora seleciona a duracao pelo grupo da magia e e usada tanto nas
condicoes do servidor quanto nos getters de cooldown. Formulas e definicoes
modernas permanecem preservadas. Referencia: o Nostalrius aplica a mesma condicao
EXHAUST por 2000 ms apos acoes agressivas e 1000 ms apos nao agressivas, salvo
override especifico: [spells.cpp](https://github.com/Ezzz-dev/Nostalrius/blob/master/src/spells.cpp).
Nesta customizacao, suporte permanece em 2000 ms; a mudanca autorizada abrange
cura e runas de cura. Teste de politica verifica 1000/2000 ms; sequencias e
indicadores visuais ainda precisam de reteste em jogo.

A política está em `src/creatures/combat/combat_mode.hpp`. O bloqueio ocorre
antes do privilégio IgnoreSpellCheck. Os registros Lua originais permanecem
intactos: reiniciar em modo moderno restaura disponibilidade e cooldowns.
`canCast`, `isEnabled`, a lista Lua usada pelo spellbook e a lista enviada ao
cliente aplicam a mesma restrição.

### Auditoria da lista

Referência histórica: [catálogo Avesta 7.4/7.6/7.7](https://github.com/peonso/avesta74/blob/master/data/spells/spells.xml),
comparado com os nomes registrados em `data/scripts/spells` e `data/scripts/runes`.
A lista é uma seleção conservadora das correspondências existentes, não uma
reimplementação completa do catálogo histórico. Nomes são comparados por
igualdade completa sem distinguir maiúsculas e minúsculas.

Correspondências de nome incluem Antidote → Cure Poison; Invisible →
Invisibility; Conjure Poison Arrow → Conjure Poisoned Arrow; nomes de runas
passam a incluir o sufixo Rune. O Energy Wave conserva a implementação atual,
cuja fórmula verbal mudou. Custos, vocações, níveis, cargas e efeitos existentes
continuam como no Canary, exceto o cooldown e as formulas tradicionais de UH,
GFB, Avalanche e Thunderstorm descritas neste documento.

Não são liberadas automaticamente versões modernas de magias históricas com
efeitos diferentes: Death Strike não substitui Force Strike; Rage of the Skies
não substitui Ultimate Explosion; Stalagmite não substitui Envenom; Wild Growth
Rune não substitui a antiga magia instantânea Wild Growth. Essas correspondências
exigem uma decisão posterior. Poison Storm e Undead Legion não têm implementação
equivalente entre as magias instantâneas importadas. Magias não listadas ficam
bloqueadas, incluindo strikes modernos, familiares e magias Monk. Avalanche e
Thunderstorm foram liberadas por decisao explicita do usuario em 12/10/2026.

## Monk e personagens

As vocações 9 (Monk) e 10 (Exalted Monk) permanecem no banco e na lista da conta.
O preload lê o ID da vocação e o protocolo rejeita o login com mensagem antes
de `loadPlayerById` e `placeCreature`. Reconexões são verificadas novamente.
Nenhum DELETE, UPDATE ou conversão de personagem é necessário.

## Itens e NPCs

Uso normal e uso em alvo/hotkey verificam a mesma política central. São bloqueados
os IDs de poções de cura, mistas, mana superior e o dispenser aleatório:
236, 237, 238, 239, 266, 6558, 7642, 7643, 7876, 23373, 23374, 23375.
Comidas de recuperação imediata de vida/mana bloqueadas:
9079, 9086, 11586, 11587, 28484, 28485, 29414, 29415.

Mana potion comum (268) mantém a exaustão existente de itens; não recebe o
cooldown de magias. Comidas comuns mantêm a regeneração. Poções de atributos,
antídoto e comidas sem recuperação imediata não estão no bloqueio solicitado.

A janela de comércio recebe uma cópia filtrada. Compra, venda e venda em lote
também verificam a política, incluindo pacotes enviados diretamente pelo cliente.
Os catálogos originais não são removidos; o modo moderno restaura o comércio.

## UH: referências e fórmula selecionada

Consulta em 12/10/2026. `L` é level e `ML` é magic level.

| Base | Fórmula encontrada | Observação |
| --- | --- | --- |
| [Avesta 7.4/7.6](https://github.com/peonso/avesta74/blob/master/data/spells/scripts/healing/ultimate_healing_rune.lua) | mínimo = max(250, 2,1 × (2L + 3ML)); máximo = 2,5 × (2L + 3ML) | O código histórico pode produzir mínimo maior que máximo em níveis baixos; não copiar sem corrigir e aprovar. |
| [Nostalrius UH](https://github.com/Ezzz-dev/Nostalrius/blob/master/data/spells/scripts/runes/ultimate%20healing.lua) e [helper](https://github.com/Ezzz-dev/Nostalrius/blob/master/data/spells/lib/spells.lua) | mínimo = máximo = 2,5 × max(100, 2L + 3ML) | Piso 250, resultado fixo antes de modificadores do combate. A base é 7.7 e está arquivada; não é prova oficial da fórmula da CipSoft 7.4. |
| [Nekiro TFS 1.5, 7.72](https://github.com/nekiro/TFS-1.5-Downgrades/blob/7.72/data/spells/scripts/runes/ultimate_healing_rune.lua) | mínimo = L/5 + 7,3ML + 42; máximo = L/5 + 12,4ML + 90 | Coincide com a fórmula atual importada do Canary; protocolo antigo não garante fórmula antiga. |

A referência mais recente [TVP develop](https://github.com/TVPV8/TVP/blob/4fbdacb2c226d58483f5d18d650ad0ab56ee9809/gameserver/data/scripts/spells/runes/ultimate_healing_rune.lua)
chama `computeHealing(250, 0, true)`. O helper não foi localizado nos arquivos
de implementação consultados; essa chamada isolada não basta para afirmar a
equação completa. Não foi compilado nem executado nenhum projeto externo.

O usuário selecionou Nostalrius: mínimo = máximo = 2,5 × max(100, 2L + 3ML).
O callback da UH aplica essa equação somente no modo tradicional; o modo moderno
conserva a fórmula original. A cura base é fixa; modificadores existentes do
combate (equipamentos, roda e outros buffs) ainda podem afetar a cura final.

## Validação

- Teste `tests/unit/game/combat_mode_test.cpp`: restauração de todos os IDs de
  itens/vocações no modo moderno; bloqueio dos dois Monks; mana/comida comum;
  rejeição de nomes modernos, prefixos e entradas desconhecidas.
- Teste Lua `tests/lua/traditional_uh_test.lua`: executa o callback real da UH
  com stubs de registro, validando piso, scaling, restauração moderna e ciclos
  entre os dois valores da configuração.
- Execução isolada sem GTest: compilar esse teste com `COMBAT_MODE_STANDALONE`,
  C++20 e include path `src`. As assertions devem ficar habilitadas.
- Compilar o servidor pelo preset `windows-release`, conforme
  `docs/building/local-validation.md`, e conferir dependências Ninja.
- Validação em jogo ainda necessária: tentativa de ataque/cura/suporte/runa
  antes e depois de 2000 ms; potion durante exaustão de magia; listas do cliente;
  compra via janela/pacote; login das duas vocações nos dois modos; ciclos
  moderno → tradicional → moderno com reinício e sem alteração do banco.
- Conferir os valores recebidos pelo cliente, inclusive qualquer bot que tenha
  catálogo de magias próprio: enforcement do servidor é independente desse catálogo.

Nenhum servidor em execução foi reiniciado para validar esta alteração.

### Resultado local em 12/10/2026

- Build `windows-release` concluída com MSVC/Ninja; execução incremental final
  sem trabalho pendente. Dependências de spells, protocolo e actions registram
  `combat_mode.hpp` com status VALID.
- Teste de política compilado com MSVC C++20 e executado com assertions: passou.
- Teste do callback real da UH executado com LuaJIT: passou.
- Executável gerado: `canary.exe`. O executável anterior foi preservado em backup.
- O cache importado foi preservado em `build/windows-release.imported`; o preset
  local reutilizou suas dependências já instaladas, sem downloads de pacotes.
- Testes GTest completos e validação em jogo não foram executados.
- Nenhum banco foi alterado e nenhum processo do servidor original foi reiniciado.

### Correção do primeiro teste em jogo

- GFB (3191, great fireball rune) é permitida em ambos os modos e tem teste de regressão específico.
- Avisos de item bloqueado agora identificam nome/ID e são enviados uma vez por item durante a vida da instância Player. Tentativas seguintes continuam bloqueadas, mas não renovam o aviso do cliente. A mensagem permite identificar qual item ou hotkey está realmente sendo recusado.
- A actionbar do OTClient aplica cooldown de grupo também às runas. Pacotes genéricos de uso de itens não encurtam nem reiniciam um cooldown mais longo já ativo; uma extensão substitui o evento antigo de remoção.
- Teste Lua `custom/otclient/tests/lua/actionbar_cooldown_test.lua` cobre GFB/UH, ordenação de pacotes, extensão de timer e independência da mana potion.
- Aplicação: usar o novo executável Canary e atualizar o arquivo Lua da actionbar no cliente em uso, reiniciando o cliente. A retestagem visual em jogo continua necessária.

O executável desta correção é gerado em `build/windows-release/bin/canary.exe`
com a opção mantida `TOGGLE_BIN_FOLDER=ON`, pois o executável da raiz está em uso
pelo teste. É necessário encerrar o servidor de forma controlada e iniciar o
novo executável com `custom/canary` como diretório de trabalho; o cliente em uso
também precisa ser reiniciado para carregar a actionbar corrigida.

### Area rune damage calibration (2026-10-12)

User-approved traditional exceptions: Avalanche (3161) and Thunderstorm (3202)
are available alongside Great Fireball (3191), with the shared 2000 ms exhaustion.
These three runes share `getTraditionalAreaRuneDamage` in
`data/libs/functions/combat.lua`: base = 2 * level + 3 * effective magic level;
minimum = base * 0.35 * class factor; maximum = base * 0.65 * class factor.
Factors: Sorcerer/Druid 1.00, Paladin 0.75, Knight 0.60. Base vocation IDs cover
promotions. The callback returns negative values for damage; integer conversion
and subsequent combat modifiers remain handled by the engine.

Each caster uses their own ML. The calibration targets RP around half the mage
damage and EK around 30% below RP, rather than exactly those percentages for
arbitrary character skills. With the agreed example MLs at levels 50 through 400,
RP ranges from 43.4% to 61.1% of mage damage, and EK from 34.1% to 25.9% below RP.
All three retain their original element, area, requirements and modern formula.
This is a custom balance choice, not a claim of historical 7.4 availability.

Validation: `tests/lua/traditional_area_runes_test.lua` executes the three real
callbacks and shared library, checking class factors, own level/ML scaling,
mode cycles and restoration of the original modern formulas. The C++ policy
test checks availability of both newly allowed runes. In-game testing remains
necessary for final damage after target resistance and other combat modifiers.

Local validation completed: LuaJIT area rune, UH and client actionbar tests passed;
standalone MSVC policy assertions and the `windows-release` build passed.
The executable was installed at `custom/canary/canary.exe` after a verified backup
and graceful shutdown/save. Restart from `custom/canary` confirmed server online
with `modernCombatSystem = false` and no Lua loading errors. Full GTest and
in-game damage/element/cooldown verification were not performed.

### Movimento com paralyze

No modo tradicional, runas de ataque e cura ignoram apenas a exaustão de passo
do paralyze nos cinco pontos de entrada/execução do uso de itens. O personagem
continua lento, e alcance, alvo, paredes, custos e cooldown de combate permanecem
validados. A exaustão de itens/poções e o comportamento do modo moderno são preservados.
O teste de política cobre a separação para runas e a preservação dos demais itens.
# Traditional ultimate spells: mana and ED damage

Rage of the Skies and Wrath of Nature cost a fixed 1200 mana in traditional mode, without Wheel mana discounts. Wrath of Nature is available through the central spell policy. For equal level and magic level its damage limits are 70% of Rage of the Skies: minimum `1.582 * (2L + 3ML)`, maximum `2.373 * (2L + 3ML)`. This applies to Mas Tera only; other ED spells have not been rebalanced. Modern damage, availability and registered mana costs (600/700) are preserved.

## SD tradicional: formula e efeito antigo (2026-10-14)

Somente no modo tradicional, Sudden Death usa dano fisico e a formula do
[Nostalrius](https://github.com/Ezzz-dev/Nostalrius/blob/master/data/spells/scripts/runes/sudden%20death.lua):
base = 2 * level + 3 * ML efetiva; minimo = 1.30 * base; maximo = 1.70 * base.
Knight e Elite Knight recebem fator 0.30 sobre ambos os limites. A ML e a do
personagem, sem substituicao, piso ou teto de ML 15. Os requisitos existentes
da runa permanecem (level 45 e ML 15); a formula nao concede acesso a runa.
Exemplo EK level 300/ML 15: 251.55-328.95 (media teorica 290.25).
Como no script de referencia, o tipo fisico nao ativa bloqueio por armor/shield
no Combat; protecoes percentuais fisicas continuam seguindo o motor normal.

O impacto usa efeito novo 352 com sprites novos 290344-290351 no cliente 15.25.
Sao os oito sprites originais 3244-3251 de Tibia 7.60, confirmados contra
effect_18.otobj. Duracao: oito quadros de 100 ms (800 ms). Efeitos existentes,
incluindo GFB/Mas Vis e o efeito moderno 18, foram preservados byte a byte.
O projetil atual permanece; esta importacao trata somente do impacto.
A ferramenta otclient/tools/import_legacy_sd_effect.py importa a partir de
Tibia.spr e verifica os quadros contra o objeto exportado, alocando IDs livres.

Modo moderno conserva formula, elemento e efeito anteriores. Validacao:
tests/lua/traditional_sd_test.lua executa o callback real nos dois modos.
Instalacao dos assets e Lua no repositorio ativo nao recarrega processos ja
abertos: reiniciar Canary de forma controlada e reiniciar o OTClient antes do
teste visual. Sem commit ate o usuario testar e confirmar.

### SD: projétil antigo (substitui a preservação do projétil acima)
O projétil tradicional passa do moderno 32 para o novo ID 69. A origem é
missile_11.otobj / CONST_ANI_DEATH da versão 760: sprite 3252 nos oito
padrões direcionais e imagem vazia no padrão central. Verificado contra
Tibia.spr. Os novos sprites são 290488-290496; patterns 3x3, uma fase.
Ferramenta: otclient/tools/import_legacy_sd_missile.py. O catálogo ativo
inclui tanto o impacto 352 quanto o projétil 69. Nenhum missile antigo foi
substituído, e no modo moderno a SD conserva CONST_ANI_SUDDENDEATH (32).
Teste Lua valida a seleção do projétil nos dois modos; teste visual pendente.

## Explosion tradicional (2026-10-14)
Minimo = 0.20 * (2L + 3ML); maximo = 2L + 3ML, sem fator de classe. Moderno preservado. Efeito exclusivo 353, derivado do Mas Vis antigo 351 com 15 fases e duracao total 800 ms (53/54 ms por fase). Reutiliza sprites existentes sem substituir IDs. Area, projetil, requisitos, cooldown e bloqueio por armadura preservados. Sem commit; teste no jogo pendente.

Explosion: projetil tradicional corrigido para ID novo 70, importado do missile 4 (CONST_ANI_FIRE) da versao 760, sprites originais 1830-1837. Sprites novos 290632-290640, centro transparente. Moderno mantem CONST_ANI_EXPLOSION. Referencia: Nostalrius data/spells/scripts/runes/explosion.lua. Sem commit; reiniciar Canary e cliente para testar.


## IH, HMM and single-target strikes (2026-10-14)

Only traditional mode changes. For P = max(100, 2 * level + 3 * effective ML):
- IH healing: minimum 0.40 * P, maximum P (base 70 +/- 30).
- HMM energy damage: minimum 0.20 * P, maximum 0.40 * P (base 30 +/- 10).
- Exori Vis/Mort/Flam: multiply BOTH current Canary bounds by 0.80.
  Minimum = 0.80 * (level/5 + 1.403*ML + 8).
  Maximum = 0.80 * (level/5 + 2.203*ML + 13).
  This does not modify the Knight's Berserk/Exori formula.

Sources: OTHire commit 43d3b1f3c83675451756d3e20064f1476e3ac7d0 for
classic bounds and floors; Nostalrius data/spells/scripts/runes/heavy magic
missile.lua for the HMM visual (energy projectile + explosion hit).
OTHire has a different fire projectile; the chosen Nostalrius visual combines
the legacy blue energy projectile and fiery impact while keeping energy damage.
No class multiplier was added to IH/HMM. Modern formulas/visuals, vocations,
levels, ML requirements, rune charges, mana, range and cooldowns remain as before.
Mort retains Canary's death damage type; the requested change is visual only.

| Action | Traditional impact | Traditional projectile |
| --- | --- | --- |
| Exori Vis | 354: legacy 760 effect 11, 8 x 100 ms | 71: legacy missile 5 |
| Exori Mort | 352: previously imported legacy effect 18 | 69: legacy missile 11 |
| Exori Flam | 356: copy of custom GFB effect 350, 15 frames, 800 ms | 70: legacy missile 4 |
| HMM | 355: legacy effect 6, 6 x 100 ms | 71: legacy missile 5 |

New sprites 290776-290798 match the visible pixels of Tibia.spr 760.
Existing client effects and missiles were retained byte-for-byte. Server
appearances.dat receives only missing effect/missile records; existing items,
outfits and visuals are retained. The active client catalog and Git exceptions
include the new appearance and sheet. Importer: otclient/tools/import_legacy_strikes.py.

Test: tests/lua/traditional_ih_hmm_strikes_test.lua checks real callbacks in
both modes, the low-level floors, effective ML profiles, visual selection,
single combat execution and original metadata. Visual gameplay test pending;
restart Canary and OTClient to load these files. No commit until user testing.
At level 50/ML45, Exori's reduced mean is 81.31 vs old HMM 70.5; the chosen
20% reduction does not make HMM stronger at every level/ML combination.

Exori Mort: Death Strike explicitly added to the central traditional allowlist; existing vocation restrictions retained. Requires updated executable.

### HMM visual correction (2026-10-14)
User correction supersedes the previous HMM visual: traditional HMM now uses legacy fire projectile 70 (missile 4/760) and new shock effect 357 (effect 12/760). Original sprites 330/331, original four-frame sequence [330, 331, 330, 331], 100 ms per phase, 400 ms total. New sprites 290920-290923. Formula, energy damage and modern behavior unchanged. Client/server metadata synchronized; no commit. Restart Canary and OTClient to test.

HMM impact correction: traditional HMM retains shock effect 357 and fire projectile 70, and adds GFB explosion effect 350 on the same target tile via CALLBACK_PARAM_TARGETCREATURE. Visual overlay only: one combat execution, no second damage instance or additional area damage. Modern mode unchanged. Server metadata now registers effect 350 too. Lua tests cover combined visuals and no extra damage/mode leakage. No commit; restart Canary to load Lua/server metadata.

### Rookie XP, waves and client defaults (2026-10-14)
- Stamina XP and low-level XP bonuses apply only at level < 8 OR vocation 0. Other characters use 100% stamina XP, do not consume stamina on kills, and retain loot/XP even with previously depleted stamina. Stored stamina hours are preserved. Server getters enforce the displayed values; skills/Cyclopedia use the same policy.
- Traditional Summon Creature is nonaggressive and trims its monster parameter. Summonability, mana, room and two-summon limits remain enforced. Usage: utevo res "Monk" (requires the existing level/vocation and monster mana cost).
- Traditional waves: P=max(100,2*level+3*effectiveML). Energy Wave bounds=P..2P; Fire Wave=.2P...4P. Nostalrius provides coefficients; OTHire supplies the historical floor. Modern formulas, spell mana and requirements remain unchanged. No flying missile for either traditional wave.
- Nostalrius sources: https://github.com/Ezzz-dev/Nostalrius/blob/master/data/spells/scripts/spells/energy%20wave.lua and fire%20wave.lua. Floor reference: https://github.com/Ezzz-dev/OTHire/commit/43d3b1f3c83675451756d3e20064f1476e3ac7d0.
- Legacy wave effects appended as 358 (760 effect 11, 8 frames/800ms) and 359 (760 effect 16, 5 frames/500ms); existing appearance IDs preserved. Importer: otclient/tools/import_legacy_waves.py.
- Empty Ctrl+K placeholders no longer remove actionbar hotkeys. Missing F1-F12 defaults restored for first bar, respecting existing actions, occupied keys and deliberate clearing. F10 button IDs remain strings to avoid clearing F1.
- HUD minimap indexes bundled map imagery for floors 0-15 at login and enables static minimap rendering. Textures load lazily. Cyclopedia preserves the shared floor index. This reveals bundled map graphics, not server tile/pathfinding knowledge or custom areas missing from the bundled maps.
- Validation: 312 spell scripts syntax checked; real wave/summon callbacks and rookie XP tests pass; existing IH/HMM/SD/UH/area-rune/Exori tests pass; actionbar cooldown and client-default regression tests pass. Gameplay/visual validation remains with the user; no commit or push.