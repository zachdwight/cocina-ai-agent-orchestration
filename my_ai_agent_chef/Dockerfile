FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY chef_agent.py .
CMD ["python", "chef_agent.py"]