# Minimales, plattformunabhängiges Image. Keine Azure-spezifischen Abhängigkeiten,
# damit das Image unverändert auf jeder OCI-kompatiblen Runtime lauffähig bleibt
# (Portierbarkeit).
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Nicht als root laufen
RUN useradd --create-home --uid 10001 appuser
USER appuser

EXPOSE 8000

# 2 Worker reichen für die Testlast; horizontale Skalierung erfolgt über Replicas.
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "--timeout", "120", "app:app"]
