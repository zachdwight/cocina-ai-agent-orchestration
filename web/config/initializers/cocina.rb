# Eagerly load Cocina domain classes so they are available
# in controllers, jobs, and channels without manual requires.
require Rails.root.join("lib/cocina/agent")
require Rails.root.join("lib/cocina/orchestrator")
require Rails.root.join("lib/cocina/agent_adapter")
