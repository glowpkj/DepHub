# Blox Fruits — mapa de gaps (Etapa 2)

Estado do backend Blox Fruits contra o plano de evolução (§2–§11).
Legenda: **Impl** = implementada (mecanismo real existe) ·
**Auto** = testada automaticamente (suite headless) · **Game** = testada in-game ·
**Gap** = falta configuração/controle para algo que o plano pede ·
**N/A** = não implementável de forma confiável (motivo registrado).

Como o painel se monta: o módulo OSS chama `UI.toggle/slider/dropdown/button`
→ `ui-headless.register` grava em `page.controls` → backend
(`bloxfruits.lua` `applySea`) renderiza cada definição no painel. O getter de
cada definição lê o estado vivo, então **tudo que é registrado já entra no
Save/Load** (via `Core.gatherConfig`). Adicionar config = adicionar a chamada
`UI.*` com callback que muta o estado e getter que o lê.

---

## 2. FARM (prioridade máxima)

Arquivo: `src/games/features/bloxfruits/oss/farm.lua`
Controles atuais: `buildFarm` (linhas ~655–708), 3 páginas (Farm/Farm 2/Farm 3).

### Configurações gerais
| Pedido no plano | Estado | Onde / nota |
|---|---|---|
| Método de movimentação | **Impl** | só tween-fly (`teleport.go`); não há escolha |
| Distância desejada do NPC | **Impl** Auto | slider "Approach distance" → `hoverRange` (30–600) |
| Altura de posicionamento | **Impl** Auto | `heightOffset` (slider 0–40) |
| Velocidade de movimentação | **Impl** | `teleport.config.speed`, sem controle no Farm |
| Intervalo de atualização | **Gap** | `questInterval` está declarado mas **nunca é lido** (config morta) — não virou controle |
| Intervalo de ataque | **Impl** Auto | slider "Attack interval" → `attackInterval` (0.05–2s) |
| Alcance de detecção | **Impl** | usa `combat.config.range` (slider "Attack range") |
| Alcance de ataque | **Impl** Auto | slider "Attack range" 1–300 → `combat.config.range` |
| Comportamento ao perder alvo | **Impl** | `_farmStep` retargeta (nearest/spawn); não precisa de controle |
| Comportamento ao morrer | **Impl** | loop `if not h then return end` idles; sem controle (sem alternativa real) |
| Retomada após respawn | **Impl** | retoma sozinho quando `hrp()` volta + watchdog reinicia loop >4s |
| Evitar ficar preso | **Impl** | RenderStepped: `Anchored=false` + `AssemblyLinearVelocity=0` por frame |

> Nota: `ui-headless` `UI.slider` arredondava **todo** valor para inteiro, o que
> tornava inalcançável a faixa fracionária (ex.: 0.05–2s). Corrigido: só arredonda
> quando min/max são inteiros, preservando precisão em sliders fracionários.

### Sistemas de farm
| Pedido | Estado | Nota |
|---|---|---|
| Auto Level Farm | **Impl** Auto | `setFarm` |
| Farm Nearest | **Impl** Auto | `setNearestFarm` |
| Auto Next Island | **Impl** | `setAutoNextIsland` |
| Farm Boss | **Impl** Auto | `setBossFarm` + dropdown de boss |
| Material Farm | **Impl** Auto | `setMaterialFarm` + dropdown |
| Auto Saber | **Impl** | toggle em `buildFarm` |
| Farm de maestria | **Gap** | não existe |
| Farm de frutas | **Impl** | coleta de frutas no `_farmStep` (sem config) |
| Farm de espadas / armas | **Gap** | não existe (Sword/Gun só como equipType) |

### Combate durante o farm
| Pedido | Estado | Nota |
|---|---|---|
| Escolher arma | **Impl** | `equipType` (Melee/Sword/Gun/Fruit) |
| Tipo de arma | **Impl** | mesmo dropdown |
| Selecionar habilidades | **Gap** | skills ficam no Combat, sem seleção por farm |
| Configurar teclas | **Impl** | `combat.config.keys` (no PVP) |
| Intervalo entre habilidades | **Impl** | `combat.config.clickInterval` (no PVP) |
| Alternância automática de armas | **Gap** | não existe |
| Configuração de alcance | **Impl** Auto | "Attack range" |
| Básico vs habilidades | **Gap** | usa o que o Combat tiver ligado |

### NPCs
| Pedido | Estado | Nota |
|---|---|---|
| Seleção de NPC/quest | **Impl** | dropdown "Quest" |
| Seleção de ilha | **Impl** | via teleport (islands); sem dropdown no Farm |
| Prioridade de alvo | **Gap** | sempre o mais próximo do tipo |
| Distância máx. p/ achar NPC | **Impl** | `hoverRange` (sem controle) |
| Agrupamento | **Impl** | `bring` toggle |
| Bring Mob | **Impl** Auto | `bring` |
| Máx. de NPCs processados | **Gap** | processa 1 por tick |

### Atributos
| Pedido | Estado | Nota |
|---|---|---|
| Seleção de atributo | **Impl** Auto | dropdown "Stat" |
| Quantidade por distribuição | **Impl** Auto | slider "Amount" 1–100 |
| Distribuição automática | **Impl** Auto | "Auto add points" |
| Limite de pontos | **Gap** | sem alvo máximo |
| Parar ao atingir o valor | **Gap** | não existe |

**Resumo Farm:** a rodada fechou os gaps de config de risco baixo — `hoverRange`
("Approach distance") e `attackInterval` ("Attack interval") viraram sliders reais
com testes de ida-e-volta (chegam ao `M.config` e ao Save/Load). Perder alvo,
morrer e retomar após respawn **já eram** comportamento real do loop, então não
ganharam controle (não há alternativa sensata a expor). `questInterval` é config
morta (nunca lida) e ficou sem controle — não vou fingir que funciona. Gaps de
sistema (maestria, espadas/armas, prioridade de alvo, alternância de armas,
limite de pontos) seguem pendentes para depois do básico validado.

---

## 3. PVP

Arquivo: `combat.lua`. Já existe base ampla: `range`, `delay`,
`targetPlayers`/`playerRange`, `auraRange`, `losCheck`, `aimSmooth`,
`clickInterval`, `keys{Z,X,C,V,F}`, `followDist`, `attack1v1`, `bounty{...}`.

| Pedido | Estado | Nota |
|---|---|---|
| Auto Attack: alcance/intervalo/arma/habilidades | **Impl** | `range`,`delay`,`clickInterval`,`keys` |
| Auto Attack: atacar durante o farm | **Impl** | `combat.attackOnce` usado pelo farm |
| Kill Aura: alcance / LOS / intervalo | **Impl** | `auraRange`,`losCheck`,`delay` |
| Kill Aura: seleção/prioridade de alvos | **Parcial** | `targetPlayers` mas sem filtros |
| Aimbot: suavidade | **Impl** | `aimSmooth` (slider) |
| Aimbot: alcance máximo | **Impl** Auto | slider "Aimbot range" → `aimRange` (20–1000) |
| Aimbot: parte do corpo | **Impl** Auto | dropdown "Aim part" → `aimPart` (Root/Head/Upper/LowerTorso) |
| Aimbot: ativação por tecla | **Gap** | ainda só toggle (`aim`); sem bind de tecla |
| Auto Skills: teclas / intervalo | **Impl** | `keys` + `clickInterval` |
| Auto Skills: ordem de execução | **Impl** Auto | textbox "Skill order" → `skillOrder`; **bug corrigido**: era `pairs()` (ordem aleatória), agora segue a sequência |
| Auto Bounty: equipes / método / ignorar amigos | **Impl** | `bounty.noFriends`,`bounty.safePct`,`bounty.method`,`bounty.team` |
| Auto Bounty: mensagem / tempo máx / retirada | **Impl** | `bounty.chatKill`,`chatMsg`,`maxTime` |
| Auto Bounty: lista personalizada de ignorados | **Impl** Auto | textbox "Ignore players" → `bounty.ignore` (nome ou display, vírgula/espaço) |
| Follow Nearest / Spectate / No Stun / 1v1 | **Impl** | `followDist`, `attack1v1`, etc. |
| Invisible from Ken | **Impl** | `bounty.invisKen`|

**Resumo PVP:** a rodada fechou lista de ignorados (bounty), alcance e parte do
corpo do aimbot e a ordem de skills — e corrigiu um bug real (a rotação de skills
saía em ordem aleatória por usar `pairs()`). Único gap de PVP restante: **bind de
tecla do aimbot** (hoje só toggle) — exige hook de `UserInputService` que ainda
não existe no módulo; fica pendente até haver mecanismo.

---

## 4. FRUITS

Arquivo: `fruits.lua`. Config atual: `chestCooldown`, `randomCooldown`,
`storePoll`, `storeHandPoll`; lista `FRUITS`.

| Pedido | Estado | Nota |
|---|---|---|
| Fruit ESP (nome/dist/filtros) | **Parcial** | há finder/teleport; falta ESP com filtros |
| Coleta automática (dist/frutas/ignorar) | **Parcial** | coleta existe (via farm); sem seleção de frutas |
| Fruit Store (auto armazenar/exceções) | **Gap** | há poll (`storePoll`) mas sem config de quais |
| Fruit Snipe | **Gap** | não existe |
| Auto Random Fruit (intervalo/limite) | **Impl** | `randomCooldown`; sem limite de dinheiro |
| Chest ESP / Chest Farm | **Gap** | não existe |

**Resumo Fruits:** aqui há os maiores gaps reais. ESP/Store/Snipe/Chest são
features inteiras, não só config — tratar como trabalho de sistema, não inventar
controle sem mecanismo.

---

## 5. RAIDS / EVENTS

Arquivo: `events.lua`. `config.element`; `raidLoc` por sea; `serverHop`.

| Pedido | Estado | Nota |
|---|---|---|
| Auto Raid: elemento / iniciar / skills / distância | **Parcial** | `element` só; skills via Combat |
| Auto Raid: intervalo / condições / recursos | **Gap** | sem verificação de recursos/beleza |
| Eventos: seleção / filtros / prioridade | **Gap** | eventos fixos, sem seleção |
| Eventos: teleporte / intervalo de verificação | **Parcial** | teleporta; sem intervalo config |
| Elite Hunter / Leviathan / Server Hop | **Impl** | controles existem (Elite/Leviathan sea-scoped) |

---

## 6. PLAYER

Arquivo: `player.lua`. Config: `noclip`, `walkWater`, `speedOn`,
`walkSpeed`, `jumpOn`, `jumpPower`, `ken`, `buso`, `antiAfk`.

| Pedido | Estado | Nota |
|---|---|---|
| ESP (dist/nome/filtros) | **Parcial** | `_esp` existe; `_espOn`; sem filtros |
| WalkSpeed / JumpPower | **Impl** | sliders existem |
| Presets de movimento / restaurar | **Gap** | não há preset nem restore |
| NoClip / Walk on Water / Auto Ken / Buso / Anti-AFK | **Impl** | todos presentes |

---

## 7. TELEPORT / SEA

Arquivo: `teleport.lua`. `config.speed`; `islands`, `waypoints`.

| Pedido | Estado | Nota |
|---|---|---|
| Favoritos / waypoints personalizados | **Gap** | o plano diz que waypoints aparecem soltos no menu `/` |
| Organização por categoria | **Gap** | islands e waypoints misturados |
| Pesquisa de destinos | **Gap** | sem busca |
| Histórico de teleporte | **Gap** | não existe |
| Velocidade / cancelar / destino inválido | **Parcial** | `speed`; sem cancel/validação visível |
| Organização por Sea / infos | **Parcial** | listas por sea, sem info por destino |

---

## 8. SHOP

Arquivo: `shop.lua`. `buy(action,arg)`; dealers por sea; auto-buy swords
(Rengoku/Oroshi/Shizu).

| Pedido | Estado | Nota |
|---|---|---|
| Separar por categoria / filtros / busca | **Gap** | compra por dealer; sem busca |
| Favoritos / compra individual | **Parcial** | há botões de compra |
| Compra automática / verif. dinheiro / requisitos | **Parcial** | auto-buy existe; sem checagem explícita |
| Feedback de compra/falha | **Impl** | `notify` no `buy` |

---

## 9. EXTRAS

Arquivo: `extras.lua` (65 linhas). Race V4, V4 Trial, Race Upgrade/Reroll,
Cake Prince, Rip Indra.

| Pedido | Estado | Nota |
|---|---|---|
| Config própria por sistema | **Gap** | só botões de ação, sem config/condição/status |
| `farmBoss` reusa o farm | **Impl** | liga o Farm Boss com nome |

---

## 10. CONFIG

Arquivo: `core.lua`. `gatherConfig/applyConfig/saveNamedConfig/loadNamedConfig/
listConfigs/unload`; prefixo `DepHub_BF_`; `cfg_<name>.json`; `lastcfg.txt`.

| Pedido | Estado | Nota |
|---|---|---|
| Salvar/Carregar/Criar com nome/Listar | **Impl** | existe |
| Renomear / Excluir | **Gap** | não existe |
| Restaurar padrões | **Gap** | não existe |
| Config por módulo / restaurar só um módulo | **Gap** | config é global |
| Presets (Default/Safe/Fast/Custom) | **Gap** | não existe |

---

## 11. EXPERIÊNCIA DO PAINEL

| Pedido | Estado | Nota |
|---|---|---|
| Seções organizadas / nomes claros | **Impl** | `groupFor`/`sectionFor` agrupam |
| Descrições úteis | **Parcial** | `UI.toggle/slider` têm `desc`; backend não renderiza tooltip |
| Pesquisa de features/config | **Gap** | sem busca no painel |
| Status das automações | **Parcial** | estado no backend; sem linha de status visual |
| Abas organizadas | **Impl** | feitas nesta rodada (sea atual) |

---

## Ordem de execução (a partir daqui)

1. **Farm** (§2): expor `hoverRange`, `questInterval`, `attackInterval`, e um
   alcance de detecção próprio; adicionar comportamento ao perder alvo/morrer
   onde já há gancho. Só depois migrar para os sistemas (maestria/armas).
2. **PVP** (§3): lista de ignorados, parte do corpo + tecla do aimbot, ordem de skills.
3. **Fruits** (§4): maior trabalho — ESP/Store/Chest são features novas.
4. **Events/Player/Teleport/Shop/Extras/Config/Painel** conforme §14.

Cada etapa: suite verde + bundle + validate + bump + commit/push, declarando
**Impl / Auto / Game / Pendente** por funcionalidade.
