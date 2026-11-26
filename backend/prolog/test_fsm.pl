:- encoding(utf8).
:- use_module(library(plunit)).
:- ensure_loaded(fsm).

/* ---------------- fluxos de exemplo ---------------- */

%  O fluxo do README, com os cinco tipos de nó.
fluxo_readme(
"graph TD
    start[\"FETCH: https://jsonplaceholder.typicode.com/posts/1\"]
    summarize[\"PROMPT: Summarize the following JSON: {{input}}\"]
    send[\"POST: https://httpbin.org/post\"]
    abort[\"ABORT\"]
    done[\"DONE\"]

    start -->|fetch_succeeded| summarize
    start -->|fetch_failed| abort
    summarize -->|prompt_succeeded| send
    summarize -->|prompt_failed| abort
    send -->|request_succeeded| done
    send -->|request_failed| abort").

fluxo_so_done(
"graph TD
    done[\"DONE\"]").

fluxo_so_abort(
"graph TD
    stop[\"ABORT\"]").

fluxo_fetch_recusado(
"graph TD
    start[\"FETCH: http://127.0.0.1:1/\"]
    abort[\"ABORT\"]
    done[\"DONE\"]

    start -->|fetch_succeeded| done
    start -->|fetch_failed| abort").

fluxo_post_recusado(
"graph TD
    send[\"POST: http://127.0.0.1:1/\"]
    abort[\"ABORT\"]
    done[\"DONE\"]

    send -->|request_succeeded| done
    send -->|request_failed| abort").

fluxo_sem_transicao_de_falha(
"graph TD
    start[\"FETCH: http://127.0.0.1:1/\"]
    done[\"DONE\"]

    start -->|fetch_succeeded| done").

fluxo_acao_desconhecida(
"graph TD
    x[\"VOAR: para longe\"]").

%  Roda o fluxo e devolve o log.
executar(Texto, Log) :-
    once(execute_workflow_from_text(Texto, "", "sem-chave", Log)).

contem(Log, Trecho) :-
    once(sub_string(Log, _, _, _, Trecho)).

/* ---------------- parser ---------------- */

:- begin_tests(parser).

test(no_simples) :-
    parse_node("    start[\"FETCH: http://x.com\"]", Id, Acao),
    Id == "start",
    Acao == "FETCH: http://x.com".

test(no_com_underscore_e_digitos) :-
    parse_node("  passo_2[\"DONE\"]", Id, Acao),
    Id == "passo_2",
    Acao == "DONE".

test(linha_que_nao_e_no, [fail]) :-
    parse_node("graph TD", _, _).

test(transicao) :-
    parse_transition("    a -->|ok| b", Src, Evento, Dst),
    Src == "a", Evento == "ok", Dst == "b".

test(transicao_sem_espacos) :-
    parse_transition("a-->|ok|b", Src, Evento, Dst),
    Src == "a", Evento == "ok", Dst == "b".

test(linha_que_nao_e_transicao, [fail]) :-
    parse_transition("start[\"DONE\"]", _, _, _).

test(texto_do_readme_tem_5_nos_e_6_transicoes) :-
    fluxo_readme(T),
    parse_mermaid_text(T, Nos, Transicoes),
    length(Nos, 5),
    length(Transicoes, 6).

test(ordem_dos_nos_e_preservada) :-
    fluxo_readme(T),
    parse_mermaid_text(T, Nos, _),
    findall(Id, member(node(Id, _), Nos), Ids),
    Ids == ["start", "summarize", "send", "abort", "done"].

test(primeira_transicao_do_readme) :-
    fluxo_readme(T),
    parse_mermaid_text(T, _, [Primeira|_]),
    Primeira == transition("start", "fetch_succeeded", "summarize").

test(ignora_cabecalho_e_linhas_em_branco) :-
    parse_mermaid_text("graph TD\n\n   \n    a[\"DONE\"]\n", Nos, Transicoes),
    Nos == [node("a", "DONE")],
    Transicoes == [].

test(aceita_fim_de_linha_windows) :-
    parse_mermaid_text("graph TD\r\n    a[\"DONE\"]\r\n    b[\"ABORT\"]\r\n", Nos, _),
    Nos == [node("a", "DONE"), node("b", "ABORT")].

test(texto_vazio) :-
    parse_mermaid_text("", Nos, Transicoes),
    Nos == [], Transicoes == [].

:- end_tests(parser).

/* ---------------- execução ---------------- */

:- begin_tests(execucao).

test(comeca_no_primeiro_no_e_termina_em_done) :-
    fluxo_so_done(T), executar(T, Log),
    contem(Log, "Starting workflow at state: done"),
    contem(Log, "Workflow finished at state: done with action: DONE").

test(termina_em_abort) :-
    fluxo_so_abort(T), executar(T, Log),
    contem(Log, "Workflow finished at state: stop with action: ABORT").

test(acao_desconhecida_encerra_com_aviso) :-
    fluxo_acao_desconhecida(T), executar(T, Log),
    contem(Log, "Unknown action: VOAR: para longe").

test(fetch_recusado_segue_a_transicao_de_falha) :-
    fluxo_fetch_recusado(T), executar(T, Log),
    contem(Log, "FETCH failed"),
    contem(Log, "start --[fetch_failed]--> abort"),
    contem(Log, "action: ABORT"),
    \+ contem(Log, "action: DONE").

test(post_recusado_segue_a_transicao_de_falha) :-
    fluxo_post_recusado(T), executar(T, Log),
    contem(Log, "POST failed"),
    contem(Log, "send --[request_failed]--> abort"),
    contem(Log, "action: ABORT").

test(log_registra_a_acao_executada) :-
    fluxo_fetch_recusado(T), executar(T, Log),
    contem(Log, "Executing FETCH: http://127.0.0.1:1/").

%  Sem transição para o evento ocorrido, o motor não tem para onde ir:
%  o predicado falha (o backend converte isso em "Execution failed.").
test(sem_transicao_para_o_evento_a_execucao_falha, [fail]) :-
    fluxo_sem_transicao_de_falha(T),
    executar(T, _).

test(diagrama_sem_nos_falha, [fail]) :-
    executar("graph TD\n", _).

:- end_tests(execucao).
