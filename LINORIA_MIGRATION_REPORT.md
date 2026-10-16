# DepHub — frontend Linoria

Data: 15/10/2026. Revisão do loader: **0.0.35**. Revisão da integração de UI: **0.1.0**.
Branch de desenvolvimento: `codex/aotr-integration`, preservando AOT:R e o histórico anterior.

## Resultado

Todos os frontends usam a mesma fonte Linoria: Universal, Blox Fruits, RT3, Noob Piece, MM2, TSB, Violence District, Volleyball Legends e AOT:R. Os controles existentes continuam ligados aos mesmos backends. Nenhum backend de gameplay foi alterado nesta migração.

Foram removidos os 11 arquivos da biblioteca anterior: `compact.lua`, `init.lua`, `components.lua`, `theme.lua`, `utils.lua`, `window.lua` e os cinco arquivos de `library/content`. As definições de conteúdo dos quatro modos gerais e a configuração comum foram movidas para `src/frontend/games`; não são renderizadores. A UI própria de Violence District foi substituída por controles Linoria.

O único código que cria janelas e controles de frontend é `library/linoria.lua`. O módulo `src/frontend/linoria.lua` traduz as definições do DepHub para as APIs nativas da Linoria, encapsula callbacks e gerencia estado e descarregamento. Não contém `Instance.new`, desenhos ou componentes visuais próprios. ESPs, BillboardGuis e demais visuais de gameplay permanecem em seus backends.

## Origem da biblioteca

- Diretório solicitado: https://github.com/ro0ti/Roblox-Scripting-UI/tree/main/Linoria%20Lib
- Arquivo utilizado: `Linoria Lib/Linoria Lib Source.lua`.
- Commit do repositório de referência: `071b80276339e73dc0686d6c694e2452ed4d40db`.
- Blob original: `5ce532748c72ffe021112be612cc1b4da14a6ab8`.

A fonte foi incluída no próprio DepHub para manter os módulos na mesma revisão e não depender de mudanças externas durante cada execução. Atribuição e origem constam no cabeçalho do arquivo. O exemplo do diretório carrega uma edição diferente de Linoria e menciona APIs que a fonte fornecida ainda não possui; a integração foi feita contra o conteúdo real do arquivo acima.

Não foram importados ThemeManager, SaveManager, webhooks ou carregadores remotos do exemplo. As configurações dos backends que já possuem SaveConfig continuam acessíveis pelo botão existente; não há autoload de configurações da Linoria.

## Ajustes locais na fonte Linoria

1. `Unload` e `OnUnload` com limpeza idempotente. Todas as inscrições de sinais da fonte original passam pelo conector que registra e desconecta as conexões.
2. Tarefas próprias, como rainbow, seleção de tecla e notificações, são registradas antes de executar e canceladas no unload. Callbacks de input que estejam aguardando também são registrados. O callback que está descarregando a própria interface não cancela a si mesmo no meio da limpeza.
3. ScreenGui tem nome DepHub, ResetOnSpawn=false, DisplayOrder definido e usa gethui quando disponível ou PlayerGui. A destruição externa da ScreenGui encerra o restante dos recursos.
4. O registro de Toggles/Options da Linoria fica acessível na própria Library. Valores globais anteriores são restaurados quando ainda pertencem à sessão descarregada.
5. O campo de input atualiza seu valor antes do callback e evita recursão. Dropdown programático dispara seu callback, possibilitando sincronização consistente com os controles dependentes.
6. Duração de Notify corrigida de `5 or Time` para `Time or 5`, com proteção após unload.
7. Janela usa o título string esperado por essa edição. `SetVisible` controla o Holder nativo. O cursor opcional que dependia de Drawing foi removido; a interface usa o cursor normal do Roblox.
8. Colunas de grupos receberam rolagem nativa para não cortar controles e diagnósticos longos. Labels de status são os próprios labels da Linoria, com altura e quebra de linha ajustadas.

Esses ajustes não restauram aparência ou componentes da biblioteca antiga. Cores, toggles, caixas, sliders, abas, dropdowns, inputs, seletor de cor, seletor de tecla e notificações vêm da Linoria.

## Preservação dos controles

| Modo | Conteúdo preservado |
|---|---|
| Universal | Movimento, voo, colisão, ESP e suas opções, ambiente, mira, chat, servidor e ferramentas já existentes |
| Blox Fruits | Movimento, equipe, ESP de jogadores/frutas e seletores dependentes de fruta, cor e forma |
| RT3 | Toggles das quatro automações e status de saúde/ping/FPS/versão |
| Noob Piece | ESP de baús/ilhas, seleção e teleporte de ilha, baús, quests/farm, inimigos, armas, NPCs, equipe e combate |
| MM2 | Role ESP, Auto Coins, Gun Drop ESP/Auto Get Gun e seus sliders, teleporte e status |
| TSB | Auto Block com a mesma ligação ao backend existente |
| Violence District | Player ESP, Auto Repair/alcance, Auto Skill Check, teleporte condicional para saída, Debug e diagnóstico |
| Volleyball Legends | Ball ESP, Trajectory Predictor e Debug |
| AOT:R | ESP, Nape Visible/Extend, Eren, assistência, teleporte, Ripper, farms, consulta e diagnósticos anteriores |

No caso dos frontends compactos, as antigas funções de montagem são agora somente ligações para os componentes Linoria; nenhum código visual compacto foi mantido. Os sliders de um recurso ficam no groupbox nativo, em vez do painel expansível antigo. A antiga HOME, busca própria e botão flutuante não fazem parte da Linoria indicada e foram removidos junto com a UI anterior.

## Comportamento e ciclo de vida

- Criar controles não executa seus callbacks de backend. A Linoria original chama OnChanged imediatamente ao registrar; a integração suprime essa primeira chamada para evitar ativação automática.
- Mudanças posteriores invocam o backend. Erro ou retorno false em um toggle restaura o valor anterior e mostra notificação, sem destruir o hub.
- Atualizações silenciosas dos controles e dropdowns dependentes não iniciam recursos.
- RightControl abre/fecha o menu. O seletor de tecla Linoria permite outro atalho. Ocultar mantém os recursos ativos; **Descarregar DepHub** encerra UI e backend.
- Reiniciar o loader limpa a sessão anterior. Reexecutar a mesma sessão saudável reabre a janela.
- Substituir apenas o frontend pode preservar o mesmo backend; listeners antigos de status e de disponibilidade de ilhas são desconectados.
- Respawn mantém a ScreenGui e os ciclos de vida dos backends, sem construir janelas duplicadas.

## Loader e manifesto

Loader e `src/version.txt` estão sincronizados em 0.0.35, invalidando a sessão anterior. Todos os pontos de entrada usam `src/frontend/linoria.lua` ou `src/frontend/main.lua`. Os identificadores internos de frontend foram atualizados para Linoria.

Todas as nove entradas de `.github/dephub-games.json` rastreiam a fonte Linoria e a integração compartilhada. Os modos gerais também rastreiam seus módulos de conteúdo. Os marcadores de atualização dos jogos foram atualizados. `src/update-manifest.json` continua sendo gerado pelo workflow de main; não foi preenchido com hashes inventados nesta branch.

## Validação

- Validação do repositório, referências, versões e manifesto: passou.
- Compilação Luau: **78 arquivos** passaram.
- Backend/headless/ciclo de vida: **356 verificações passaram**.
- Biblioteca/integração Linoria: **262 verificações passaram**.
- Revisão de diff e verificação de dependências antigas: concluídas.

A suite de UI executa a fonte Linoria real com substitutos das APIs Roblox e monta os nove modos. Cobre callbacks, montagem sem efeitos automáticos, rejeição/erro, sliders, dropdowns dependentes, input, cores, labels de status, teclas, unload, destruição externa da GUI, restauração de globais e encerramento dos backends. Os testes de layout específicos da biblioteca removida foram substituídos por testes da interface atual.

**Não houve teste desta migração dentro do Roblox.** A abertura anterior confirmada pelo usuário era da interface antiga e não comprova a renderização da nova. Os testes simulados não verificam posicionamento real, fonte/texto, clipping, foco, permissões de gethui/PlayerGui, input mobile ou interação com interfaces dos jogos.

## Teste manual

1. Executar o loader abaixo. Confirmar v0.0.35 e somente uma janela Linoria.
2. Abrir/fechar por RightControl, trocar a tecla no seletor e conferir arraste, abas e rolagem.
3. Em cada jogo, verificar a lista da tabela acima e ativar um recurso por vez. Confirmar que os estados iniciais correspondem aos do backend.
4. Blox Fruits: trocar fruta e conferir que a lista de cores acompanha a seleção. Noob Piece: trocar/disponibilizar ilha e atualizar inimigos.
5. AOT:R e MM2: conferir que status longos são legíveis e todos os controles podem ser alcançados com rolagem.
6. Violence District: conferir que o botão da saída aparece apenas quando o backend encontra a alavanca.
7. Testar respawn e reexecução sem janelas ou ações duplicadas.
8. Descarregar com recursos ligados. Confirmar limpeza de UI, handlers e recursos de backend.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/glowpkj/DepHub/codex/aotr-integration/DepHub.lua?ui=0.0.35"))("codex/aotr-integration")
```

Esta publicação é na branch de desenvolvimento. A migração não faz merge em main nem retoma a manutenção do launcher principal que havia sido adiada.
