# ATLAS: The Lost Frontier

Jogo cooperativo de exploração e captura de criaturas para Roblox (mobile primeiro, também PC; PT, EN, ES).

Os scripts vivem neste repositório e são sincronizados com o Roblox Studio pelo [Rojo](https://rojo.space). Mapas, modelos 3D e cenário ficam no arquivo do place, **`atlas.rbxl`, que também é versionado aqui** — é ele que traz a vila, o pet inicial e os assets. Clonar o repositório basta para ter o jogo inteiro em qualquer computador.

## Configurar no Windows (uma vez)

1. Instale o **Rokit** (gerenciador de ferramentas): baixe o `rokit-*-windows-x86_64.zip` em <https://github.com/rojo-rbx/rokit/releases>, extraia e rode `rokit self-install` no terminal. Feche e abra o terminal.
2. Clone o repositório e instale o Rojo:
   ```
   git clone https://github.com/DanielOliveiraUX/atlas
   cd atlas
   rokit install
   ```
3. Instale o plugin do Rojo no Studio: `rojo plugin install`.
4. Abra o `atlas.rbxl` da pasta clonada (duplo clique, ou **Arquivo → Abrir do arquivo** no Studio).
5. Em **Game Settings → Localization**, defina o idioma de origem como **Português (Brasil)**.

Sobre **Game Settings → Security → Enable Studio Access to API Services**: deixe **desligado** enquanto estiver ajustando o tutorial. Sem ele os dados ficam só em memória, então o tutorial recomeça a cada Play — que é o que você quer para testar. Ligue só quando for testar persistência de verdade.

## Trabalhar no dia a dia

1. No terminal, dentro da pasta: `rojo serve`
2. No Studio, com o `atlas.rbxl` aberto: aba **Plugins → Rojo → Connect**.
3. Aperte **Play**.

O tutorial deve correr assim: tela "Carregando sua expedição…" → você nasce na praça → faixa "Bem-vindo à fronteira" → "Fale com o Guia do Farol" → chegue perto do NPC e aperte **E** → cartão "Este é o Lumi" → abra **Coleção** (canto inferior direito) → **Equipar** → você vai para a sua base com o Lumi atrás. No Output: `[ATLAS] Servidor iniciado`.

## Salvar o cenário

Mexeu no cenário, nos modelos ou nos assets dentro do Studio? Salve o place (**Ctrl+S**) e faça commit do `atlas.rbxl` — senão a mudança fica só na sua máquina. Mexeu só em script? O arquivo está em `src/`, o place não muda.

## Estrutura

```
src/
  shared/        → ReplicatedStorage.Shared (servidor e cliente)
    Config/      valores de balanceamento (fadiga, criaturas, batalha, dificuldade, dados)
    Types/       tipos Luau
    Util/        TeamUtil, Localization
    UI/          Theme (mobile-first, escala por tela)
    Remotes.lua  todos os RemoteEvents/Functions
  server/        → ServerScriptService.Server
    Services/    regras do jogo (fonte de verdade)
    Data/        perfil padrão e migrações
  client/        → StarterPlayerScripts.Client
    Controllers/ lógica de interface e entrada
  localization/  UI.csv → LocalizationService (PT origem, EN, ES)
```

## Regras do código

- Toda regra de jogo roda no servidor. O cliente só pede; o servidor valida.
- Números de balanceamento ficam em `Config/`, nunca no meio da lógica.
- Todo texto visível usa chave de tradução em `UI.csv`.
- Mudou o formato do perfil? Suba `DataConfig.SchemaVersion` e crie a migração em `server/Data/Migrations.lua`.

## Andamento

- [x] Fase 1 — Fundação (estrutura, dados com trava de sessão, localização, base de UI mobile)
- [~] Fase 2 — Tutorial, coleção e equipe — **código escrito e vila construída, ainda não testado em jogo**
- [ ] Fase 3 — Pet no mundo
- [ ] Fase 4 — Batalha + fadiga
- [ ] Fase 5 — Captura
- [ ] Fase 6 — Expedição
- [ ] Fase 7 — Economia mínima
- [ ] Fase 8 — Multiplayer e balanceamento
- [ ] Fase 9 — Lançamento experimental
