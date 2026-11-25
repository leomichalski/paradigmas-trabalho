<!--
  TEMPLATE DO RELATÓRIO DE ENTREGA: Paradigmas de Programação

  Como usar:
  - Copie este arquivo para a raiz do repositório do grupo, com o nome
    RELATORIO.md, e preencha todas as seções.
  - Os textos entre <!- - e - -> (como este) são instruções. Eles não
    aparecem quando o arquivo é visualizado, mas APAGUE-OS antes de entregar.
  - Troque tudo o que estiver entre [colchetes].
  - Seja direto. Frases curtas e listas valem mais que parágrafos longos.
    Um relatório típico cabe em 4 a 8 páginas.
  - O relatório e o código são avaliados juntos. Sempre que possível,
    aponte para o código (arquivo e linha) em vez de descrevê-lo. Os
    critérios de avaliação estão em AVALIACAO.md.
  - ANTES DE ENTREGAR, rode o validador na raiz do repositório:

        uv run scripts/validar_entrega.py

    Ele confere a FORMA do relatório (comentários apagados, colchetes
    preenchidos, tabelas bem formadas, seções presentes, arquivos
    existentes), não o conteúdo. Corrija todos os ERROS apontados.
-->

# ProspectFlow

## 1. Identificação

<!--
  Os grupos têm de 3 a 7 pessoas (5, em média). A tabela abaixo tem 5
  linhas: adicione ou remova linhas conforme o tamanho do seu grupo, aqui e
  na seção 10. Os grupos podem misturar alunos das turmas das 14h e das 16h:
  indique a turma de CADA integrante.
-->

| Nome completo | Matrícula | Turma (14h/16h) | Usuário GitHub |
|---------------|-----------|-----------------|----------------|
| Eduarda Domingos Rodrigues       | [000000]  | 16           | [@usuario]     |
| Eduardo de Almeida Ferreira       | [000000]  | 16           | [@usuario]     |
| Eduardo de Almeida Morais        | 231011275  | 16h           | @Edumorais08     |
| Leonardo Michalski Miranda       | [000000]  | 16           | [@usuario]     |
| Letícia de Carvalho dos Santos        | [000000]  | 16           | [@usuario]     |
| Maria Samara Alves Silva        | 231027005  | 16          | @SamaraAlvess     |
| Yan Lucas Souza Guimarães       | [000000]  | 16           | [@usuario]     |

- **Nome do projeto:** ProspectFlow
- **Nome do grupo:** Lambda Squad
  <!--
    O nome do grupo identifica vocês nas planilhas de notas e na chamada
    para a apresentação. Não dá para validar se é único, então caprichem:
    "Grupo 3" vai colidir com o "Grupo 3" da outra turma.
  -->
- **Repositório:** https://github.com/leomichalski/paradigmas-trabalho
- **Commit ou tag entregue:** [`a1b2c3d` ou `v1.0`]
  <!--
    O avaliador vai olhar exatamente esta versão. Para criar uma tag:
      git tag v1.0 && git push origin v1.0
  -->
- **Ponto de partida:** [template do Sudoku com ajustes | variante do Sudoku | outro jogo conhecido | remix original | jogo inventado]
  <!--
    Escolha UMA faixa. Ela define o ajuste de escopo da nota do grupo
    (AVALIACAO.md, seção 1.5). O professor confirma a faixa na apresentação.
  -->
- **Slides da apresentação oral:** [`docs/apresentacao.pdf` | link externo | não há]
  <!--
    No final do semestre, cada grupo faz uma apresentação oral de 15
    minutos. Slides são opcionais; se o grupo usar, coloque o arquivo no
    repositório (de preferência em PDF) e indique o caminho aqui.
  -->

## 2. Resumo

ProspectFlow é um editor e executor de fluxos de automação com LLM, descritos em texto com uma sintaxe limitada do Mermaid. O frontend em Elm envia o fluxo para um backend FastAPI, e o Prolog executa o fluxo como uma máquina de estados (cada nó dispara um evento que escolhe o próximo passo), analisa o grafo e guarda os fluxos salvos como uma base de fatos consultável.

![Gif do Sistema](assets/demo.gif)
<!-- Uma ou duas capturas de tela da interface. Crie a pasta docs/ se precisar. -->

## 3. Como executar

<!--
  Teste estas instruções numa máquina "limpa" (ou peça a um colega de
  outro grupo). Se o avaliador não conseguir rodar o sistema, o resto do
  trabalho não pode ser verificado.
-->

**Requisitos** (com as versões que o grupo usou):

- SWI-Prolog [9.x]
- Node.js [2x.x]
- [uv / Python 3.x, se usar]

**Instalação e execução:**

```sh
[comandos exatos, na ordem]
```

**Testes:**

```sh
[comando para rodar os testes, se houver]
```

**Testado em:** [Linux / Windows / macOS, navegador]

## 4. Arquitetura

<!--
  Um diagrama simples (pode ser em texto) mostrando as partes do sistema e
  como elas se comunicam. Diga em uma frase a responsabilidade de cada parte.
-->

```
[Elm] --HTTP/JSON--> [Python] --janus--> [Prolog]
```

| Parte  | Responsabilidade | Arquivos principais |
|--------|------------------|---------------------|
| Prolog | [...]            | [`backend/prolog/...`] |
| Elm    | [...]            | [`frontend/src/...`]   |
| Python | [só integração]  | [`backend/app/...`]    |

## 5. Parte em Prolog

### 5.1 Predicados principais

<!--
  Os predicados mais importantes, com o local no código. Use a notação
  nome/aridade e indique entradas (+) e saídas (-), como na documentação
  do SWI-Prolog.
-->

| Predicado | Local | O que faz |
|-----------|-------|-----------|
| [`resolver(+Entrada, -Saida)`] | [`arquivo.pl:42`] | [...] |
| [...] | [...] | [...] |
| `salvar_fluxo(+Nome, +Texto, +Gatilho)` | `backend/prolog/armazenamento.pl:53` | Lê o diagrama com o parser do `fsm.pl` e grava o fluxo como fatos (texto, gatilho, nós e transições). Substitui o fluxo se o nome já existir |
| `carregar_fluxo(+Nome, -Texto, -Gatilho)` | `backend/prolog/armazenamento.pl:86` | Devolve o diagrama e o gatilho de um fluxo salvo. Falha se ele não existe |
| `fluxos_com_tipo(+Tipo, -Nomes)` | `backend/prolog/armazenamento.pl:129` | "Quais fluxos usam um nó POST?" |
| `fluxos_com_evento(+Evento, -Nomes)` | `backend/prolog/armazenamento.pl:134` | "Quais fluxos tratam o evento `fetch_failed`?" |
| `fluxos_com_ligacao(+TipoA, +TipoB, -Nomes)` | `backend/prolog/armazenamento.pl:140` | "Quais fluxos ligam um PROMPT direto a um POST?" Junta três fatos numa só consulta |
| `tipo_da_acao(+Acao, -Tipo)` | `backend/prolog/armazenamento.pl:112` | `"PROMPT: Oi"` vira `prompt`, `"DONE"` vira `done` |

### 5.2 Conceitos do paradigma lógico utilizados

<!--
  Marque o que o projeto usa DE FATO e indique onde. Não é preciso usar
  tudo; é preciso explicar bem o que foi usado.
-->

- [x] Fatos e regras como base de conhecimento: os fluxos salvos viram fatos `fluxo_no/3`, `fluxo_transicao/4`, `fluxo_texto/2` e `fluxo_gatilho/2`, gravados em arquivo com `library(persistency)` (`armazenamento.pl:31`); as consultas são regras sobre eles (`armazenamento.pl:125-145`). [outras partes: onde]
- [ ] Unificação e casamento de padrões: [onde]
- [ ] Recursão (inclusive sobre listas): [onde]
- [x] Backtracking e múltiplas soluções: `fluxos_com_ligacao/3` (`armazenamento.pl:140`) percorre por backtracking todas as transições e todos os nós que satisfazem a conjunção, e devolve todos os fluxos que casam. [outras partes: onde]
- [x] `findall/3`, `bagof/3`, `setof/3` ou similares: `setof/3` com quantificador existencial `^` em `nomes_onde/3` (`armazenamento.pl:152`), que dá a lista de nomes ordenada e sem repetição. [outras partes: onde]
- [ ] Corte (`!`) ou negação (`\+`), e por que foram necessários: [onde]
- [ ] Programação por restrições (CLP(FD) ou outra): [onde]
- [x] Predicados de ordem superior (`maplist`, `foldl`, `include`...): `forall/2` para gravar cada nó e transição (`armazenamento.pl:63-66`); `maplist/3` com lambda da `library(yall)` para converter os nomes (`armazenamento.pl:154`); `nomes_onde/3` recebe o próprio objetivo da consulta como argumento. [outras partes: onde]
- [ ] Outro: [...]

### 5.3 Trecho em destaque

<!--
  Escolha o trecho de Prolog de que o grupo mais se orgulha (ou o mais
  difícil). Cole o código e explique como ele funciona: o que é declarado,
  como o Prolog chega à resposta, e por que essa solução é "lógica" e não
  uma tradução de um algoritmo imperativo.
-->

```prolog
[trecho]
```

[Explicação.]

## 6. Parte em Elm

### 6.1 Modelo e mensagens

<!--
  Os tipos centrais do programa: o Model, o tipo Msg e os custom types do
  domínio. Explique as escolhas: por que um custom type e não um Bool, por
  que Maybe ou Result, etc.
-->

```elm
[type alias Model = ...]
[type Msg = ...]
```

[Explicação das escolhas.]

**Fluxos salvos (`frontend/src/Types.elm:27-67`).**

```elm
type SavedFlows
    = LoadingFlows
    | LoadedFlows (List String)
    | FlowsFailed String

type FlowFilter
    = AllFlows
    | UsingNode NodeType

type StorageStatus
    = NoStorageStatus
    | StorageBusy
    | StorageDone StorageAction String
    | StorageFailed String
```

- `SavedFlows` em vez de `List String` mais um `Bool` de "carregando" e um
  `Maybe String` de erro: com três campos soltos, a tela poderia estar
  "carregando" e "com erro" ao mesmo tempo. Com o custom type, a lista só
  existe dentro de `LoadedFlows`, e o `case` em `viewList`
  (`frontend/src/StorageView.elm:153`) é obrigado a tratar os três estados.
- `FlowFilter` usa `NodeType` em vez de `String`: o filtro só pode ser um tipo
  de nó que existe. A conversão para a string que o Prolog espera fica num
  único lugar (`nodeTypeToString`, `frontend/src/StorageApi.elm:118`).
- `StorageDone` guarda qual ação terminou (`FlowSaved`, `FlowOpened`,
  `FlowDeleted`) e o nome do fluxo, para a mensagem de confirmação certa.

### 6.2 Conceitos do paradigma funcional utilizados

- [ ] Arquitetura Elm (Model, update, view): [onde]
- [x] Custom types e `case` exaustivo: `SavedFlows` e `StorageStatus` em `viewList` e `viewStatus` (`frontend/src/StorageView.elm:80`, `:153`); cada texto novo da tela é um construtor de `TextId`, e `translate` não compila se faltar a versão em pt ou en (`frontend/src/Translations.elm`). Dicionário tipado de traduções (`Language` e `TextId` em `frontend/src/Translations.elm`) e tratamento exaustivo no translate, garantindo em tempo de compilação que todos os textos existam tanto em PT quanto em EN sem strings soltas.
- [ ] `Maybe` e `Result` no lugar de null e exceções: [onde]
- [ ] Funções de ordem superior e aplicação parcial: [onde]
- [x] Composição (`|>`, `>>`): `filterFromString` (`frontend/src/StorageView.elm:121`) com `|>`; `onInput (filterFromString >> ChangeFlowFilter)` no `<select>` do filtro. [outras partes: onde]
- [x] Decoders e encoders JSON: `savedFlowDecoder`, que usa `Decode.oneOf` para aceitar fluxos sem gatilho (`frontend/src/StorageApi.elm:92`), e o encoder em `saveFlow` (`frontend/src/StorageApi.elm:63`). [outras partes: onde]
- [x] Comandos e subscriptions (efeitos controlados): Uso de Elm Ports (`port saveApiKey` em `frontend/src/Main.elm`) para delegar a comunicação com o `localStorage` do navegador (efeito colateral impuro) para o JavaScript, preservando a pureza da arquitetura Elm.
- [ ] Imutabilidade e atualização de records: [onde]
- [ ] Outro: [...]

### 6.3 Trecho em destaque

```elm
[trecho]
```

[Explicação.]

## 7. Integração

<!--
  Curto: a parte Python não é avaliada. Liste as rotas ou a forma de
  comunicação e o formato dos dados trocados. Se o grupo não usou Python,
  explique como Elm e Prolog se comunicam.
-->

| Rota / chamada | Entrada | Saída | Predicado Prolog |
|----------------|---------|-------|------------------|
| [`POST /api/...`] | [...] | [...] | [`...`] |
| `GET /fluxos` | `?tipo=post` (opcional) | `{"fluxos": ["a", "b"]}` | `fluxos_salvos/1` ou `fluxos_com_tipo/2` |
| `POST /fluxos` | `{"nome", "diagram_text", "trigger_input"}` | `{"nome"}`; 400 se o nome for vazio ou o diagrama não tiver nós | `salvar_fluxo/3` |
| `GET /fluxos/{nome}` | — | `{"nome", "diagram_text", "trigger_input"}`; 404 se não existir | `carregar_fluxo/3` |
| `DELETE /fluxos/{nome}` | — | `{"nome"}`; 404 se não existir | `remover_fluxo/1` |

## 8. Testes e validação

<!--
  Como o grupo sabe que o sistema funciona? Testes automatizados (plunit,
  pytest, elm-test), roteiros de teste manual, casos de borda verificados.
-->

- [O que foi testado e como.]
- [Casos de borda considerados.]
- **Frontend (elm-test):** 75 testes em `frontend/tests/` (`make test-elm`), todos sobre funções puras, sem navegador nem backend. `DomainTest` e `FlowParserTest` cobrem os casos de borda do domínio: texto vazio, nó duplicado, ligação para nó não declarado, ciclo (inclusive auto-laço), losango e ligações duplas que não são ciclo, fim de linha do Windows (`\r\n`) e `PROMPT` com dois-pontos no texto. `ApiErrorTest` cobre os formatos de erro do FastAPI (`detail` em texto, em lista no 422, corpo que não é JSON, corpo vazio).
- **Prolog (fsm.pl):** [N] testes plunit em `backend/prolog/test_fsm.pl` (`make test-prolog`) para [o que eles cobrem].

- **Armazenamento (parte 2):** 24 testes plunit em
  `backend/prolog/test_armazenamento.pl` (`make test-prolog`) e 14 testes
  pytest das rotas em `backend/tests/test_fluxos.py`, rodando o Prolog de
  verdade. Cada teste usa um arquivo de base temporário.
- **Casos de borda do armazenamento:** nome vazio ou só com espaços (recusado,
  400); diagrama sem nós (recusado, 400); fluxo inexistente (404); salvar de
  novo com o mesmo nome (substitui, inclusive o gatilho); nome com espaço e
  acento na URL; fluxo sem gatilho aberto depois de um com gatilho (o campo é
  limpo); fluxos salvos antes de existir o gatilho (abrem com gatilho vazio);
  fechar e reabrir a base (os fluxos continuam lá); nome com aspas e
  parênteses, como `x"), halt, ("`, que é guardado como texto e não vira
  código Prolog.



- **Interface Visual e Integração (Parte 6):** Roteiro de testes manuais focados na persistência e reatividade da SPA (Single Page Application).
- **Casos de borda visuais:** 
Persistência Segura: Atualizações de página (F5) não perdem a Chave de API, validando o isolamento via Elm Ports e localStorage. Estado Imutável: A alternância do idioma (PT/EN) não interfere no fluxo desenhado nem apaga o grafo visualizado.


## 9. Limitações e problemas conhecidos

<!--
  Seja honesto. Um problema conhecido e bem descrito vale mais que um
  problema escondido que o avaliador descobre sozinho.
-->

- [Limitação ou bug conhecido, e em que situação acontece.]
- [O que o grupo faria com mais tempo.]


## 10. Contribuição de cada integrante

<!--
  O que cada pessoa fez. Deve ser coerente com o histórico de commits do
  repositório. Todos os integrantes precisam concordar com esta tabela.
-->

| Integrante | Principais contribuições |
|------------|--------------------------|
| Eduarda Domingos Rodrigues | [...] |
| Eduardo de Almeida Ferreira | Testes plunit do motor de fluxos (`fsm.pl`) com o alvo no `make test-prolog`; configuração do `elm-test` e do `make test-elm`, com testes de `Domain` (ids, eventos, URLs, nó duplicado, ligação para nó inexistente e ciclos) e de `FlowParser` (erros de sintaxe com número da linha) em `frontend/tests/`; módulo `ApiError.elm`, que guarda o `detail` das respostas de erro do FastAPI para a tela mostrá-lo, e `ExecutionOutcome` no lugar do `status` em `String`; remoção da inicialização duplicada do Elm e do Mermaid no `index.html`; atualização da seção de arquitetura e de uso do README. |
| Eduardo de Almeida Morais | Parte 2: armazenamento de fluxos como fatos em Prolog (`armazenamento.pl`) e testes plunit; rotas `/fluxos` e pytest; tela "Fluxos salvos" em Elm (`StorageView.elm`, `StorageApi.elm`); gatilho salvo junto com o fluxo; correções de configuração (versão do Elm, CORS, `make test-prolog`). |
| Leonardo Michalski Miranda | [...] |
| Letícia de Carvalho dos Santos | [...] |
| Maria Samara Alves Silva | Interface de usuário e integração frontend em Elm. Implementou a internacionalização (i18n) segura através de Custom Types (Translations.elm); desenvolveu a persistência da Chave de API utilizando Elm Ports e localStorage via JavaScript (main.js e Main.elm); criou o feedback visual reativo para erros do Parser (View.elm). |
| Yan Lucas Souza Guimarães | [...] |

<!--
  Além desta tabela, que é do grupo, cada integrante entrega uma avaliação
  360 graus individual no SEU repositório do GitHub Classroom, em
  avaliacao-360/<matricula>.md. Veja o modelo em avaliacao-360/TEMPLATE.md.
-->

## 11. Fontes, código de terceiros e uso de IA

<!--
  Declare tudo o que não foi escrito pelo grupo. Declarar não tira pontos;
  deixar de declarar pode anular o trabalho.
-->

**Código reaproveitado.** [Ex.: "Partimos do template do Sudoku. Mantivemos
a integração Python e a estrutura do frontend; o arquivo `x.pl` e os
módulos `Y.elm` e `Z.elm` foram escritos pelo grupo."]

**Referências.** [Livros, documentação, tutoriais, repositórios consultados.]

**Uso de ferramentas de IA.**

- **Faixa de uso no código:** [nenhum | pontual | auxiliar | intensivo]
  <!--
    nenhum: não usou. pontual: autocompletar, dúvidas, explicar erros.
    auxiliar: trechos gerados pela IA e revisados pelo grupo. intensivo: a
    IA escreveu a maior parte do código. Veja o efeito em AVALIACAO.md,
    seção 1.5. Não declarar anula o trabalho; declarar não tira pontos.
  -->

| Ferramenta | Para que foi usada | Como o grupo verificou o resultado |
|------------|--------------------|------------------------------------|
| [Nome ou "nenhuma"] | [...] | [...] |
| Claude | Gerou o código da parte de armazenamento (Prolog do armazenamento, rotas `/fluxos`, tela "Fluxos salvos" em Elm) e os testes; explicou o código e ajudou a configurar o ambiente, porém tudo foi revisado pelo grupo | Testes automatizados (plunit e pytest), roteiro de teste manual na tela, revisão do código e explicação de cada parte |
| Gemini / ChatGPT | Auxílio na Parte 6: resolução de erros de build do Vite, elaboração do dicionário de tradução e código para integração do Elm Ports com LocalStorage. | Revisão da compilação e teste manual contínuo no navegador para garantir que a UI e a chave de API mantinham o comportamento desejado. |


## 12. Apresentação oral

<!--
  A apresentação tem 15 minutos e acontece no final do semestre. Uma
  divisão que costuma funcionar: 2 min de contexto, 5 min de demonstração
  do sistema funcionando, 6 min mostrando o código Prolog e Elm mais
  interessante, 2 min de limitações e aprendizados. Todos os integrantes
  devem falar.

  Preencha esta seção antes da apresentação.
-->

- **Slides:** [mesmo caminho indicado na seção 1, ou "não há"]
- **Roteiro:**

| Parte | Duração | Quem apresenta |
|-------|:-------:|----------------|
| [Contexto e objetivo] | [2 min] | [Nome] |
| [Demonstração] | [5 min] | [Nome] |
| [Código Prolog] | [3 min] | [Nome] |
| [Código Elm] | [3 min] | [Nome] |
| [Limitações e aprendizados] | [2 min] | [Nome] |

## 13. Reflexão sobre os paradigmas

<!--
  De 1 a 3 parágrafos. Perguntas que podem ajudar:
  - O que ficou mais simples em Prolog do que seria numa linguagem
    imperativa? E o que ficou mais difícil?
  - O que o compilador do Elm impediu que desse errado?
  - Como a forma de pensar mudou entre as duas linguagens?
-->

[Reflexão.]

---

<!--
  CHECKLIST ANTES DE ENTREGAR (apague esta seção depois de conferir)

  - [ ] `uv run scripts/validar_entrega.py` termina sem erros.
  - [ ] Todos os integrantes, com matrícula e turma, estão na seção 1.
  - [ ] O commit ou tag da seção 1 existe no repositório e é a versão final.
  - [ ] As instruções da seção 3 funcionam numa máquina sem nada instalado
        além dos requisitos listados.
  - [ ] Os locais indicados (arquivo:linha) conferem com o commit entregue.
  - [ ] As seções 10 e 11 foram revisadas por todo o grupo.
  - [ ] Se há slides, o arquivo está no repositório e o caminho da seção 1
        está certo.
  - [ ] Cada integrante entregou a própria avaliação 360 graus no seu
        repositório individual, em avaliacao-360/<matricula>.md.
  - [ ] Nenhum texto entre [colchetes] ou comentário de instrução sobrou.
-->