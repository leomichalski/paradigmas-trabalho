from fastapi.testclient import TestClient
from unittest.mock import patch

from app.main import app

client = TestClient(app)

EXAMPLE_DIAGRAM = """graph TD
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
"""

EXAMPLE_LOG_OUTPUT = "Starting workflow at state: start\nExecuting FETCH: https://jsonplaceholder.typicode.com/posts/1\nFETCH succeeded."


# Usamos o patch para interceptar a chamada 'prolog.execute_workflow'
# ATENÇÃO: Mude 'main.prolog.execute_workflow' para o caminho real de onde
# a variável 'prolog' está importada no seu arquivo FastAPI.
@patch("app.main.prolog.execute_workflow")
def test_execute_workflow_success(mock_execute):
    # Simula o retorno de sucesso do motor prolog
    mock_execute.return_value = EXAMPLE_LOG_OUTPUT

    response = client.post(
        "/execute",
        json={
            "api_key": "test_fake_api_key",
            "diagram_text": EXAMPLE_DIAGRAM
        }
    )

    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert data["message"] == "Workflow executed successfully"
    assert "Starting workflow at state: start" in data["logs"]


def test_execute_rejects_missing_fields():
    # Quem rejeita aqui é o Pydantic, antes mesmo de tentar executar.
    # Faltando 'diagram_text'
    response = client.post("/execute", json={"api_key": "123"})
    assert response.status_code == 422
    assert response.json()["detail"][0]["type"] == "missing"


def test_execute_rejects_empty_body():
    # Envia um JSON vazio
    response = client.post("/execute", json={})
    assert response.status_code == 422


@patch("app.main.prolog.execute_workflow")
def test_execute_handles_validation_error(mock_execute):
    # Simula o motor do Prolog lançando um ValueError (ex: diagrama inválido)
    mock_execute.side_effect = ValueError("Diagrama com sintaxe incorreta.")

    response = client.post(
        "/execute",
        json={
            "api_key": "test_fake_api_key",
            "diagram_text": "graph TD\n invalid_node"
        }
    )

    # O FastAPI (nosso try/except) deve converter o ValueError em HTTP 400
    assert response.status_code == 400
    assert response.json()["detail"] == "Diagrama com sintaxe incorreta."


@patch("app.main.prolog.execute_workflow")
def test_execute_handles_unexpected_error(mock_execute):
    # Simula uma exceção genérica no servidor (ex: queda do banco, erro de memória)
    mock_execute.side_effect = Exception("Erro bizarro no sistema")

    response = client.post(
        "/execute",
        json={
            "api_key": "test_fake_api_key",
            "diagram_text": EXAMPLE_DIAGRAM
        }
    )

    # O FastAPI deve capturar com o 'except Exception' e retornar HTTP 500
    assert response.status_code == 500
    assert "Erro bizarro no sistema" in response.json()["detail"]

# Cobertura do suporte a arquivos MP4 no nó PROMPT.
import io

@patch("app.main._extract_video_frames", return_value=["data:image/jpeg;base64,ZmFrZQ=="])
@patch("app.main.prolog.execute_workflow", return_value=EXAMPLE_LOG_OUTPUT)
def test_execute_accepts_mp4(mock_execute, mock_frames):
    response = client.post("/execute", data={"api_key": "test", "diagram_text": EXAMPLE_DIAGRAM},
        files={"video": ("sample.mp4", io.BytesIO(b"mp4 bytes"), "video/mp4")})
    assert response.status_code == 200
    mock_frames.assert_called_once()
    assert "data:image/jpeg;base64,ZmFrZQ==" in mock_execute.call_args.kwargs["video_frames"]


def test_execute_rejects_non_mp4_upload():
    response = client.post("/execute", data={"api_key": "test", "diagram_text": EXAMPLE_DIAGRAM},
        files={"video": ("sample.mov", io.BytesIO(b"not mp4"), "video/quicktime")})
    assert response.status_code == 200
    assert response.json()["status"] == "failed"
    assert "video/mp4" in response.json()["logs"]


def test_execute_rejects_video_over_size_limit(monkeypatch):
    from app import main
    monkeypatch.setattr(main, "MAX_VIDEO_SIZE", 4)
    response = client.post("/execute", data={"api_key": "test", "diagram_text": EXAMPLE_DIAGRAM},
        files={"video": ("sample.mp4", io.BytesIO(b"12345"), "video/mp4")})
    assert response.status_code == 200
    assert response.json()["status"] == "failed"
    assert "25 MB" in response.json()["logs"]


@patch("app.main.prolog.execute_workflow", return_value="PROMPT failed: missing_video_file")
def test_execution_reports_missing_video_as_failed(mock_execute):
    response = client.post("/execute", json={"api_key": "test",
        "diagram_text": 'graph TD\\nstart["PROMPT: resumo {{inputVideo}}"]'})
    assert response.status_code == 200
    assert response.json()["status"] == "failed"
