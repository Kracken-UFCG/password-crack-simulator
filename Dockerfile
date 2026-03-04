FROM nvidia/cuda:12.8.0-devel-ubuntu24.04

RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Makefile config.env ./
COPY src/ ./src/
COPY utils/ ./utils/

RUN mkdir -p data

RUN make all

EXPOSE 8082

CMD ["python3", "src/backend/server.py"]