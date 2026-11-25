"""Ponte Python -> Prolog para o armazenamento de fluxos (parte #2).

Cada função chama um predicado de backend/prolog/armazenamento.pl.
O Python não guarda nada: só repassa os dados e devolve a resposta.
"""

import os
import threading
from pathlib import Path

from pyswip import Prolog

PROLOG_DIR = Path(__file__).parent.parent / "prolog"
BASE_PADRAO = Path(__file__).parent.parent / "data" / "fluxos.db"

# O pyswip não aceita duas consultas ao mesmo tempo, e o FastAPI atende
# requisições em threads diferentes. A trava faz uma esperar a outra.
_trava = threading.Lock()


def _texto_prolog(valor: str) -> str:
    """Transforma um texto do Python numa string Prolog segura.

    Letras e números passam direto; qualquer outro caractere vira o
    escape \\xHEX\\ do Prolog. Assim, aspas ou parênteses vindos do
    usuário nunca viram código Prolog.
    """
    partes = []
    for c in valor:
        if c.isascii() and c.isalnum():
            partes.append(c)
        else:
            partes.append(f"\\x{ord(c):x}\\")
    return '"' + "".join(partes) + '"'


def _para_str(valor) -> str:
    return valor.decode("utf-8") if isinstance(valor, bytes) else str(valor)


def _consultar(consulta: str) -> list[dict]:
    with _trava:
        return list(Prolog.query(consulta, catcherrors=True))


def usar_base(arquivo: Path | str) -> None:
    """Liga o armazenamento a um arquivo (os testes usam um temporário)."""
    Path(arquivo).parent.mkdir(parents=True, exist_ok=True)
    _consultar("catch(fechar_base, _, true)")
    _consultar(f"abrir_base({_texto_prolog(str(arquivo))})")


def salvar(nome: str, diagrama: str) -> bool:
    """False se o nome for vazio ou o diagrama não tiver nenhum nó."""
    return bool(_consultar(
        f"salvar_fluxo({_texto_prolog(nome)}, {_texto_prolog(diagrama)})"
    ))


def carregar(nome: str) -> str | None:
    """O texto do diagrama, ou None se o fluxo não existe."""
    r = _consultar(f"carregar_fluxo({_texto_prolog(nome)}, Texto)")
    return _para_str(r[0]["Texto"]) if r else None


def remover(nome: str) -> None:
    _consultar(f"remover_fluxo({_texto_prolog(nome)})")


def listar(tipo: str | None = None) -> list[str]:
    """Todos os fluxos, ou só os que usam o tipo de nó (fetch, post...)."""
    if tipo:
        consulta = f"fluxos_com_tipo({_texto_prolog(tipo)}, Nomes)"
    else:
        consulta = "fluxos_salvos(Nomes)"
    r = _consultar(consulta)
    return [_para_str(n) for n in r[0]["Nomes"]] if r else []


# Ao importar: carrega o Prolog e abre o arquivo da base.
Prolog.consult(str(PROLOG_DIR / "armazenamento.pl"))
usar_base(os.environ.get("FLUXOS_DB", BASE_PADRAO))
