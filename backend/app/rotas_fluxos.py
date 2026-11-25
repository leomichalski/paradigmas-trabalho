"""Rotas HTTP do armazenamento de fluxos (parte #2).

    GET    /fluxos              lista os nomes      {"fluxos": [...]}
    GET    /fluxos?tipo=post    só os que usam POST {"fluxos": [...]}
    POST   /fluxos              salva               {"nome", "diagram_text", "trigger_input"}
    GET    /fluxos/{nome}       abre                {"nome", "diagram_text", "trigger_input"}
    DELETE /fluxos/{nome}       apaga
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app import armazenamento

router = APIRouter(prefix="/fluxos", tags=["fluxos"])


class Fluxo(BaseModel):
    nome: str
    diagram_text: str
    trigger_input: str = ""


@router.get("")
def listar_fluxos(tipo: str | None = None):
    return {"fluxos": armazenamento.listar(tipo)}


@router.post("")
def salvar_fluxo(fluxo: Fluxo):
    if not armazenamento.salvar(fluxo.nome, fluxo.diagram_text, fluxo.trigger_input):
        raise HTTPException(
            status_code=400,
            detail="O nome não pode ser vazio e o diagrama precisa ter pelo menos um nó.",
        )
    return {"nome": fluxo.nome.strip()}


# {nome:path} aceita nomes com "/" (o Elm manda %2F)
@router.get("/{nome:path}")
def abrir_fluxo(nome: str):
    salvo = armazenamento.carregar(nome)
    if salvo is None:
        raise HTTPException(status_code=404, detail=f"Fluxo não encontrado: {nome}")
    texto, gatilho = salvo
    return {"nome": nome, "diagram_text": texto, "trigger_input": gatilho}


@router.delete("/{nome:path}")
def apagar_fluxo(nome: str):
    if armazenamento.carregar(nome) is None:
        raise HTTPException(status_code=404, detail=f"Fluxo não encontrado: {nome}")
    armazenamento.remover(nome)
    return {"nome": nome}
