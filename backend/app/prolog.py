"""Ponte entre Python e Prolog usando a biblioteca pyswip.

Para mais detalhes sobre pyswip: https://github.com/yuce/pyswip
"""

from pathlib import Path

from pyswip import Prolog


PROLOG_FILE = Path(__file__).parent.parent / "prolog" / "fsm.pl"

pyswipProlog = Prolog()
pyswipProlog.consult(str(PROLOG_FILE))
GRAPH_FILE = Path(__file__).parent.parent / "prolog" / "graph.pl"
pyswipProlog.consult(str(GRAPH_FILE))


def execute_workflow(
    api_key,
    diagram_text="""\
graph TD
    start["FETCH: https://jsonplaceholder.typicode.com/posts/1"]
    summarize["PROMPT: Summarize the following JSON: {{input}}"]
    send["POST: https://httpbin.org/post"]
    abort["ABORT"]
    done["DONE"]

    start -->|fetch_succeeded| summarize
    start -->|fetch_failed| abort
    summarize -->|summary_generated| send
    summarize -->|generation_failed| abort
    send -->|request_succeeded| done
    send -->|request_failed| abort
""",
    trigger_input=None
):
    # Escape quotes and newlines for Prolog query string
    diagram_escaped = diagram_text.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n")
    safe_trigger = trigger_input if trigger_input is not None else ""
    trigger_escaped = safe_trigger.replace("\\", "\\\\").replace("'", "\\'")
    query_str = f"execute_workflow_from_text('{diagram_escaped}', '{trigger_escaped}', '{api_key}', LogOut)"

    result = list(pyswipProlog.query(query_str))
    if result:
        log_out = result[0]['LogOut']
        if isinstance(log_out, bytes):
            log_out = log_out.decode('utf-8')
        return log_out
    else:
        return "Execution failed."


def _para_str(item):
    if isinstance(item, bytes):
        return item.decode("utf-8")
    if isinstance(item, list):
        return [_para_str(x) for x in item]
    return str(item)


def analyze_graph(diagram_text: str) -> dict:
    diagram_escaped = diagram_text.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n")
    query_str = (
        f"parse_mermaid_text('{diagram_escaped}', Nodes, Transitions), "
        f"analisar_grafo(Nodes, Transitions, TemCiclo, Ciclo, Inalcancaveis, Niveis, Ordem)"
    )

    result = list(pyswipProlog.query(query_str))
    if not result:
        raise ValueError("Erro ao analisar o diagrama.")

    row = result[0]
    tem_ciclo = _para_str(row["TemCiclo"]) == "true"
    ciclo = _para_str(row["Ciclo"])
    inalcancaveis = _para_str(row["Inalcancaveis"])
    niveis = _para_str(row["Niveis"])
    ordem = _para_str(row["Ordem"])

    return {
        "valid": (not tem_ciclo) and len(inalcancaveis) == 0,
        "has_cycle": tem_ciclo,
        "cycle": ciclo,
        "unreachable_nodes": inalcancaveis,
        "parallel_levels": niveis,
        "execution_order": ordem,
    }