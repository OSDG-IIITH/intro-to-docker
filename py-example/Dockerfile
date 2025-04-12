FROM python:3.13-alpine

WORKDIR /app

COPY requirements.txt .

RUN pip install -r requirements.txt

COPY . .

ENV RELOAD=0

EXPOSE 5000

ENTRYPOINT [ "python3", "main.py" ]
