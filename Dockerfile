# ====== STAGE 1: Build (instala e compila dependências) ======
FROM python:3.11-bookworm AS builder

# Evita interações e reduz logs do pip
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Só o necessário para compilar deps que precisam de headers (ex.: GDAL)
RUN apt-get update && apt-get install --no-install-recommends -y \
      build-essential \
      git \
      g++ \
      gcc \
      gdal-bin \
      libgdal-dev \
    && rm -rf /var/lib/apt/lists/*

# Ambiente isolado para deps Python
WORKDIR /app
COPY requirements.txt ./

RUN python -m venv /opt/venv \
 && /opt/venv/bin/pip install --upgrade pip wheel setuptools \
 && GDAL_CONFIG=/usr/bin/gdal-config /opt/venv/bin/pip install -r requirements.txt

# ====== STAGE 2: Runtime (mínimo possível) ======
FROM python:3.11-slim-bookworm

# Apenas libs de RUNTIME (sem headers/dev). gdal-bin puxa libgdal em runtime.
RUN apt-get update && apt-get install --no-install-recommends -y \
      gdal-bin \
      libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Variáveis e PATH para o venv
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    STREAMLIT_SERVER_FILE_WATCHER_TYPE=auto \
    GDAL_CONFIG=/usr/bin/gdal-config

# Usuário não-root + diretórios necessários
RUN useradd -ms /bin/bash appuser \
 && mkdir -p /home/appuser/.streamlit /home/appuser/.cache \
 && chown -R appuser:appuser /home/appuser

WORKDIR /app

# Copia o venv pronto do builder (menor imagem, sem toolchain)
COPY --from=builder /opt/venv /opt/venv

# Copia só o código da app
# (Se usar .dockerignore, fica ainda menor)
COPY --chown=appuser:appuser . /app

# Garante que o usuário da app consegue ler/usar o venv
RUN chown -R appuser:appuser /opt/venv

USER appuser

# Porta do Streamlit
EXPOSE 8501

# Sobe o Streamlit com o Login.py
# (bind explícito ao 0.0.0.0 para aceitar tráfego externo)
CMD ["streamlit", "run", "Login.py", "--server.address=0.0.0.0", "--server.port=8501"]
