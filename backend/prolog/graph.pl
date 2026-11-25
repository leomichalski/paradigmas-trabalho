% Analise do grafo do workflow

extrair_ids([], []).
extrair_ids([node(Id, _) | Resto], [Id | RestoIds]) :-
    extrair_ids(Resto, RestoIds).

aresta(Transitions, Origem, Destino) :-
    member(transition(Origem, _, Destino), Transitions).

% Busca todos os nos alcancaveis a partir do inicio
alcancaveis(Transitions, Visitados, Resultado) :-
    member(Atual, Visitados),
    aresta(Transitions, Atual, Proximo),
    \+ member(Proximo, Visitados),
    !,
    alcancaveis(Transitions, [Proximo | Visitados], Resultado).
alcancaveis(_, Visitados, Visitados).

nos_inalcancaveis([], _, []) :- !.
nos_inalcancaveis(Nodes, Transitions, Inalcancaveis) :-
    Nodes = [node(Inicio, _) | _],
    extrair_ids(Nodes, TodosIds),
    alcancaveis(Transitions, [Inicio], Alcancaveis),
    subtract(TodosIds, Alcancaveis, Inalcancaveis).

% Deteccao de ciclos guardando o caminho atual
dfs_ciclo(Transitions, Atual, Caminho, Ciclo) :-
    aresta(Transitions, Atual, Proximo),
    member(Proximo, Caminho),
    !,
    reverse([Proximo | Caminho], Ciclo).

dfs_ciclo(Transitions, Atual, Caminho, Ciclo) :-
    aresta(Transitions, Atual, Proximo),
    \+ member(Proximo, Caminho),
    dfs_ciclo(Transitions, Proximo, [Proximo | Caminho], Ciclo).

encontrar_ciclo(Nodes, Transitions, Ciclo) :-
    extrair_ids(Nodes, TodosIds),
    member(Inicio, TodosIds),
    dfs_ciclo(Transitions, Inicio, [Inicio], Ciclo),
    !.

tem_ciclo(Nodes, Transitions) :-
    encontrar_ciclo(Nodes, Transitions, _).

% Niveis de paralelismo e ordem de execucao
tem_dependencia(No, Restantes, Transitions) :-
    member(Pai, Restantes),
    aresta(Transitions, Pai, No).

calcular_niveis([], _, []) :- !.
calcular_niveis(Restantes, Transitions, [Nivel | Outros]) :-
    findall(No, (
        member(No, Restantes),
        \+ tem_dependencia(No, Restantes, Transitions)
    ), Nivel),
    Nivel \= [],
    subtract(Restantes, Nivel, Proximos),
    calcular_niveis(Proximos, Transitions, Outros).

niveis_paralelismo(Nodes, Transitions, Niveis) :-
    \+ tem_ciclo(Nodes, Transitions),
    extrair_ids(Nodes, TodosIds),
    calcular_niveis(TodosIds, Transitions, Niveis).

ordem_execucao(Nodes, Transitions, Ordem) :-
    niveis_paralelismo(Nodes, Transitions, Niveis),
    append(Niveis, Ordem).

% Junta todas as analises em uma chamada so para o Python
analisar_grafo(Nodes, Transitions, true, Ciclo, Inalcancaveis, [], []) :-
    nos_inalcancaveis(Nodes, Transitions, Inalcancaveis),
    encontrar_ciclo(Nodes, Transitions, Ciclo),
    !.
analisar_grafo(Nodes, Transitions, false, [], Inalcancaveis, Niveis, Ordem) :-
    nos_inalcancaveis(Nodes, Transitions, Inalcancaveis),
    niveis_paralelismo(Nodes, Transitions, Niveis),
    append(Niveis, Ordem).
