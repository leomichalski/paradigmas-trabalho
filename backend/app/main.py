import os
from typing import Annotated, Literal

import fastapi
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from app import prolog

app = FastAPI(title="Editor de Fluxos")

# In development mode, allow cross-origin requests from the frontend
ENVIRONMENT = os.environ.get("ENVIRONMENT", "production").lower()
if ENVIRONMENT in ("dev", "development", "debug"):
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

class ExecuteRequest(BaseModel):
    api_key: str
    diagram_text: str

@app.post("/execute")
def call_execute_workflow(request: ExecuteRequest):
    try:
        user_api_key = request.api_key
        user_diagram = request.diagram_text

        logs = prolog.execute_workflow(
            api_key=user_api_key,
            diagram_text=user_diagram
        )

        # FastAPI will automatically serialize this dictionary to JSON
        return {
            "status": "success",
            "message": "Workflow executed successfully",
            "logs": logs
        }
    except ValueError as ve:
        # Catch specific known errors (e.g., bad inputs) and return a 400 Bad Request
        print(f"Validation error during workflow execution: {ve}")
        raise HTTPException(status_code=400, detail=str(ve))
    except ConnectionError as ce:
        print(f"Connection error: {ce}")
        raise HTTPException(status_code=502, detail="Failed to connect to the workflow engine.")
    except Exception as e:
        print(f"Unexpected error executing workflow: {e}")
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred: {str(e)}")


class AnalyzeRequest(BaseModel):
    diagram_text: str


@app.post("/analyze")
def call_analyze_graph(request: AnalyzeRequest):
    try:
        return prolog.analyze_graph(diagram_text=request.diagram_text)
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred: {str(e)}")