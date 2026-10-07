# DepHub

Framework client-side Luau com loader, backends separados por jogo e biblioteca própria de UI.

## Estrutura

- `DepHub.lua`: seleção por PlaceId/GameId, carregamento, estado da sessão e cleanup.
- `src/core`: serviços compartilhados, movimento com owner/prioridade, dashboard e updater.
- `src/games`: APIs dos backends; `features/<jogo>` contém as implementações específicas.
- `library`: componentes, janela com HOME fixa, adaptadores de conteúdo e biblioteca compacta.
- `.github/dephub-games.json`: arquivos que participam do hash de atualização de cada jogo.
- `diagnostics/compatibility.lua`: diagnóstico somente de leitura das dependências já usadas pelos backends.

## Validação

```text
node tests/validate_repo.js
node tests/run_backend_tests.js /caminho/para/luau
node tests/run_library_tests.js /caminho/para/luau
luau-compile --null DepHub.lua <arquivos .lua em src e library>
```

Os testes usam simuladores de APIs Roblox. Eles verificam comportamento local e cleanup, mas não comprovam remotes, física, replicação, timings de ataque ou compatibilidade com Madium.

## Teste no jogo

1. Execute o loader e habilite uma feature de cada vez.
2. Desabilite e habilite novamente; confira se há workers ou interfaces duplicados.
3. Morra, reapareça e repita o teste. Teste também entrada/saída de jogadores e objetos.
4. Reexecute o loader com a sessão saudável e depois com a UI destruída.
5. Se uma feature falhar, execute `diagnostics/compatibility.lua` e envie o JSON junto com o erro e a ação que falhou.

O diagnóstico não chama remotes, não ativa automações e não verifica se o servidor aceita os argumentos existentes. Dependência ausente pode significar mudança no jogo, carregamento incompleto ou contexto incorreto; não se deve inventar uma substituição.

## Versões e origem

A versão global fica em `DepHub.lua` e `src/version.txt`. Backends versionados têm notas em `src/games/updates`. O workflow gera `src/update-manifest.json` com hashes dos arquivos monitorados.

Para testar uma revisão isolada, o launcher pode definir temporariamente `getgenv().__DEPHUB_SOURCE_REF` com um SHA ou branch. Todos os carregadores internos seguem a origem selecionada. O comportamento padrão continua sendo `main`. Use SHA para um teste consistente enquanto o repositório recebe atualizações.

## Alterações em 0.0.29

- Recuperação de sessão com UI/backend destruídos; proteção contra inicializações concorrentes e updater antigo.
- Fallback HTTP sem lacunas na lista de funções, cache por origem e updater com Start idempotente.
- Universal: cancelamento do worker de chat, cleanup por jogador/Character e atualização de ESP a 10 Hz.
- Noob Piece: dependências com timeout, rollback de inicialização e cleanup idempotente.
- MM2: substituição dos listeners de Character/Backpack e agrupamento de pedidos de rescan.
- TSB: recuperação de componentes do oponente por eventos, cleanup na morte local e liberação pareada do contra-ataque.
- RT3: rebind quando DropFolder é substituída e descarte de tarefas de coleta antigas.
- UI compacta: atualização quando a câmera muda e fechamento sem coroutine esperando Tween.Completed.
- Arquivos faltantes adicionados ao controle de atualização; testes e diagnóstico atualizados.

Não foram substituídos protocolos dos jogos nem recalibrados alcance/timings de combate. AutoFarm e InstantCook do RT3 ainda contêm movimentos diretos legados: teste individualmente antes de combinar automações. A integração completa deles com ownership de movimento exige teste real e uma tarefa dedicada.

## TSB em 0.0.30 (backend 0.0.10)

A interface do TSB tem apenas Auto Block. Ele liga os detectores existentes de M1, dash e skills; não dispara contra-ataques. O block não é mais cancelado por clique/estado de M1 local e é renovado enquanto ataques conhecidos permanecem ativos no alcance. M1 usa o alcance configurado sem a caixa adicional que reduzia o limite efetivo à metade. Os tempos e IDs existentes foram mantidos.

Uma ação de ContextActionService com prioridade acima de High retém MouseButton1 enquanto o block está ativo. O M1 já segurado recebe LeftClickRelease antes do pedido de F. Depois da ameaça e do hold existente, o clique passa novamente; nenhum ataque é enfileirado para disparar sozinho. A ação é removida ao desligar/destruir o backend. Se ela não puder ser instalada, a ativação falha.

Limites: KeyPress não é confirmação de defesa pelo servidor. ContextActionService não garante travar scripts de input que ignorem o processamento do Roblox. A trava cobre MouseButton1; teclas de skills, gamepad e botões mobile ainda não foram validados. O catálogo não informa quais skills são unblockable nem o fim exato de cada hitbox; término de animação mais hold existente é somente uma aproximação. Não há garantia de 100% de bloqueio ou de uma janela perfeitamente segura.

Teste em sessão controlada: habilite o único toggle, segure M1 enquanto outro jogador aplica a sequência completa; confirme que não há ataque local durante a defesa e que um novo clique funciona ao terminar. Repita com duas ameaças, dash, morte/respawn, reexecução e toggle desligado. Se M1 ainda sair durante o block, reporte o ataque e o input: isso exige observar o caminho real do jogo, sem inventar hooks ou remotes.

API oficial de input: https://create.roblox.com/docs/reference/engine/classes/ContextActionService
# Volleyball Legends — DepHub 0.0.31

Implementação visual em Luau, integrada ao loader DepHub e à biblioteca compacta existente. Não há Auto Receive, Auto Block, chamadas de remotes ou automação de jogo neste módulo. Backend 0.0.1. Ball ESP, Trajectory Predictor e Debug começam desligados.

## Arquivos

Novos: backend `src/games/volleyballlegends.lua`; módulos `src/games/features/volleyballlegends/ball-detector.lua`, `ball-esp.lua`, `trajectory.lua` e `frontend.lua`; nota `src/games/updates/6931042565.txt`; testes `tests/volleyball_tests.luau`.

Integração: `DepHub.lua`, `src/version.txt`, `.github/dephub-games.json`, `src/update-manifest.json`, `diagnostics/compatibility.lua`, `README.md` e infraestrutura de testes. A UI é `library/compact.lua`, reutilizada sem alterações.

O PlaceId 73956553001240 foi confirmado na página oficial do jogo; a API pública do Roblox confirmou GameId 6931042565. O sufixo de CLIENT_BALL nunca é fixado no código de produção.

## Detecção e seleção

Ao ligar qualquer visual, o detector observa ChildAdded/ChildRemoved do Workspace e faz uma leitura inicial dos filhos diretos. Registra somente nomes com prefixo CLIENT_BALL_. Em cada candidato, procura Cube.001 e exige BasePart. DescendantAdded/DescendantRemoving cobrem streaming e substituição de peças. Duas Cube.001 válidas no mesmo candidato são tratadas como ambiguidade; o detector não escolhe uma delas arbitrariamente.

A seleção compara apenas os candidatos registrados, a 20 Hz. Prefere uma bola em movimento e, dentro desse grupo, a mais próxima do personagem; usa a câmera enquanto o personagem não possui root. Mantém a bola atual quando a distância dela está até 15% acima da melhor alternativa, reduzindo trocas pequenas. Empates usam nome e ordem de registro. Sem referência e com várias bolas, não faz seleção. Isso é uma heurística de relevância local, não uma confirmação do servidor sobre qual bola pertence à partida.

O detector lê AssemblyLinearVelocity e também mede deslocamento entre amostras. Usa o deslocamento quando a peça está ancorada ou sua velocidade física é quase zero. Assim, uma bola movida por CFrame pode ser prevista. Com uma nova peça, espera a segunda amostra para estimar essa velocidade.

## ESP, curva e pouso

O ESP associa Highlight e BillboardGui à Cube.001 selecionada, mostrando BALL e distância em studs. Reutiliza os visuais enquanto acompanha a mesma peça.

A trajetória usa `p(t) = p0 + v0*t + (0, -Workspace.Gravity, 0)*t²/2`. Desenha 40 pontos no horizonte de dois segundos, com atualização máxima de 20 Hz e Parts reutilizadas. Bola ausente ou velocidade abaixo de 0,5 stud/s esconde a curva e não executa os raycasts de previsão.

Cada segmento da curva usa Workspace:Raycast. Exclui todas as CLIENT_BALL registradas, personagens dos jogadores e a pasta visual. Os Parts visuais têm CanCollide/CanTouch/CanQuery desligados. A primeira colisão interrompe a curva; se ocorrer durante descida e a normal da superfície tiver Y ≥ 0,7, aparece um disco indicando possível pouso. Uma parede/rede interrompe a curva sem criar um falso pouso. Sem impacto dentro do horizonte, não inventa um marcador.

Ao desaparecer a bola, os visuais dela são removidos. Ao desligar cada feature, seus visuais são destruídos. Quando ambas estão desligadas, o único Heartbeat compartilhado e todas as conexões do detector são desconectados. Reexecução usa o cleanup do loader; respawn usa a referência atual do personagem.

Debug não cria um worker sozinho. Quando uma feature está ligada, registra troca de bola e alterações de pouso, com resumo limitado a uma vez por segundo. O diagnóstico também informa nome, peça, velocidade, origem da velocidade, seleção e erro atual.

## Limitações

- Não foi executado dentro do Roblox/Madium nesta sessão. Testes locais verificam comportamento estrutural com simuladores de APIs, não renderização real ou física do jogo.
- Gravidade padrão pode divergir de uma simulação customizada da bola. Toques futuros, spins, drag, mudanças de velocidade, correções de rede e quique não são previstos.
- O raycast usa a trajetória do centro, não o volume da bola. O pouso é aproximado; não inclui o raio da bola.
- A primeira superfície física voltada para cima é um possível chão, mas o código não possui metadados de quadra para distinguir mesa, teto ou outra plataforma. Respeita CanCollide e depende de geometria disponível no cliente.
- A seleção entre várias bolas é uma aproximação pela proximidade e movimento. Não existe vínculo confirmado com a partida do jogador.
- Detecção segue os filhos diretos CLIENT_BALL_* descritos no pedido. Mudança da hierarquia ou renomeação posterior de um objeto já existente exige nova evidência.
- Posição amostrada pode refletir correções abruptas e produzir uma previsão transitória incorreta.

## O que testar

1. Abra Volleyball Legends com o loader novo. Confirme Ball ESP, Trajectory Predictor e Debug inicialmente OFF.
2. Ligue Ball ESP durante uma partida e confira Highlight, rótulo e distância na bola correta.
3. Ligue Trajectory Predictor e confira curva em saque, subida, queda e spike. Compare o marcador com o pouso real.
4. Teste bola ancorada movida por CFrame; confira `VelocitySource` no diagnóstico se a curva não aparecer.
5. Termine o ponto e comece outro. Confirme troca automática de CLIENT_BALL e ausência de visuais antigos.
6. Teste várias bolas próximas, lobby e quadras vizinhas. Se selecionar a errada, registre nomes e contexto para identificar um vínculo real de partida.
7. Confira colisões com rede/parede, ausência de falso marcador e previsão sem chão dentro dos dois segundos.
8. Desligue cada visual separadamente, desligue ambos, morra/reapareça e reexecute o loader. Confira que não existem duplicatas ou visuais restantes.
9. Em caso de falha, ative Debug e envie o diagnóstico e o erro do console. Não altere IDs da bola.

Referências oficiais: [Volleyball Legends](https://www.roblox.com/games/73956553001240/Volleyball-Legends), [Raycasting](https://create.roblox.com/docs/workspace/raycasting), [RaycastParams](https://create.roblox.com/docs/reference/engine/datatypes/RaycastParams).

🟢 PODE EXECUTAR: SIM, para teste controlado. A precisão real da trajetória e a seleção da bola precisam ser confirmadas dentro do jogo.

