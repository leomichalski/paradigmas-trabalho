from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_sequencial():
    diagrama = """graph TD
        start["FETCH: https://jsonplaceholder.typicode.com/posts/1"]
        summarize["PROMPT: Resuma: {{input}}"]
        send["POST: https://httpbin.org/post"]
        done["DONE"]

        start -->|fetch_succeeded| summarize
        summarize -->|summary_generated| send
        send -->|request_succeeded| done
    """
    resp = client.post("/analyze", json={"diagram_text": diagrama})

    assert resp.status_code == 200
    dados = resp.json()
    assert dados["valid"] is True
    assert dados["has_cycle"] is False
    assert dados["unreachable_nodes"] == []
    assert dados["parallel_levels"] == [["start"], ["summarize"], ["send"], ["done"]]
    assert dados["execution_order"] == ["start", "summarize", "send", "done"]


def test_paralelo():
    diagrama = """graph TD
        oi["PROMPT: Oi"]
        send["POST: https://httpbin.org/post"]
        send2["POST: https://httpbin.org/post"]
        abort["ABORT"]
        done["DONE"]

        oi -->|prompt_succeeded| send
        oi -->|prompt_succeeded| send2
        oi -->|prompt_failed| abort
        send -->|request_succeeded| done
        send -->|request_failed| abort
        send2 -->|request_succeeded| done
        send2 -->|request_failed| abort
    """
    resp = client.post("/analyze", json={"diagram_text": diagrama})

    assert resp.status_code == 200
    dados = resp.json()
    assert dados["valid"] is True
    assert dados["has_cycle"] is False
    assert dados["unreachable_nodes"] == []
    assert dados["parallel_levels"] == [["oi"], ["send", "send2"], ["abort", "done"]]
    assert dados["execution_order"] == ["oi", "send", "send2", "abort", "done"]


def test_ciclo():
    diagrama = """graph TD
        oi["PROMPT: Oi"]
        send["POST: https://httpbin.org/post"]
        done["DONE"]

        oi -->|prompt_succeeded| send
        send -->|loop| oi
        send -->|request_succeeded| done
    """
    resp = client.post("/analyze", json={"diagram_text": diagrama})

    assert resp.status_code == 200
    dados = resp.json()
    assert dados["valid"] is False
    assert dados["has_cycle"] is True
    assert "oi" in dados["cycle"]
    assert "send" in dados["cycle"]
    assert dados["parallel_levels"] == []
    assert dados["execution_order"] == []


def test_auto_laco():
    diagrama = """graph TD
        oi["PROMPT: Oi"]
        oi -->|loop| oi
    """
    resp = client.post("/analyze", json={"diagram_text": diagrama})

    assert resp.status_code == 200
    dados = resp.json()
    assert dados["valid"] is False
    assert dados["has_cycle"] is True
    assert dados["cycle"] == ["oi", "oi"]


def test_nos_inalcancaveis():
    diagrama = """graph TD
        oi["PROMPT: Oi"]
        done["DONE"]
        esquecido["FETCH: https://example.com"]
        extra1["FETCH: https://example.com/1"]
        extra2["POST: https://example.com/2"]

        oi -->|ok| done
        extra1 -->|ok| extra2
    """
    resp = client.post("/analyze", json={"diagram_text": diagrama})

    assert resp.status_code == 200
    dados = resp.json()
    assert dados["valid"] is False
    assert dados["has_cycle"] is False
    assert set(dados["unreachable_nodes"]) == {"esquecido", "extra1", "extra2"}


def test_diagrama_vazio():
    resp = client.post("/analyze", json={"diagram_text": "graph TD\n"})

    assert resp.status_code == 200
    dados = resp.json()
    assert dados["has_cycle"] is False
    assert dados["unreachable_nodes"] == []
    assert dados["parallel_levels"] == []
    assert dados["execution_order"] == []


def test_sem_diagrama():
    resp = client.post("/analyze", json={})
    assert resp.status_code == 422


def test_execute_rejects_cycle():
    diagram = """graph TD
        hello["PROMPT: Hello"]
        send["POST: https://httpbin.org/post"]

        hello -->|summary_generated| send
        send -->|request_succeeded| hello
    """
    resp = client.post("/execute", json={"api_key": "x", "diagram_text": diagram})

    assert resp.status_code == 400
    assert resp.json()["detail"] == "Workflow has a cycle: hello -> send -> hello"
