import os
import sys
import anthropic

AGENT_ID = os.environ.get("AGENT_ID", "sous_unknown")
TASK     = os.environ.get("TASK", "Write a detailed recipe for a classic French dish.")

print(f"[Sous Chef Agent | ID: {AGENT_ID}] Starting...")
print(f"[Sous Chef Agent | ID: {AGENT_ID}] Task: {TASK}")
print()

api_key = os.environ.get("ANTHROPIC_API_KEY", "")
if not api_key:
    print("Error: ANTHROPIC_API_KEY environment variable is not set.", file=sys.stderr)
    sys.exit(1)

client = anthropic.Anthropic(api_key=api_key)

print("[Sous Chef Agent] Calling Claude API...")

message = client.messages.create(
    model="claude-haiku-4-5-20251001",
    max_tokens=1024,
    system=(
        "You are the Sous Chef AI agent. Your role is to execute specific culinary sub-tasks "
        "with precision and detail. When given a task, respond with thorough, step-by-step "
        "instructions including ingredients, quantities, timing, and technique. Be practical "
        "and exact."
    ),
    messages=[
        {"role": "user", "content": TASK}
    ]
)

result = message.content[0].text
print(f"[Sous Chef Agent | ID: {AGENT_ID}] Result:\n")
print(result)
print()
print(f"[Sous Chef Agent | ID: {AGENT_ID}] Done. (Input tokens: {message.usage.input_tokens}, Output tokens: {message.usage.output_tokens})")
