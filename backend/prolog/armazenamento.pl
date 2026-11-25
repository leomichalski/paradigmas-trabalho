/*  armazenamento.pl — Parte #2: fluxos salvos como fatos e consultas.

    Um fluxo é salvo a partir do texto Mermaid do editor.

    O texto é lido pelo mesmo parser do executor (fsm.pl) e vira fatos.

    Os fatos são gravados num arquivo pela library(persistency), então
    continuam lá depois que o servidor reinicia.
*/
:- module(armazenamento, [
    abrir_base/1, fechar_base/0,
    salvar_fluxo/2, carregar_fluxo/2, remover_fluxo/1,
    fluxos_salvos/1, fluxos_com_tipo/2, fluxos_com_evento/2,
    fluxos_com_ligacao/3,
    tipo_da_acao/2
]).

:- use_module(library(persistency)).
:- use_module(library(apply)).
:- use_module(library(yall)).

%  O parser (parse_mermaid_text/3) fica no fsm.pl, carregado no módulo user.
%  ensure_loaded não carrega de novo se a ponte já tiver feito consult dele.
:- user:ensure_loaded(fsm).

/* ------------------------------------------------------------------
   1. Os fatos guardados
   ------------------------------------------------------------------ */

:- persistent
    fluxo_texto(fluxo:atom, texto:string),
    fluxo_no(fluxo:atom, id:atom, tipo:atom),
    fluxo_transicao(fluxo:atom, origem:atom, evento:atom, destino:atom).

%  abrir_base(+Arquivo): liga os fatos ao arquivo e recarrega o que já
%  estava salvo. Chamar uma vez quando o servidor inicia.
abrir_base(Arquivo) :- db_attach(Arquivo, []).
fechar_base :- db_detach.

/* ------------------------------------------------------------------
   2. Salvar, carregar, remover
   ------------------------------------------------------------------ */

%  salvar_fluxo(+Nome, +Texto): lê o diagrama e grava os fatos.
%  Se já existe um fluxo com esse nome, ele é substituído.
%  Falha se o nome for vazio ou o texto não tiver nenhum nó.
salvar_fluxo(Nome, Texto) :-
    nome_valido(Nome, F),
    text_to_string(Texto, TextoS),
    user:parse_mermaid_text(TextoS, Nos, Transicoes),
    Nos \= [],
    with_mutex(armazenamento,
        ( apagar(F),
          assert_fluxo_texto(F, TextoS),
          forall(member(node(Id, Acao), Nos),
                 gravar_no(F, Id, Acao)),
          forall(member(transition(O, E, D), Transicoes),
                 gravar_transicao(F, O, E, D))
        )).

gravar_no(F, Id, Acao) :-
    atom_string(IdA, Id),
    tipo_da_acao(Acao, Tipo),
    assert_fluxo_no(F, IdA, Tipo).

gravar_transicao(F, O, E, D) :-
    atom_string(OA, O),
    atom_string(EA, E),
    atom_string(DA, D),
    assert_fluxo_transicao(F, OA, EA, DA).

%  carregar_fluxo(+Nome, -Texto): devolve o diagrama para o editor.
%  Falha se o fluxo não existe.
carregar_fluxo(Nome, Texto) :-
    atom_string(F, Nome),
    fluxo_texto(F, Texto).

remover_fluxo(Nome) :-
    atom_string(F, Nome),
    with_mutex(armazenamento, apagar(F)).

apagar(F) :-
    retractall_fluxo_texto(F, _),
    retractall_fluxo_no(F, _, _),
    retractall_fluxo_transicao(F, _, _, _).

%  O nome não pode ser vazio nem só espaços.
nome_valido(Nome, F) :-
    normalize_space(string(Limpo), Nome),
    Limpo \== "",
    atom_string(F, Limpo).

%  tipo_da_acao(+Acao, -Tipo): "PROMPT: Oi" -> prompt, "DONE" -> done.
%  O tipo é o que vem antes do ':' (ou a ação inteira), em minúsculas.
tipo_da_acao(Acao, Tipo) :-
    (   sub_string(Acao, Antes, _, _, ":")
    ->  sub_string(Acao, 0, Antes, _, Prefixo)
    ;   Prefixo = Acao
    ),
    normalize_space(string(Limpo), Prefixo),
    string_lower(Limpo, Minusculo),
    atom_string(Tipo, Minusculo).

/* ------------------------------------------------------------------
   3. Consultas (sempre devolvem uma lista de nomes, vazia se não houver)
   ------------------------------------------------------------------ */

fluxos_salvos(Nomes) :-
    nomes_onde(F, T^fluxo_texto(F, T), Nomes).

%  "Quais fluxos usam o nó POST?"
fluxos_com_tipo(Tipo, Nomes) :-
    para_atomo(Tipo, T),
    nomes_onde(F, I^fluxo_no(F, I, T), Nomes).

%  "Quais fluxos tratam o evento prompt_failed?"
fluxos_com_evento(Evento, Nomes) :-
    atom_string(E, Evento),
    nomes_onde(F, O^D^fluxo_transicao(F, O, E, D), Nomes).

%  "Quais fluxos ligam um PROMPT direto a um POST?"
%  Junta três fatos: a transição e o tipo de cada ponta.
fluxos_com_ligacao(TipoA, TipoB, Nomes) :-
    para_atomo(TipoA, A),
    para_atomo(TipoB, B),
    nomes_onde(F, O^E^D^( fluxo_transicao(F, O, E, D),
                          fluxo_no(F, O, A),
                          fluxo_no(F, D, B) ), Nomes).

para_atomo(Texto, Atomo) :-
    string_lower(Texto, S),
    atom_string(Atomo, S).

%  setof que devolve [] em vez de falhar, com os nomes em string.
nomes_onde(F, Objetivo, Nomes) :-
    (   setof(F, Objetivo, Fs)
    ->  maplist([A, S]>>atom_string(A, S), Fs, Nomes)
    ;   Nomes = []
    ).
