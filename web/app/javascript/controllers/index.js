import { application } from "controllers/application"

import AgentLogsController from "controllers/agent_logs_controller"
application.register("agent-logs", AgentLogsController)
