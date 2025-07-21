import os
import time

print(f"Agent Sous Chef (ID: {os.environ.get('AGENT_ID')}) starting...")
print(f"API Key for Sous Chef: {os.environ.get('API_KEY')}")

# Simulate agent work
for i in range(5):
    print(f"Sous Chef organizing orders... {i+1}/5")
    time.sleep(30)
    #this is where your agent could call other sources / RAG style

for i in range():
    print(f"Sous Chef cooking fish... {i+1}/5")
    time.sleep(30)

print("Sous Chef finished plating.")
