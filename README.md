# StraitUI

**Interface gráfica local para transferir conversas entre Claude Code, Codex e OpenCode usando [Strait](https://github.com/Sasitilak/strait).**

Projeto Flutter Desktop, com um bridge Node.js em segundo plano. As conversas são lidas do computador do usuário e nenhuma informação é enviada a servidores pelo StraitUI.

> **Status: MVP inicial / desenvolvimento.** Este código foi escrito sem execução de builds ou testes automatizados. O Strait também está em alpha. Faça backups das sessões antes de experimentar transferências, especialmente para OpenCode.

## Funcionalidades

- Detectar os três agentes e contar suas sessões locais.
- Habilitar ou ocultar provedores; listar, buscar e filtrar sessões.
- Visualizar mensagens, textos, chamadas de ferramentas e resultados.
- Prévia dos blocos omitidos (imagens/raciocínio) e confirmação antes de copiar.
- Converter sessões entre os seis pares suportados pelo Strait, preservando a origem.
- Copiar o comando para retomar a sessão no programa de destino.
- Interface adaptável com temas claro/escuro do sistema; PT-BR, EN e ES.

## Stack

| Camada | Tecnologia | Responsabilidade |
| --- | --- | --- |
| Interface | Flutter / Dart / Material 3 | Layout, filtros, visualização e confirmação |
| Bridge | Node.js 18+ / JSON Lines em stdio | Leitura local, normalização visual e invocação da CLI |
| Transferência | [`strait-cli`](https://github.com/Sasitilak/strait) | Conversão de sessões, parse/emit e escrita nativa |
| Leitura OpenCode | `sql.js`/WASM | Snapshot SQLite de leitura, sem edição pela GUI |

O bridge **não** reimplementa as conversões do Strait. O visualizador realiza uma normalização de leitura independente porque o CLI upstream ainda não fornece um endpoint JSON de conteúdo das sessões. As futuras versões poderão usar uma API de biblioteca pública do Strait, caso seja disponibilizada.

## Rodar em desenvolvimento

Pré-requisitos:

- [Flutter SDK](https://docs.flutter.dev/get-started/install) com suporte para Linux, Windows ou macOS;
- Node.js 18 ou superior e npm;
- [Strait](https://github.com/Sasitilak/strait) instalado globalmente;
- pelo menos um dos agentes (Claude Code, Codex ou OpenCode) com sessões locais;
- comando `sqlite3` no PATH **para transferências com destino OpenCode** (recomendado para a segurança da escrita).

```bash
git clone https://github.com/zonaro/straitUI.git
cd straitUI

# Strait é um programa externo; o comando disponível deve se chamar "strait"
npm install -g strait-cli

# Instala a única dependência JS do bridge, sql.js
cd bridge
npm install
cd ..

# Gere os arquivos nativos de cada plataforma caso ainda não existam no repo
flutter create --platforms=linux,windows,macos --project-name strait_ui .
flutter pub get
flutter run -d linux
```

Troque `linux` por `windows` ou `macos` conforme seu computador. A geração dos diretórios nativos com `flutter create` é parte do setup inicial, porque o projeto foi criado sem SDK Flutter disponível no ambiente de autoria.

No Fedora, caso ainda falte o utilitário de banco, instale o pacote `sqlite` usando o gerenciador de pacotes do sistema. **Não execute uma transferência para OpenCode enquanto ele estiver gravando no banco.**

O bridge é iniciado automaticamente pelo Flutter. Durante o desenvolvimento, execute o app **a partir da raiz do repositório**, onde fica `bridge/bin/bridge.mjs`.

### Variáveis opcionais

| Variável | Uso |
| --- | --- |
| `STRAIT_UI_BRIDGE_PATH` | Caminho absoluto para `bridge.mjs` |
| `STRAIT_UI_NODE_BIN` | Executável Node.js usado pelo Flutter |
| `STRAIT_UI_STRAIT_BIN` | Executável `strait` usado pelo bridge |
| `STRAIT_UI_OPENCODE_DB` | Caminho do banco `opencode.db` em instalação não padrão |

## Fluxo de cópia

1. Escolha uma conversa na lista.
2. Visualize a sessão. Blocos de mídia e raciocínio privado aparecem como placeholders.
3. Clique em **Copiar para**, selecione outro agente e confira o aviso.
4. O bridge chama `strait sync <origem> <destino> --session <id>` em um subprocesso **sem shell**.
5. Se tudo der certo, a GUI apresenta o comando de retomada para copiar e executar no terminal.

O StraitUI nunca ativa `--force`. A sessão original não é removida pela GUI. Para o OpenCode, transferências são bloqueadas se houver arquivo WAL não vazio ou se o programa `sqlite3` não estiver disponível.

## Limitações conhecidas

- Desktop-first: Android/iOS e acesso remoto às sessões não fazem parte do MVP.
- O app ainda requer Node.js e Strait instalados no sistema. Empacotamento do runtime e instaladores autossuficientes estão no roadmap.
- O visualizador não renderiza imagens, anexos, Markdown enriquecido, sintaxe de código ou raciocínio interno. Ele preserva as mensagens textuais para inspeção.
- OpenCode mantém dados em SQLite; quando há páginas não consolidadas no WAL, o snapshot somente leitura pode estar desatualizado.
- Os caminhos de sessão em Windows/macOS devem ser verificados em instalações reais. Há uma configuração manual para o banco OpenCode.
- A descoberta de `strait-cli` no Windows cobre os prefixos globais mais comuns do npm. Instalações customizadas podem exigir `STRAIT_UI_STRAIT_BIN` apontando para o `dist/index.js` instalado.
- O resultado de uma conversão depende da versão do Strait e pode omitir blocos incompatíveis entre agentes.
- Sessões muito grandes (>200 MB cada arquivo JSONL) não são abertas pelo visualizador, para evitar consumo excessivo de memória.

## Estrutura

```text
lib/
  main.dart                  # interface Flutter
  src/bridge_client.dart     # comunicação via stdio
  src/models.dart            # modelos normalizados do visualizador
  src/i18n.dart              # strings PT/EN/ES
bridge/
  bin/bridge.mjs             # integração local Node/Strait
  package.json
.agents/
  architecture.md            # arquitetura e contrato de mensagens
  security.md                # limites de segurança e dados locais
  ui.md                      # interface e comportamento esperado
  roadmap.md                 # próximas etapas de implementação
AGENTS.md                    # regras para agentes de código
```

## Contribuições e licença

Este repositório usa licença MIT (`LICENSE`). O [Strait](https://github.com/Sasitilak/strait), também MIT, é uma dependência externa criada por Sasitilak. StraitUI não é um produto oficial do projeto upstream.

Leia `AGENTS.md` e `.agents/` antes de modificar o código.

