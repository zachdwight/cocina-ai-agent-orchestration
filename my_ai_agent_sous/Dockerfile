FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY sous_agent.py .
CMD ["python", "sous_agent.py"]