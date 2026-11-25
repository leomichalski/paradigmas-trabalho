"""Testes das rotas /fluxos (parte #2), com o Prolog de verdade.

Cada teste usa um arquivo de base novo, então um não interfere no outro
e a base real (backend/data/fluxos.db) nunca é tocada.
"""

import os
import tempfile

# Antes de importar o app, para ele não abrir a base real.
os.environ["FLUXOS_DB"] = os.path.join(tempfile.mkdtemp(), "inicial.db")

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app import armazenamento  # noqa: E402
from app.main import app  # noqa: E402

client = TestClient(app)

SIMPLES = """graph TD
    oi["PROMPT: Oi"]
    send["POST: https://httpbin.org/post"]
    done["DONE"]
    oi -->|prompt_succeeded| send
    send -->|request_succeeded| done
"""

BUSCA = """graph TD
    start["FETCH: https://jsonplaceholder.typicode.com/posts/1"]
    done["DONE"]
    start -->|fetch_succeeded| done
"""


@pytest.fixture(autouse=True)
def base_vazia(tmp_path):
    armazenamento.usar_base(tmp_path / "fluxos.db")


def salvar(nome, texto):
    return client.post("/fluxos", json={"nome": nome, "diagram_text": texto})


def test_comeca_vazio():
    assert client.get("/fluxos").json() == {"fluxos": []}


def test_salvar_e_abrir():
    assert salvar("simples", SIMPLES).status_code == 200
    r = client.get("/fluxos/simples")
    assert r.status_code == 200
    assert r.json() == {"nome": "simples", "diagram_text": SIMPLES}


def test_listar_em_ordem():
    salvar("simples", SIMPLES)
    salvar("busca", BUSCA)
    assert client.get("/fluxos").json() == {"fluxos": ["busca", "simples"]}


def test_filtrar_por_tipo():
    salvar("simples", SIMPLES)
    salvar("busca", BUSCA)
    assert client.get("/fluxos?tipo=post").json() == {"fluxos": ["simples"]}
    assert client.get("/fluxos?tipo=done").json() == {"fluxos": ["busca", "simples"]}
    assert client.get("/fluxos?tipo=planilha").json() == {"fluxos": []}


def test_salvar_de_novo_substitui():
    salvar("f", SIMPLES)
    salvar("f", BUSCA)
    assert client.get("/fluxos/f").json()["diagram_text"] == BUSCA
    assert client.get("/fluxos?tipo=post").json() == {"fluxos": []}


def test_nome_com_espaco_e_acento():
    salvar("resumo de notícias", SIMPLES)
    r = client.get("/fluxos/resumo%20de%20not%C3%ADcias")
    assert r.status_code == 200


def test_nome_vazio_da_400():
    assert salvar("   ", SIMPLES).status_code == 400


def test_diagrama_sem_nos_da_400():
    assert salvar("vazio", "graph TD\n").status_code == 400


def test_abrir_inexistente_da_404():
    assert client.get("/fluxos/nao_existe").status_code == 404


def test_apagar():
    salvar("simples", SIMPLES)
    assert client.delete("/fluxos/simples").status_code == 200
    assert client.get("/fluxos").json() == {"fluxos": []}


def test_apagar_inexistente_da_404():
    assert client.delete("/fluxos/nao_existe").status_code == 404


def test_aspas_no_nome_nao_viram_codigo_prolog():
    # Se o texto fosse colado direto na consulta, isto quebraria o Prolog.
    nome = 'x"), halt, ("'
    assert salvar(nome, SIMPLES).status_code == 200
    assert client.get("/fluxos").json() == {"fluxos": [nome]}


def test_continua_salvo_depois_de_reabrir(tmp_path):
    salvar("simples", SIMPLES)
    armazenamento.usar_base(tmp_path / "fluxos.db")
    assert client.get("/fluxos").json() == {"fluxos": ["simples"]}
