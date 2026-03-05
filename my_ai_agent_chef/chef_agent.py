import os
import sys
import anthropic

AGENT_ID = os.environ.get("AGENT_ID", "chef_unknown")
TASK     = os.environ.get("TASK", "Plan a simple 3-course dinner menu.")

print(f"[Head Chef Agent | ID: {AGENT_ID}] Starting...")
print(f"[Head Chef Agent | ID: {AGENT_ID}] Task: {TASK}")
print()

api_key = os.environ.get("ANTHROPIC_API_KEY", "")
if not api_key:
    print("Error: ANTHROPIC_API_KEY environment variable is not set.", file=sys.stderr)
    sys.exit(1)

client = anthropic.Anthropic(api_key=api_key)

print("[Head Chef Agent] Calling Claude API...")

message = client.messages.create(
    model="claude-haiku-4-5-20251001",
    max_tokens=1024,
    system=(
        "You are the Head Chef AI agent. Your role is to plan, coordinate, and oversee "
        "multi-step culinary tasks. Respond with a clear, structured plan broken into "
        "numbered steps. Be concise and actionable."
    ),
    messages=[
        {"role": "user", "content": TASK}
    ]
)

result = message.content[0].text
print(f"[Head Chef Agent | ID: {AGENT_ID}] Result:\n")
print(result)
print()
print(f"[Head Chef Agent | ID: {AGENT_ID}] Done. (Input tokens: {message.usage.input_tokens}, Output tokens: {message.usage.output_tokens})")
