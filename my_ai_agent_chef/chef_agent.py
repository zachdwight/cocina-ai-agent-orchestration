import os
import time

print(f"Agent Head Chef (ID: {os.environ.get('AGENT_ID')}) starting...")
print(f"API Key for Head Chef: {os.environ.get('API_KEY')}")

# Simulate agent work
for i in range(5):
    print(f"Head Chef getting ingredients... {i+1}/5")
    time.sleep(30)
    #this is where your agent could call other sources / RAG style

for i in range():
    print(f"Head Chef cooking... {i+1}/5")
    time.sleep(30)

print("Head Chef finished plating.")
