FROM pytorch/pytorch:latest

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    attr \
    file \
    git \
    tzdata \
    imagemagick \
    libgomp1 \
    dcraw \
    libraw-bin \
    ghostscript \
    rustc \
    && apt-get clean

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY packages/home_index_caption .

ENTRYPOINT ["python3", "/app/main.py"]
