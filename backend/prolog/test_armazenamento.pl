/*  Testes do armazenamento (parte #2).
    Rodar: swipl -g run_tests -t halt backend/prolog/test_armazenamento.pl
*/
:- use_module(armazenamento).
:- use_module(library(plunit)).

/* ---------------- fluxos de exemplo ---------------- */

texto_simples(
"graph TD
    oi[\"PROMPT: Oi\"]
    send[\"POST: https://httpbin.org/post\"]
    abort[\"ABORT\"]
    done[\"DONE\"]

    oi -->|prompt_succeeded| send
    oi -->|prompt_failed| abort
    send -->|request_succeeded| done
    send -->|request_failed| abort").

texto_busca(
"graph TD
    start[\"FETCH: https://jsonplaceholder.typicode.com/posts/1\"]
    done[\"DONE\"]
    start -->|fetch_succeeded| done").

salvar_exemplos :-
    texto_simples(T1), salvar_fluxo("simples", T1),
    texto_busca(T2),   salvar_fluxo("busca", T2).

/* ---------------- base temporária para cada teste ---------------- */

abrir_base_temporaria :-
    tmp_file(fluxos, Arquivo),
    nb_setval(arquivo_teste, Arquivo),
    abrir_base(Arquivo).

%  Cada teste começa só com os dois fluxos de exemplo.
reiniciar :-
    apagar_tudo,
    salvar_exemplos.

apagar_tudo :-
    fluxos_salvos(Ns),
    forall(member(N, Ns), remover_fluxo(N)).

fechar_base_temporaria :-
    apagar_tudo,
    fechar_base,
    nb_getval(arquivo_teste, Arquivo),
    (exists_file(Arquivo) -> delete_file(Arquivo) ; true).

/* ---------------- tipo de cada ação ---------------- */

:- begin_tests(tipo_da_acao).

test(prompt) :- tipo_da_acao("PROMPT: Oi", prompt).
test(post)   :- tipo_da_acao("POST: https://httpbin.org/post", post).
test(fetch)  :- tipo_da_acao("FETCH: https://x.com", fetch).
test(done)   :- tipo_da_acao("DONE", done).
test(abort)  :- tipo_da_acao(" ABORT ", abort).

:- end_tests(tipo_da_acao).

/* ---------------- salvar, carregar, remover ---------------- */

:- begin_tests(armazenamento,
               [ setup(abrir_base_temporaria),
                 cleanup(fechar_base_temporaria) ]).

test(carrega_o_mesmo_texto, [setup(reiniciar)]) :-
    texto_simples(T),
    carregar_fluxo("simples", T).

test(salvar_de_novo_substitui, [setup(reiniciar)]) :-
    texto_busca(T),
    salvar_fluxo("simples", T),
    carregar_fluxo("simples", T),
    fluxos_com_tipo("prompt", []).

test(fluxo_inexistente, [setup(reiniciar), fail]) :-
    carregar_fluxo("nao_existe", _).

test(texto_sem_nos_nao_e_salvo, [setup(reiniciar), fail]) :-
    salvar_fluxo("vazio", "graph TD\n").

test(nome_vazio_nao_e_salvo, [setup(reiniciar), fail]) :-
    texto_busca(T),
    salvar_fluxo("   ", T).

test(nome_com_espacos_nas_pontas, [setup(reiniciar)]) :-
    texto_busca(T),
    salvar_fluxo("  meu fluxo ", T),
    carregar_fluxo("meu fluxo", T).

test(remover, [setup(reiniciar)]) :-
    remover_fluxo("simples"),
    fluxos_salvos(["busca"]).

test(persiste_no_arquivo, [setup(reiniciar)]) :-
    fechar_base,
    nb_getval(arquivo_teste, Arquivo),
    abrir_base(Arquivo),
    fluxos_salvos(["busca", "simples"]).

:- end_tests(armazenamento).

/* ---------------- consultas ---------------- */

:- begin_tests(consultas,
               [ setup(abrir_base_temporaria),
                 cleanup(fechar_base_temporaria) ]).

test(listar, [setup(reiniciar)]) :-
    fluxos_salvos(["busca", "simples"]).

test(quais_usam_post, [setup(reiniciar)]) :-
    fluxos_com_tipo("POST", ["simples"]).

test(quais_usam_done, [setup(reiniciar)]) :-
    fluxos_com_tipo("done", ["busca", "simples"]).

test(ninguem_usa_tipo, [setup(reiniciar)]) :-
    fluxos_com_tipo("planilha", []).

test(quais_tratam_falha_do_prompt, [setup(reiniciar)]) :-
    fluxos_com_evento("prompt_failed", ["simples"]).

test(ligacao_prompt_post, [setup(reiniciar)]) :-
    fluxos_com_ligacao("PROMPT", "POST", ["simples"]).

test(ligacao_fetch_done, [setup(reiniciar)]) :-
    fluxos_com_ligacao("fetch", "done", ["busca"]).

:- end_tests(consultas).
