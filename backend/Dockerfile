FROM python:3.11-slim

RUN apt-get update && apt-get install -y swi-prolog ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN pip install uv

COPY pyproject.toml uv.lock ./
COPY app ./app
COPY prolog ./prolog

RUN uv sync --no-dev

EXPOSE 8000

CMD ["uv", "run", "fastapi", "run", "app/main.py", "--host", "0.0.0.0", "--port", "8000"]
