<div align="center">

# ⚔️ Arcane Voyage

**Um AFK-RPG de fantasia sombria, estilo MU, feito em Godot — com servidor autoritativo, saves à prova de queda e mais de 160 suítes de testes automatizados.**

![Godot 4.6](https://img.shields.io/badge/Godot-4.6-478CBF?logo=godotengine&logoColor=white)
![GDScript](https://img.shields.io/badge/linguagem-GDScript-355570)
![Plataforma](https://img.shields.io/badge/plataforma-PC%20%7C%20Android%20(landscape)-2ea44f)
![Renderer](https://img.shields.io/badge/renderer-Compatibility%20(GLES3)-6e5494)
![Testes](https://img.shields.io/badge/selftests-164%20su%C3%ADtes-success)

</div>

<p align="center">
  <img src="assets/actors/bosses/alpha_wolf.png" alt="Boss Lobo Alfa" height="160">
  <img src="assets/actors/bosses/crystal_golem.png" alt="Boss Golem de Cristal" height="160">
  <img src="assets/actors/bosses/salt_split_warden.png" alt="Boss Guardião do Sal" height="160">
  <br><sub>Sprites de bosses usados no jogo</sub>
</p>

---

## 🎮 O que é

**Arcane Voyage** é um RPG de progressão automática (*idle/AFK*) inspirado em MU Online: o herói caça,
sobe de fase e enfrenta bosses sozinho, enquanto o jogador decide **classe, build, equipamento, refino e
rumo da jornada**. Este repositório é o **cliente Godot (vertical slice)** do projeto.

O que existe de fato no código (`scripts/`):

| Sistema | O que faz | Onde |
|---|---|---|
| **Campanha por fases** | Jornada em `capítulo-fase` (1-1 … 1-10); a fase 5 é mini-boss e a 10 é boss de capítulo | `StageDirector.gd` |
| **Bosses data-driven** | Bosses definidos por dados (ex.: Lobo Alfa, Golem de Cristal, Aranha Matriarca, Matriarca das Raízes), com fases por % de HP, *telegraphs* e enfurecimento | `BossDefinition.gd`, `BossEncounterRuntime.gd`, `BossAbilityLibrary.gd` |
| **5 classes + IA de combate** | Corpo a corpo, arqueiro, mago, lanceiro e suporte; a IA escolhe a execução por arquétipo | `CharacterClassDefinition.gd`, `AutoCombatBrain.gd`, `CombatRuntime.gd` |
| **Progresso offline** | Baú AFK calculado por **matemática** (custo proporcional às fases atravessadas, não aos abates) | `IdleRewards.gd` |
| **Prestígio / Master Level** | Reinicia a jornada, nunca o personagem, com bônus permanente explícito | `PrestigeManager.gd` |
| **Itens, loot e refino** | Instâncias de item com qualidade/rolagens, refino por slot, bestiário e códice | `ItemInstance.gd`, `LootManager.gd`, `RefineMath.gd`, `BestiaryManager.gd` |
| **Missões e zonas de caça** | Motor único de missões data-driven; zonas de caça com respawn, grupo (*party*) e loot pessoal | `MissionEngine.gd`, `HuntService.gd` |
| **Arena (fundação competitiva)** | Rating tipo ELO transparente, temporadas com estados explícitos e finalização idempotente, ranking de poder separado | `ArenaService.gd`, `ArenaRating.gd`, `ArenaSeasonManager.gd` |
| **Troca P2P segura** | Item vai para **escrow** real no servidor, oferta versionada, confirmação reseta a cada mudança (anti *bait-and-switch*) e commit atômico entre dois personagens | `TradeService.gd`, `TradeRepository.gd` |
| **Mobile** | Joystick e botões de toque, botão VOLTAR do Android fecha painéis em vez de sair, layout landscape | `TouchJoystick.gd`, `UIBackStack.gd`, `PlatformCapabilities.gd` |

> Arena e troca estão implementadas como **serviços de backend cobertos por testes**; o modo online
> ainda é experimental (servidor ENet local). O modo padrão é **LOCAL**, com a autoridade embutida.

---

## 🛠️ Stack

- **Godot 4.6** · **GDScript**
- Renderer **Compatibility (GLES3)** também no Android — o mesmo caminho de renderização do PC, para alcançar aparelhos modestos
- Alvo: **PC (Windows)** e **Android em landscape** (resolução mínima garantida 1280×720, `stretch = expand`)
- Rede: **ENet** (`ENetConnection`) com protocolo JSON versionado
- Ferramentas: **Python** (NumPy / Pillow / SoundFile) para pipeline de arte e áudio procedural; **PowerShell** para o runner de testes

---

## 🧠 Destaques de engenharia

Pontos que mostram preocupação com **confiabilidade, segurança e testabilidade** — todos verificáveis no código:

- **Save atômico** (`AtomicSave.gd`) — grava um arquivo temporário inteiro, valida, faz backup e só então promove. Se o processo morrer no meio, sobra o save antigo **ou** o novo, nunca um arquivo vazio. O carregamento recupera pelo backup.
- **Migração de save** (`SaveMigration.gd`) — evita a perda silenciosa de progresso quando o formato do save muda de versão.
- **Servidor autoritativo** (`AuthorityServer.gd`) — o cliente envia **intenção**; o servidor valida, executa uma única vez, persiste e responde. O cliente nunca decide ouro, XP, loot ou sucesso de refino.
- **Idempotência por `command_id`** — repetir um comando (ex.: reenvio após queda de conexão) não duplica recompensa.
- **Fila de comandos serializada** (`AuthorityCommandQueue.gd`) — uma operação econômica por vez, com *backpressure* (`SERVER_BUSY`) sem descartar nada já confirmado.
- **Concorrência otimista** por *revision* e **sessão única** por personagem.
- **Relógio do servidor** (`ServerClock.gd`) — operações online nunca confiam no relógio do cliente.
- **Camada de rede separada da economia** (`GameServer.gd` / `NetProtocol.gd`) — whitelist de comandos, limite de tamanho de pacote, *rate limit* por conexão, pacote malformado não derruba o servidor e logs **sem token/credencial**.
- **Guarda de produção** (`RuntimeMode.gd`) — o provedor de autenticação de desenvolvimento não pode subir em ambiente `production`.
- **Validação de assets** (`ActorAssetValidator.gd`, `EnvironmentAssetValidator.gd`) — confere contrato de sprites (dimensões, quadros, direções) antes de chegar ao jogo.
- **Arquitetura data-driven** — bosses, missões, regiões e narrativa vêm de dados (`data/`), não de `if boss == ...`.

---

## 🧪 Testes automatizados (QA)

| Métrica | Valor medido |
|---|---|
| Suítes de selftest (`scripts/_*selftest*.gd`) | **164** |
| Linhas de código de teste | **≈ 34,4 mil** |
| Chamadas de verificação (asserts) | **≈ 8,7 mil** (contagem estática por `grep`) |
| Grupos estruturados com `TestHarness` | **179** grupos em 21 suítes |

- **"No silent green"** (`TestHarness.gd`): um grupo de testes que aborta no meio, ou que não atinge o mínimo de asserts, **não passa** — o resultado geral fica FAIL. Isso impede o falso positivo clássico de teste que "passou" porque nem rodou.
- Os testes usam **fixtures** e nunca tocam o save real do jogador.
- **Runner seguro** (`tools/run_selftest_safe.ps1`): nasceu de um incidente real — uma suíte travou a máquina. O runner impede dois Godot simultâneos, roda em prioridade baixa, tem **timeout externo com kill**, *watchdog* de travamento (log parou de crescer ⇒ mata), captura stdout/stderr e registra o último marcador observado.

---

## 📊 Números do projeto (medidos com `wc`/`find`)

| | |
|---|---|
| Scripts `.gd` | **350** (≈ **79,8 mil** linhas) |
| — código de jogo/sistemas | 174 arquivos · ≈ 44,5 mil linhas |
| — testes e utilitários de teste | 176 arquivos · ≈ 35,3 mil linhas |
| Arquivos de dados JSON | 49 |
| Imagens PNG | 594 |
| Faixas de áudio ambiente (procedurais) | 10 |
| Ferramentas Python | 12 scripts · ≈ 2,3 mil linhas |

---

## 📁 Estrutura

```
arcane-voyage/
├── project.godot          # configuração (autoloads, landscape, renderer Compatibility)
├── scenes/                # Main.tscn (cena principal) + cenas de teste
├── scripts/               # sistemas do jogo (*.gd) e selftests (_*_selftest.gd)
├── data/
│   ├── canonical/         # campanha, bosses, NPCs, regiões, diálogos (exportados do editor)
│   ├── map_manifest/      # manifestos de mapa por região
│   └── map_editor_*/      # mapas e ajustes vindos do editor de mapas
├── assets/                # atores, tilesets, UI/HUD, VFX, áudio
├── tools/
│   ├── run_selftest_safe.ps1   # runner de testes com timeout/watchdog
│   ├── generate_map_manifest.py
│   ├── art/  audio/  audit/    # pipeline de arte, áudio procedural, auditoria estática
└── docs/media/            # prints para este README
```

Autoloads: `DataLoader` (carrega os dados canônicos), `GameState` (estado e save) e `TriggerDispatcher` (gatilhos de narrativa).

---

## ▶️ Como abrir e jogar

1. Instale o **Godot 4.6** (versão padrão, não a .NET).
2. Abra o Godot → **Importar** → selecione o `project.godot` desta pasta.
3. Na primeira abertura o Godot reimporta os assets (pode levar alguns minutos).
4. Pressione **F5** — a cena principal é `scenes/Main.tscn`.

O save fica em `user://arcane_voyage_save.json` (pasta de dados do usuário do Godot).

## ✅ Como rodar os testes

Direto pela linha de comando (qualquer SO):

```bash
godot --headless --path . --import                                   # 1ª vez: importa os assets
godot --headless --path . -s res://scripts/_combatmath_selftest.gd   # roda uma suíte
```

No Windows, pelo runner seguro (PowerShell):

```powershell
.\tools\run_selftest_safe.ps1 -Mode import -GodotExe "C:\caminho\Godot_v4.6-stable_win64_console.exe"
.\tools\run_selftest_safe.ps1 -Mode run -Script res://scripts/_a112_trade_selftest.gd -GodotExe "C:\caminho\Godot_v4.6-stable_win64_console.exe"
```

Os logs vão para `%TEMP%\arcane_selftest_runs`. Códigos de saída: `0` ok · `2` abortado (já havia Godot aberto) · `124` morto pelo runner.

Variáveis opcionais: `AV_MODE` (`LOCAL`/`SERVER`/`CLIENT`), `AV_SERVER_ENV` (`development`/`production`)
e `AV_COMBAT_HANDOFF_JSON` (usada por uma única suíte de auditoria de arte que lê um arquivo externo ao repositório).

---

## 🤝 Como foi construído

Este projeto foi desenvolvido **com IA como par de programação**, e faço questão de deixar isso claro:

- **ChatGPT** atuou como **arquiteto de especificação** — ajudando a transformar ideias em especificações numeradas por fatia (as referências `§` e `FATIA Axx` nos comentários vêm daí).
- **Agentes Codex e Claude** atuaram como **executores** — escrevendo a maior parte do código e dos testes a partir dessas especificações.
- **Meu papel:** direção de produto, definição de escopo e regras, especificação, **revisão** do que foi entregue e **QA/testes** — rodar, quebrar, reportar, exigir teste para cada correção e não aceitar "verde" sem prova.

O que este repositório demonstra, portanto, é menos digitação de código e mais **o processo**: especificar
com clareza, validar com testes automatizados, tratar incidentes (como o runner seguro) e manter
rastreabilidade das decisões.

A arte foi gerada durante o projeto e processada com scripts próprios; o áudio ambiente é procedural.
Créditos de terceiros em [`CREDITS.md`](CREDITS.md).

---

<div align="center">
<sub>Projeto pessoal de estudo · vertical slice · sem fins comerciais</sub>
</div>
