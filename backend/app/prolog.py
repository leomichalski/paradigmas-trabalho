"""Ponte entre Python e Prolog usando a biblioteca pyswip.

Para mais detalhes sobre pyswip: https://github.com/yuce/pyswip
"""

from pathlib import Path

from pyswip import Prolog


PROLOG_FILE = Path(__file__).parent.parent / "prolog" / "fsm.pl"

pyswipProlog = Prolog()
pyswipProlog.consult(str(PROLOG_FILE))


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
"""):
    # Escape quotes and newlines for Prolog query string
    diagram_escaped = diagram_text.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n")
    query_str = f"execute_workflow_from_text('{diagram_escaped}', '{api_key}', LogOut)"

    result = list(pyswipProlog.query(query_str))
    if result:
        log_out = result[0]['LogOut']
        if isinstance(log_out, bytes):
            log_out = log_out.decode('utf-8')
        return log_out
    else:
        return "Execution failed."
