FROM python:3.9-slim-buster
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY sous_agent.py .
CMD ["python", "sous_agent.py"]