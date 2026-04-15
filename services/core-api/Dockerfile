FROM python:3.12-slim AS whisper-builder

ARG WHISPER_CPP_VERSION=v1.8.1
ARG WHISPER_CPP_MODEL=base.en

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        cmake \
        curl \
        git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt

RUN git clone --branch "${WHISPER_CPP_VERSION}" --depth 1 https://github.com/ggml-org/whisper.cpp.git

WORKDIR /opt/whisper.cpp

RUN cmake -B build \
    && cmake --build build -j --config Release \
    && ./models/download-ggml-model.sh "${WHISPER_CPP_MODEL}"

FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_LINK_MODE=copy

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        libgomp1 \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir uv

COPY --from=whisper-builder /opt/whisper.cpp/build /opt/whisper.cpp/build
COPY --from=whisper-builder /opt/whisper.cpp/models /opt/whisper.cpp/models

COPY services/voice /app/services/voice
COPY services/core-api /app/services/core-api

WORKDIR /app/services/core-api

RUN uv sync --no-dev

EXPOSE 8000

CMD ["uv", "run", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
