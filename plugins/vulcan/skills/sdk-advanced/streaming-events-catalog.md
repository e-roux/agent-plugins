# Streaming Events Catalog

When `streaming: true`, the SDK emits 40+ event types. Every event shares a common envelope:

| Field       | Type     | Description                      |
|-------------|----------|----------------------------------|
| `id`        | UUID     | Unique event identifier          |
| `timestamp` | ISO 8601 | When the event was created       |
| `parentId`  | string?  | Previous event in the chain      |
| `ephemeral` | boolean? | `true` for transient events      |
| `type`      | string   | Event type discriminator         |
| `data`      | object   | Event-specific payload           |

## Assistant Events

| Event                       | Ephemeral | Description                               |
|-----------------------------|-----------|-------------------------------------------|
| `assistant.turn_start`      |           | Agent begins processing a turn            |
| `assistant.intent`          | yes       | What the agent is currently doing         |
| `assistant.reasoning`       |           | Complete extended thinking block          |
| `assistant.reasoning_delta` | yes       | Incremental thinking chunk                |
| `assistant.message`         |           | Complete response (may include tool requests) |
| `assistant.message_delta`   | yes       | Incremental response chunk                |
| `assistant.turn_end`        |           | Turn finished                             |
| `assistant.usage`           | yes       | Token usage and cost info                 |
| `assistant.streaming_delta` | yes       | Network-level bytes received              |

## Tool Events

| Event                            | Ephemeral | Description                    |
|----------------------------------|-----------|--------------------------------|
| `tool.user_requested`           |           | User explicitly requested tool |
| `tool.execution_start`          |           | Tool begins executing          |
| `tool.execution_partial_result` | yes       | Incremental tool output        |
| `tool.execution_progress`       | yes       | Progress status message        |
| `tool.execution_complete`       |           | Tool finished (success/error)  |

## Session Events

| Event                        | Ephemeral | Description                        |
|------------------------------|-----------|-------------------------------------|
| `session.idle`               | yes       | Ready for next message              |
| `session.error`              |           | Error during processing             |
| `session.title_changed`      | yes       | Auto-generated title updated        |
| `session.context_changed`    |           | Working directory/repo changed      |
| `session.usage_info`         | yes       | Context window utilization          |
| `session.task_complete`      |           | Agent completed its task            |
| `session.shutdown`           |           | Session ended (metrics included)    |
| `session.compaction_start`   |           | Context compaction began            |
| `session.compaction_complete`|           | Context compaction finished         |

## System Events (v0.2.0+)

| Event                        | Ephemeral | Description                        |
|------------------------------|-----------|-------------------------------------|
| `system.notification`        |           | System notification from the runtime |
| `session.log`                | yes       | Log message via `session.log()`    |

## Permission & User Input Events

| Event                    | Ephemeral | Description                      |
|--------------------------|-----------|----------------------------------|
| `permission.requested`   | yes       | Agent needs approval             |
| `permission.completed`   | yes       | Permission resolved              |
| `user_input.requested`   | yes       | Agent asking user a question     |
| `user_input.completed`   | yes       | User input resolved              |
| `elicitation.requested`  | yes       | Structured form input needed     |
| `elicitation.completed`  | yes       | Elicitation resolved             |

## Sub-Agent & Skill Events

| Event                  | Ephemeral | Description                 |
|------------------------|-----------|-----------------------------|
| `subagent.started`     |           | Sub-agent began             |
| `subagent.completed`   |           | Sub-agent finished          |
| `subagent.failed`      |           | Sub-agent errored           |
| `subagent.selected`    |           | Agent auto-selected         |
| `subagent.deselected`  |           | Returned to parent          |
| `skill.invoked`        |           | Skill activated             |

## Other Events

| Event                        | Ephemeral | Description                        |
|------------------------------|-----------|-------------------------------------|
| `abort`                      |           | Turn was aborted                    |
| `user.message`               |           | User sent a message                 |
| `system.message`             |           | System prompt injected              |
| `external_tool.requested`    | yes       | External tool invocation needed     |
| `external_tool.completed`    | yes       | External tool resolved              |
| `command.queued`             | yes       | Slash command queued                |
| `command.completed`          | yes       | Slash command resolved              |
| `exit_plan_mode.requested`   | yes       | Agent wants to exit plan mode       |
| `exit_plan_mode.completed`   | yes       | Plan mode exit resolved             |

## Typical Turn Flow

```
assistant.turn_start
├── assistant.intent (ephemeral)
├── assistant.reasoning_delta (ephemeral, repeated)
├── assistant.reasoning
├── assistant.message_delta (ephemeral, repeated)
├── assistant.message (may include toolRequests)
├── assistant.usage (ephemeral)
├── permission.requested → permission.completed (ephemeral)
├── tool.execution_start
├── tool.execution_partial_result (ephemeral, repeated)
├── tool.execution_complete
├── [agent loops: more reasoning → message → tool calls...]
assistant.turn_end
session.idle (ephemeral)
```
