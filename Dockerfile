# =============================================
# STAGE 1: Builder
# Instala dependencias en un entorno aislado
# =============================================
FROM python:3.11-slim AS builder

WORKDIR /app

# Instalar solo las dependencias necesarias para compilar
COPY requirements.txt .
RUN pip install --upgrade pip \
    && pip install --no-cache-dir --prefix=/install -r requirements.txt

# =============================================
# STAGE 2: Production
# Imagen final liviana, sin herramientas de build
# =============================================
FROM python:3.11-slim AS production

# Crear usuario no root por seguridad (mínimo privilegio)
RUN groupadd -r appgroup && useradd -r -g appgroup -d /app -s /sbin/nologin appuser

WORKDIR /app

# Copiar dependencias instaladas desde builder
COPY --from=builder /install /usr/local

# Copiar código fuente de la aplicación
COPY --chown=appuser:appgroup . .

# Eliminar archivos innecesarios para reducir superficie de ataque
RUN rm -f .env.example .env && \
    find . -name "*.pyc" -delete && \
    find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

# Cambiar al usuario no root
USER appuser

# Puerto que expone el frontend Flask
EXPOSE 5000

# Variables de entorno por defecto (sobreescribibles en runtime)
ENV PORT=5000 \
    DEBUG=False \
    BACKEND_URL=http://backend:3000 \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Health check para verificar que el contenedor está saludable
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000')" || exit 1

# Comando de inicio en producción
CMD ["python", "app.py"]