FROM python:3.12-slim AS test

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .
COPY test_app.py .

# Run automated tests while building the test image
RUN pytest


FROM python:3.12-slim AS production

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

# Run as a non-root user for security
RUN useradd --create-home --uid 1000 appuser
USER appuser

EXPOSE 5000

CMD ["python", "app.py"]
