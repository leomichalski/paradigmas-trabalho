import base64
import json
import os
import subprocess
import tempfile
from pathlib import Path

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ValidationError

from app import prolog
from app.rotas_fluxos import router as rotas_fluxos

app = FastAPI(title="Editor de Fluxos")
app.include_router(rotas_fluxos)
MAX_VIDEO_SIZE = 25 * 1024 * 1024
MAX_VIDEO_FRAMES = 8

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
    trigger_input: str | None = None

def _extract_video_frames(video_path: str) -> list[str]:
    """Extrai quadros JPEG do MP4 como entradas multimodais de visão."""
    with tempfile.TemporaryDirectory(prefix="prospectflow-frames-") as out_dir:
        pattern = str(Path(out_dir) / "frame-%02d.jpg")
        result = subprocess.run(
            ["ffmpeg", "-v", "error", "-i", video_path, "-vf", "fps=1/5,scale=768:-1",
             "-frames:v", str(MAX_VIDEO_FRAMES), pattern],
            capture_output=True, text=True, timeout=60, check=False)
        frames = sorted(Path(out_dir).glob("frame-*.jpg"))
        if result.returncode != 0 or not frames:
            raise ValueError("Não foi possível ler quadros do vídeo. Verifique se o MP4 está íntegro.")
        return ["data:image/jpeg;base64," + base64.b64encode(frame.read_bytes()).decode("ascii") for frame in frames]


@app.post("/execute")
async def call_execute_workflow(request: Request):
    temp_path = None
    try:
        video = None
        if "multipart/form-data" in request.headers.get("content-type", ""):
            form = await request.form()
            user_api_key = str(form.get("api_key", ""))
            user_diagram = str(form.get("diagram_text", ""))
            user_trigger = form.get("trigger_input")
            video = form.get("video")
        else:
            payload = ExecuteRequest.model_validate(await request.json())
            user_api_key, user_diagram, user_trigger = payload.api_key, payload.diagram_text, payload.trigger_input

        frames_json = "[]"
        if video is not None and hasattr(video, "read"):
            if video.content_type != "video/mp4" or not (video.filename or "").lower().endswith(".mp4"):
                return {"status": "failed", "message": "Formato de vídeo inválido",
                        "logs": "PROMPT failed: envie um arquivo .mp4 com MIME video/mp4."}
            with tempfile.NamedTemporaryFile(prefix="prospectflow-", suffix=".mp4", delete=False) as tmp:
                temp_path = tmp.name
                size = 0
                while chunk := await video.read(1024 * 1024):
                    size += len(chunk)
                    if size > MAX_VIDEO_SIZE:
                        return {"status": "failed", "message": "Vídeo muito grande",
                                "logs": "PROMPT failed: o vídeo excede o limite de 25 MB."}
                    tmp.write(chunk)
            frames_json = json.dumps(_extract_video_frames(temp_path))

        logs = prolog.execute_workflow(
            api_key=user_api_key,
            diagram_text=user_diagram,
            trigger_input=user_trigger,
            video_frames=frames_json
        )
        failed = "PROMPT failed:" in logs or "generation_failed" in logs

        # FastAPI will automatically serialize this dictionary to JSON
        return {
            "status": "failed" if failed else "success",
            "message": "Workflow execution failed" if failed else "Workflow executed successfully",
            "logs": logs
        }
    except ValidationError as ve:
        raise HTTPException(status_code=422, detail=ve.errors()) from ve
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
    finally:
        if temp_path and os.path.exists(temp_path):
            os.unlink(temp_path)
