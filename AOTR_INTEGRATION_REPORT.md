> Revisão 0.0.36 / backend AOTR 0.1.1: Classic Autofarm agora usa noclip restaurável, tween por velocidade e retenção de alvo. Leia AOTR_MOVEMENT_UPDATE.md; as descrições anteriores de BodyPosition e ausência de noclip abaixo são históricas.

> Nota de frontend 0.0.35: AOT:R agora usa exclusivamente Linoria. As referências à interface compacta abaixo descrevem a revisão anterior. O backend AOTR 0.1.0 permanece preservado. Veja LINORIA_MIGRATION_REPORT.md e use o loader da versão 0.0.35 para testar a interface atual.

# DepHub — AOT:R: revisão para testes individuais

Data: 15/10/2026. Branch: `codex/aotr-integration`.
Base desta revisão: `696f106c843745d53d1b294aa20480e4874a6c56`.
Loader: 0.0.34. Backend AOTR: 0.1.0.
Referência: `aotr_corrigido_v3.luau`, 78.690 bytes, analisado por inspeção; nunca executado pelo hub.

## Evidência e significado dos estados

O usuário confirmou que a versão inicial da branch abriu o DepHub dentro do Roblox. Essa evidência confirma a abertura inicial; não confirma cada toggle nem a execução dos novos recursos desta revisão.

Nesta revisão, **implementado** significa lógica real conectada a um controle. **Verificado estaticamente** significa inspeção, compilação e testes com substitutos das APIs Roblox. **Nenhum dos recursos novos foi testado por este agente no Roblox.** Física, replicação, efeitos de habilidades, contratos de remotes e permissões do executor continuam sujeitos aos testes do usuário.

Os diagnósticos usam Disabled, Waiting, Running e Error. Running descreve trabalho local ou solicitação enviada, sem afirmar dano, kill, recarga ou missão concluída. Todos os toggles começam desligados. Após respawn, somente os que o usuário já havia ligado retomam; reiniciar o backend encerra os anteriores e começa com todos desligados.

## Estado real de cada função

| Função | Entrega e limite real |
|---|---|
| Titan ESP | Implementado e preservado. Um Highlight próprio por Titan válido; não remove Highlights de outros scripts. Sem teste novo no jogo. |
| Nape Visible | Implementado e preservado. Transparência original restaurada; compõe com outros recursos. |
| Nape Extend / multiplicador | Implementado e preservado. Escala relativa ao tamanho original, intervalo 0–2; rejeita NaN/infinito. Zero continua permitido pela interface anterior. |
| Extend Eren Weakpoint | Implementado. Usa somente Marker.Adornee BasePart dentro do Hit do próprio boss. Troca de marcador restaura alvo anterior; prioridade própria sobre extensão comum. |
| Teleport to Refill | Implementado e preservado. Mantém botão de cancelamento, cancela tween anterior e no respawn/unload. Farm aguarda enquanto o tween está Playing. |
| Titan Ripper | Implementado. Detecta efeitos locais Tester_Steel/Thrust/RIP pelo nome real do jogador, amplia efeito e napes comuns por até 2 s, move napes ao efeito e pausa animações. Restaura dimensões, transparência, velocidade exata das animações e posição relativa à cabeça em movimento. Não modifica boss. Efeitos identificados antes de respawn não são reutilizados no novo personagem. Precisa confirmar esses modelos/efeitos na versão atual do jogo. |
| Skill Autofarm | Implementado. Sequência 108 → 14 → 23 → 14, pausas 0,1 / 2,5 / 0,1 / 0,5 s, equipamentos e cooldown checados a cada passo. Slots desconhecidos são pulados com Waiting. Compartilha Ripper com referência de uso própria, sem desligar o toggle independente. A associação de ícones aos IDs é inferida das três habilidades do anexo e precisa de confirmação no jogo; SkillId explícito tem evidência mais forte. Não promete completar missão. |
| Autofarm clássico | Implementado. Seleciona Titan vivo próximo ou weakpoint ativo de boss; usa BodyPosition/BodyGyro próprios, offsets 75/195 e destino limitado por passo; envia Slash e Hitboxes/Register a distância limitada, no máximo uma vez por segundo. Usa velocidade local observada, sem números aleatórios de dano/velocidade. Faz ciclo de Full_Reload Left/Right perto de GasTanks.Refill quando o HUD confirma zero sets; recarga normal com sets disponíveis fica a cargo do toggle Blade Refill. Não apaga mapa, não desativa colisões e não altera BV/BG do jogo. Contratos e movimento precisam de teste real. |
| Check ShadowBan | Consulta assíncrona real GET(Data, Get), botão independente e timeout de 15 s, sem imprimir valores da conta. Respostas nil, inesperadas ou tabelas com nomes blacklist produzem diagnóstico **inconclusivo**. Nenhum resultado definitivo de banimento é implementado: o contrato atual é desconhecido. Isso é uma limitação deliberada, não um placeholder. |
| Auto Grab Escape | Implementado com disparo conservador, mas **contrato de detecção ainda parcial**. Não usa mais qualquer Buttons.ChildAdded. Só solicita Slash_Escape diante de Grabbed/IsGrabbed booleano true no Character ou BoolValue Grabbed true. Um pedido por episódio. Esses indicadores candidatos não foram comprovados pelo anexo; se não existirem no jogo, permanece Waiting e precisa de evidência de runtime para concluir a detecção. Não destrói UI nem dispara ataque adicional. |
| Anti-Injury | Implementado no cliente com restauração recuperável. Retira objetos da pasta mantendo referência, restaura na pasta original ao desligar ou remover Character, não migra lesões para outro personagem e não destrói deliberadamente lesões originais. Objetos/pastas destruídos externamente não podem ser reconstruídos com garantia. Remoção real da lesão no servidor não é comprovada. |
| Blade Refill | Implementado e revisado. Renova Character/Blade/HUD, aceita IFrames=false, respeita sets disponíveis e limite de 30 s de tentativas por episódio. Não falsifica texto do HUD. RPC bloqueada pode manter o worker aguardando até toggle off/respawn; UI permanece independente. |
| Auto Retry | Implementado e revisado. Exige Retry.Title efetivamente visível e formato numérico de votos; ignora STARTING, (0/0) e formatos desconhecidos. Uma solicitação por episódio visível, inclusive diante de erro remoto, sem repetição arbitrária. Texto localizado exige confirmação. |
| Anti-AFK | Implementado e revisado. Conexão própria a Idled, refeita no respawn e encerrada no toggle off/unload. Não desconecta handlers de outros scripts; depende da permissão de VirtualUser. |
| Diagnósticos | Implementado. Identifica revisão do backend, referências, erro recente, estados dos três recursos de combate e resultado da consulta. Prints e dados permanecem locais. |

## Arquitetura e composição de propriedades

- `src/games/features/aotr/properties.lua`: novo registro de propriedades por dono e prioridade. Visual comum tem prioridade 10, Eren 20 e Ripper 30. Desligar um dono reaplica os demais; o último restaura o valor original. Ripper fornece restauração de CFrame relativa à cabeça para acompanhar deslocamento do Titan. Não escreve material ou cor.
- `targets.lua`: novo módulo para saúde, raiz, Titans vivos e validação de Marker.Adornee; boss sem marcador válido não é atacado por fallback arbitrário.
- `movement.lua`: novo componente de movimento. Cria e destrói apenas seus próprios movers e restaura velocidades capturadas. Não altera CanCollide nem objetos BV/BG existentes. Em física real, mola/replicação e autoridade do servidor podem rejeitar o movimento.
- `combat.lua`: novos controladores independentes, uma tarefa por recurso, uso compartilhado do Ripper entre dois donos, tratamento de erro isolado, gestão de respawn e consulta assíncrona. Cancelar encerra espera local; uma mensagem já enviada ao servidor não pode ser desfeita.
- `assistance.lua`: indicadores de grab conservadores; idempotência; cancelamento de jobs no CharacterRemoving e recriação somente de recursos já ligados no CharacterAdded; restauração das lesões; reload e retry sem falsificar interface.
- `src/games/aotr.lua`: fachada existente mantida; integra módulos, propriedades e diagnósticos. Backend anterior é destruído ao reiniciar.
- `frontend.lua`: usa a mesma biblioteca compacta. Mantém Titans, Assistance, Movement e Diagnostics; substitui o aviso de pendências pela seção Combat com três toggles reais e adiciona botão de consulta em Diagnostics. Nenhuma biblioteca nova ou UI Tekkit.

O loader só recebeu versão 0.0.34 e parâmetro de revisão nas URLs de download para invalidar respostas antigas. O roteamento existente por GameId 4658598196 foi preservado. Não foi reescrito e a manutenção do loader principal em main não faz parte desta entrega.

## Arquivos criados ou modificados

Criados:

- src/games/features/aotr/properties.lua
- src/games/features/aotr/targets.lua
- src/games/features/aotr/movement.lua
- src/games/features/aotr/combat.lua
- tests/aotr_combat_tests.luau

Modificados:

- src/games/aotr.lua
- src/games/features/aotr/assistance.lua
- src/games/features/aotr/frontend.lua
- DepHub.lua
- src/version.txt
- .github/dephub-games.json
- src/games/updates/4658598196.txt
- tests/aotr_tests.luau
- tests/headless_tests.luau (somente expectativa de versão)
- tests/run_backend_tests.js
- AOTR_INTEGRATION_REPORT.md

A configuração do manifesto rastreia todos os módulos novos. src/update-manifest.json é gerado pelo workflow de main; não foi alterado manualmente nesta branch. Biblioteca compacta, updater e implementação dos outros jogos permaneceram intactos.

## Erros e comportamentos antigos corrigidos

- Ripper antigo restaurava velocidade de animação fixa 1 e posição estimada Head.Position - (2,5,0). Agora captura velocidade real e transformação relativa; também restaura tamanho do efeito.
- Extensão e Ripper podiam desfazer alterações um do outro. Agora compartilham composição por propriedade, mantendo os toggles independentes.
- Farm antigo destruía Climbable/Unclimbable, reutilizava BV/BG e alterava colisões sem restauração. Esses efeitos foram excluídos; há movimento próprio e limpeza.
- Seleção antiga podia manter nape anterior ou acessar Highlight como Model. A seleção nova é refeita em cada passo, valida modelos vivos e não mantém alvo inválido.
- Skill farm antigo tinha eventos concorrentes e referência única a cooldowns de HUD. Agora há um único worker, sequência com atrasos canceláveis e renovação dos slots.
- Grab antigo disparava em qualquer filho de Buttons. Agora não depende desse evento genérico; falta confirmar o indicador atual do jogo.
- Anti-Injury antigo destruía lesões; a integração inicial ainda destruía referências de personagem anterior. Agora restaura quando recuperável e apenas solta referências irrecuperáveis, registrando limitação.
- Retry podia repetir em estados STARTING ou texto desconhecido. Agora filtra formato e evita duplicação por episódio.
- Check ShadowBan antigo usava pairs em resposta desconhecida e inferia banimento pelo nome de campos. A consulta nova faz validação de tipo e não declara safe/banned.
- Nenhum webhook, coleta de dados, link Discord, ajuste de Atmosphere, persistência Tekkit ou execução do anexo foi importado.

## Dependências e suposições que exigem Roblox

1. Workspace.Titans e modelos com Humanoid vivo; Hitboxes.Hit.Nape; Attack_Titan.Marker.Adornee.
2. Ripper: BaseParts diretamente em Workspace com nomes <jogador>_Steel, _Thrust ou _RIP; Fake.Head para restauração de nape e Animator do Humanoid para velocidade de tracks. Napes sem cabeça válida não são movidas.
3. Skills: PlayerGui.Interface.HUD.Main.Top.7.Hotbar, slots contendo Skill, atributo SkillId ou Inner.Icon, Cooldown como GuiObject. Associações legadas: 108 ↔ ícone 15216496277, 14 ↔ 15215073606, 23 ↔ 15215081865. Precisam de confirmação; slots sem identificação/cooldown não são acionados.
4. Remotes em ReplicatedStorage.Assets.Remotes: GET RemoteFunction e POST RemoteEvent. Contratos usados: S_Skills/Usage/ID; Attacks/Slash/true; Hitboxes/Register/part/velocidade/0; Blades/Reload; Blades/Full_Reload/Left ou Right/refill; Functions/Retry/Add; Attacks/Slash_Escape; Data/Get. Todos são do anexo, sem confirmação atual do servidor.
5. Character.Rig_<nome>.LeftHand.Blade_1, Character.Injuries, HumanoidRootPart, IFrames e HUD Blade.Sets. Full reload exige zero sets e distância local <=20 studs de Refill dentro de GasTanks em Climbable/Unclimbable.
6. Grabbed/IsGrabbed booleanos ou BoolValue Grabbed são candidatos defensivos, não caminhos comprovados no anexo. Precisamos do indicador real para finalizar essa parte sem falsos positivos.
7. Rewards.Main.Info.Main.Buttons.Retry.Title, formato (n/n), visibilidade de ancestrais e estados STARTING/(0/0).
8. VirtualUser e permissão do executor. BodyPosition/BodyGyro são usados para manter o modelo físico legado com escopo próprio; podem não funcionar com a autoridade física atual.

## Plano de teste no jogo

1. Abrir a revisão abaixo no lobby e numa missão. Confirmar log v0.0.34 e diagnóstico AOTR 0.1.0. Todos os toggles devem iniciar desligados.
2. ESP, Visible e Extend: ativar um de cada vez, testar slider 0/1/2, novos Titans e alternância combinada. Desligar tudo restaura os valores observados originalmente.
3. Eren: ativar durante raid, acompanhar troca de Marker, desligar durante troca. Weakpoint anterior deve restaurar; alvo fora do próprio boss deve ser ignorado.
4. Ripper: ativar, usar uma habilidade que gere efeito reconhecido, observar janela de 2 s; testar sem Fake.Head/Animator para verificar Waiting/segurança. Desligar durante o efeito, mover Titan durante o efeito e testar com Nape Extend ligado. Confirmar restauração de velocidade das animações.
5. Skill farm: equipar as três habilidades de referência, observar identificação dos slots, cooldown e sequência. Desequipar/trocar slot durante execução; deve aguardar/pular sem erro fatal. Desligar durante atraso, ligar repetidamente, morrer e reaparecer. Verificar efeitos reais e associação ícone/ID antes de concluir funcionamento.
6. Farm clássico: ambiente com rota acessível e um Titan vivo; observar movimento e solicitações, aproximar-se de boss com Marker, retirar marcador e confirmar ausência de alvo. Esgotar sets para testar deslocamento ao refill e Full_Reload; confirmar HUD real. Ativar Blade Refill para recargas com stock. Desligar durante movimento, usar teleporte manual e respawn. Mapa, colisões e BV/BG devem permanecer intactos. Sem caminho livre, mover pode ficar bloqueado; não há destruição do cenário ou planejamento de rota.
7. ShadowBan: clicar uma vez, repetir enquanto ocupado, testar resposta/erro. Deve terminar em inconclusivo ou Error, sem conclusão de banimento e sem imprimir conteúdo de conta. Em 15 s de espera deve informar timeout.
8. Grab: ligar e criar outros botões na UI; não deve enviar escape. Sofrer grab real, observar Waiting e verificar se os indicadores candidatos existem. Se não houver detecção, enviar o diagnóstico e a estrutura/atributo real observado, sem assumir sucesso.
9. Anti-Injury: gerar lesão, ligar/desligar, conferir retorno na mesma pasta; remover Character enquanto ligado. Novo personagem não deve receber lesões antigas. Conferir separadamente se há efeito no servidor.
10. Blade Refill: zero/alguns sets, Blade ausente, IFrames true/false, trocar lâmina, respawn e desativar durante tentativa. Não alterar texto do HUD artificialmente.
11. Retry: recompensa visível, oculta, STARTING e (0/0); verificar uma solicitação por episódio, não declarar sucesso antes de voto/reinício real.
12. Anti-AFK: ativar, aguardar Idled, desativar, respawn e reiniciar. Conferir permissões e ausência de múltiplos handlers.
13. Reiniciar o hub com vários recursos ligados: UI/backend anteriores devem ser encerrados. Verificar ausência de movers/Highlights/tarefas residuais e todos os novos toggles desligados.

## Validação automática desta revisão

- Validação do repositório, versões e manifesto: passou em 0.0.34.
- Compilação dos 81 arquivos Lua de src, library, diagnostics e loader: passou.
- 356 verificações backend/headless/ciclo de vida: passaram, incluindo 60 novas verificações AOTR sobre a base de 296.
- 71 verificações da biblioteca: passaram.
- Revisão de diff e espaços: sem erros.
- Casos novos incluem: seleção viva/boss, nenhuma automação inicial, idempotência, composição/remoção de layers, restauração com cabeça em movimento, animações, erro remoto isolado, morte/respawn/reinício, movers próprios, mapa intacto, skills desconhecidas/cooldown, uso compartilhado de Ripper, cancelamento em atraso, grab falso positivo, lesões recuperáveis, query desconhecida/nil/timeout/retry, recarga sem alterar HUD, full reload com limite e voto único de retry.

Esses testes não verificam física ou protocolo real do servidor. A abertura inicial foi confirmada pelo usuário; recursos novos dependem dos testes acima.

## Loader exato da branch publicada

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/glowpkj/DepHub/codex/aotr-integration/DepHub.lua?ui=0.0.36"))("codex/aotr-integration")
```

O parâmetro evita reutilizar o loader antigo; o argumento fixa a mesma branch para os módulos. Testar sem executar o Tekkit em paralelo. Esta entrega atualiza apenas a branch de desenvolvimento e não faz merge em main.
