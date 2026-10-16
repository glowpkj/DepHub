# AOT:R — Classic Autofarm: noclip e deslocamento

Revisão do loader: **0.0.36**. Backend AOTR: **0.1.1**.

## Mudanças

- Classic Farm Noclip é uma preferência ligada por padrão, mas só altera o personagem quando Classic Autofarm começa a se mover. Não liga o farm automaticamente.
- Captura CanCollide original de cada BasePart do personagem, incluindo false, e desativa colisão antes da física. Inclui peças novas e corrige reativações de colisão durante o movimento. Peças que saem do personagem recuperam imediatamente o valor capturado.
- Desligar noclip restaura colisão sem desligar o farm. Desligar o farm, descarregar, morrer, remover o personagem, perder alvo ou encontrar erro encerra tween/hold/conexão de física e restaura as propriedades recuperáveis.
- Não altera CanTouch, CanQuery, mapa, colisões de cenário nem os objetos BV/BG do jogo. Não promete impedir grab ou outras ações do servidor.
- Substitui a mola BodyPosition e os destinos limitados a 30 studs por um tween linear, com duração calculada por distância/velocidade. Usa um BodyVelocity próprio para contrabalançar a física durante o trajeto, sem forças infinitas. Ao parar, remove-o e restaura velocidades, orientação na posição atual e AutoRotate do Humanoid.
- Pequenas oscilações do alvo não reiniciam o tween continuamente; deslocamentos de pelo menos 8 studs atualizam o destino. O alvo vivo fica fixado até morrer, sair da pasta ou mudar o weakpoint do boss, evitando troca contínua entre Titans próximos.
- Cancelamento desconecta o callback antes de cancelar o tween. Conclusões antigas não podem interferir no movimento atual. A morte do personagem ou do alvo é observada também pelo controlador de física, independentemente da espera por uma chamada remota.
- Teleport to Refill usa a mesma velocidade e continua cancelável. O botão libera o controlador do farm antes de iniciar o tween para não disputar a posição do personagem. Esse teleporte manual não mantém o noclip do farm; o trajeto automático de refill do farm usa o controlador com noclip.

## Velocidade

**Travel Speed (studs/s)**: padrão **1.000**, ajuste de **50 a 2.000**.

É um intervalo local de configuração, não um limite oficial ou máximo aceito pelo servidor. Não há informação confiável no código sobre o limite do AOT:R, nem medição nesta sessão. O servidor pode corrigir ou rejeitar deslocamentos rápidos; reduzir o slider é a forma de comparar o comportamento. Não foi incluída lógica para contornar validações do servidor.

Mudanças do slider cancelam o tween automático anterior e passam a valer no próximo passo do farm. No botão manual de refill, a velocidade vale para o próximo teleporte iniciado.

## Verificação

- 379 verificações de backend/headless/ciclo de vida passaram, incluindo 23 verificações novas sobre a base anterior de 356.
- 262 verificações de integração Linoria passaram.
- Validação de referências, manifesto e versão 0.0.36 passou.
- Compilação Luau dos 78 arquivos Lua passou.

Os novos casos cobrem velocidade por distância/tempo, reuso de tween, oscilação do alvo, atualização de velocidade, valores inválidos, callback antigo, peças novas/removidas, colisão inicialmente false, noclip independente, morte/respawn, AutoRotate, alvo fixado e transição para refill manual.

O usuário relatou testar o Classic Autofarm da revisão anterior. **Esta revisão ainda não foi executada no Roblox pelo agente.** Testes com substitutos de APIs não comprovam física, ausência de correções do servidor, aceitação de velocidade ou ataques reais.

## Teste

1. Confirmar log v0.0.36 e diagnóstico AOTR 0.1.1.
2. Ligar Classic Autofarm com Classic Farm Noclip marcado. Testar passagem por obstáculos durante o trajeto.
3. Comparar velocidades 500, 1.000, 1.500 e 2.000. Se houver retorno de posição ou tremor, reduzir e informar o valor/contexto observado.
4. Desligar noclip durante o movimento e confirmar restauração. Desligar o farm durante um trajeto e confirmar que o personagem volta a colidir e pode ser controlado normalmente.
5. Testar troca/morte do Titan, respawn, refill automático e botão manual de refill. Descarregar/reexecutar para conferir ausência de hold, tween ou colisão residual.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/glowpkj/DepHub/codex/aotr-integration/DepHub.lua?ui=0.0.36"))("codex/aotr-integration")
```

Publicação apenas na branch de desenvolvimento `codex/aotr-integration`.
