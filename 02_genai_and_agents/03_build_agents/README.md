# 02.3 — Build agents by using Foundry

**Time:** 90–120 minutes · **Cost:** tokens, plus **Code Interpreter session
charges** (a session stays warm for up to an hour with a 30-minute idle timeout) and
File Search vector-storage charges. Agents themselves are free to exist; runs cost
tokens. The lab deletes every agent, thread, file, and vector store it creates.

By the end you will have:

- [ ] Explained the agent / thread / message / run / run-step object model without looking
- [ ] Created an agent with instructions, a model, and tools
- [ ] Handled a `requires_action` run and submitted tool outputs by hand
- [ ] Used automatic function calling and understood what it hides from you
- [ ] Attached Code Interpreter, File Search, and Azure AI Search tools
- [ ] Described the OpenAPI spec tool and Bing grounding, and when each is the right answer
- [ ] Inspected run steps to see exactly what the agent did and what it cost
- [ ] Deleted everything

---

## Concepts

### The object model — learn this cold

The exam tests these five nouns and their lifecycle more than anything else in the
agent domain.

```
Agent            a persistent configuration: model + instructions + tools + tool_resources
  │              lives on the project until you delete it. Stateless by itself.
  │
Thread           a persistent conversation. Holds messages. Belongs to no agent.
  │              The SAME thread can be run by DIFFERENT agents.
  │
  ├── Message    one turn. role = user | assistant. May carry attachments and
  │              annotations (citations). Immutable once created.
  │
  └── Run        one execution of ONE agent against ONE thread.
        │        Has a status. Costs tokens. Produces new messages.
        │
        └── Run step   what the run actually did: message_creation or tool_calls.
                       This is your audit trail and your token breakdown.
```

Four consequences that get tested:

1. **Threads are not owned by agents.** You can hand the same thread to a different
   agent — that is the primitive underneath handoff orchestration in unit 02.4.
2. **The agent is stateless; the thread is the memory.** "Conversation memory" in an
   agent solution means *the thread*. You do not resend history — the service
   replays it for you. That is the single biggest difference from chat completions.
3. **Threads grow without limit and you pay for the replay.** Every run re-reads the
   thread, so prompt tokens climb turn over turn. Long-lived threads need
   truncation, summarisation, or a fresh thread per session.
4. **Run steps are the only honest record** of which tools fired, with what
   arguments, and how many tokens each step cost.

### Run status — the state machine

| Status | Meaning | What you do |
|---|---|---|
| `queued` | accepted, not started | wait |
| `in_progress` | executing | wait |
| **`requires_action`** | the model wants a tool your code must run | execute it, then `submit_tool_outputs` |
| `completed` | finished | read the new assistant message |
| `failed` | error | read `run.last_error` |
| `cancelling` / `cancelled` | you cancelled it | — |
| `expired` | exceeded the run window (~10 min default) or you never submitted outputs | restart |

`requires_action` is the heart of function calling. The model **never executes your
code**. It emits a tool call with a name and JSON arguments; your application runs
the function and submits the result; the run resumes.

> **Exam note.** "The agent called the function but nothing happened" → the run is
> sitting in `requires_action` and the application never called
> `submit_tool_outputs`. It will `expire`. This is the most commonly described
> failure in agent questions.

### Tool categories

| Tool | Executed by | Needs | Use for |
|---|---|---|---|
| **Function calling** (`FunctionTool`) | **Your code** | a JSON schema per function | Anything private: your database, your billing system, an internal service |
| **Code Interpreter** (`CodeInterpreterTool`) | Foundry sandbox | optional file IDs | Maths, data analysis, chart generation, file transformation |
| **File Search** (`FileSearchTool`) | Foundry | a vector store | Ad-hoc document Q&A where you do not want to run Search yourself |
| **Azure AI Search** (`AzureAISearchTool`) | Foundry | a project **connection** + index name | Enterprise RAG over an index you already own and control |
| **OpenAPI spec** (`OpenApiTool`) | Foundry | an OpenAPI 3.0 document + auth scheme | Calling an existing REST API without writing a wrapper function |
| **Bing grounding** (`BingGroundingTool`) | Foundry | a Grounding with Bing **connection** (billed separately) | Public, current web information |
| **Azure Functions** | Azure, async via queues | storage queues | Long-running work that would blow the run window |
| **MCP** (`McpTool`) | remote MCP server | a server URL; supports **tool approval** | Standardised external toolsets |
| **Connected agents** (`ConnectedAgentTool`) | another agent | a sibling agent's ID | Delegation — unit 02.4 |

The exam's favourite distinction:

> **Function calling vs OpenAPI tool.** Both reach external systems. With
> `FunctionTool`, execution happens **in your process** — you get the
> `requires_action` callback and full control, and it works with anything, including
> code that never leaves your network. With `OpenApiTool`, **Foundry calls the API
> directly** using a connection or managed identity; there is no `requires_action`
> and your process is not involved. Choose OpenAPI when a documented HTTP API
> already exists and Foundry can reach it; choose functions when the work is local,
> private, or not HTTP.

A second favourite:

> **File Search vs Azure AI Search.** File Search means Foundry chunks, embeds, and
> stores your files in a managed **vector store** — quick, but you do not control
> chunking, cannot use hybrid or semantic ranking, and the data is duplicated into
> the agent service. `AzureAISearchTool` points at an index **you** built, with your
> chunking, your filters, your hybrid + semantic configuration, and your other
> consumers. Enterprise scenarios with an existing index always want the latter.

### Designing an agent: roles, goals, tool schemas

The study guide asks you to "define agent roles, goals, conversation-tracking
approach, and tool schemas." Concretely:

**Role and goal** live in `instructions`. Good instructions state:

1. Who the agent is and what it is for (one sentence).
2. What it must never do — refunds it cannot authorise, advice it cannot give.
3. The tool policy: *when* to use each tool, and what to do when a tool fails.
4. The output contract: format, citation requirements, escalation phrasing.
5. The refusal path: what to say when it cannot help.

Instructions are prepended to every run, so they are billed on every turn. Keep them
tight, and put stable long content in a knowledge tool rather than the prompt.

**Tool schemas** are JSON Schema, and the model chooses tools *entirely from the
names, descriptions, and parameter descriptions*. The description is not
documentation; it is the routing logic. Two rules:

- Describe **when** to call it, not just what it does:
  *"Look up the current shipment status for an order. Use only when the user gives
  an order ID; do not guess IDs."*
- Constrain aggressively with `enum`, `required`, and types. Every constraint is one
  fewer malformed call you have to handle at runtime.

**Conversation tracking** is a design decision with four options:

| Approach | Where state lives | Good for |
|---|---|---|
| One thread per conversation | Foundry | The default. Simple, durable, replayable. |
| One thread per session, summarised on close | Foundry + your DB | Long-running support relationships |
| New thread per turn, context re-injected | your app | Strict data-retention rules; full control of what persists |
| Thread + external profile store | Foundry + your DB | Personalisation across conversations ("memory" beyond one thread) |

Threads persist until deleted, which is a **data-retention** consideration as much
as a cost one: user content sits in the agent service until you remove it.

### `create_and_process` vs `create` + poll

`runs.create_and_process(...)` creates the run, polls it, and — if you registered
your functions with `enable_auto_function_calls` — executes tool calls and submits
outputs automatically. It is convenient and it hides the `requires_action` state
entirely.

`runs.create(...)` followed by your own polling loop is what you use when you need
to log, authorise, rate-limit, or ask a human before a tool executes. Unit 02.4
builds an approval gate on exactly that seam.

> **Exam note.** If a question mentions "require approval before the tool runs" or
> "audit every tool invocation," the answer involves the manual loop (or the MCP
> tool's built-in approval), never `create_and_process`.

---

## Portal walkthrough

### Step 1 — Build an agent in the portal

**https://ai.azure.com** → your project → **Agents** (under *Build and customize*)
→ **+ New agent**.

| Field | Value | Notes |
|---|---|---|
| Agent name | `contoso-support` | display only |
| Deployment | `gpt-4o-mini` | the deployment, not the model |
| Instructions | see below | prepended to every run |
| Knowledge | *(add later)* | File Search, Azure AI Search, Bing, SharePoint, Fabric |
| Actions | *(add later)* | Functions, OpenAPI, Azure Functions, MCP |
| Temperature / Top P | leave default | per-agent defaults; overridable per run |

Instructions to paste:

```
You are Contoso's support triage assistant.

- Answer only from the knowledge tools provided. If nothing is found, say so
  and offer to escalate.
- Use get_order_status whenever the user supplies an order ID. Never invent an
  order ID or a status.
- You may state policy. You may never promise a refund, a credit, or a date.
  Refunds require a human agent.
- Cite the policy section for every policy claim.
- If the user is abusive or asks for anything outside Contoso support, decline
  in one sentence.
```

Every line does a job: role, grounding rule, tool policy, authority limit,
attribution requirement, refusal path.

### Step 2 — Add knowledge

**Knowledge** → **+ Add**:

| Source | What it creates | When it is right |
|---|---|---|
| **Files** | a managed vector store, chunked and embedded by Foundry | Ad-hoc PDFs; no existing index |
| **Azure AI Search** | a reference to a project **connection** + index | You already own an index — the enterprise answer |
| **Grounding with Bing Search** | a Bing connection (billed separately) | Public, current information |
| **Microsoft Fabric / SharePoint** | data-agent connections | Governed enterprise data |

Choose **Azure AI Search**, select the connection, pick the index from unit 02.2 if
you kept it, and set the query type to **hybrid + semantic**.

### Step 3 — Add an action

**Actions** → **+ Add** → **Custom function**, and paste a JSON schema:

```json
{
  "name": "get_order_status",
  "description": "Look up the current status and delivery estimate for an order. Use only when the user provides an order ID.",
  "parameters": {
    "type": "object",
    "properties": {
      "order_id": { "type": "string", "description": "Order ID, format ORD-12345" }
    },
    "required": ["order_id"]
  }
}
```

Now try it in the portal playground. The agent will emit the tool call and then
**stall** — the portal has no way to execute your function. That stall is
`requires_action`, and it is the single most important thing to see with your own
eyes: the model asks, your code answers.

### Step 4 — Read the run in the portal

After a playground run, open **Threads** (or the run detail from the agent page).
You get the thread's messages, the run status, the tool calls with their arguments,
and per-run token usage. That view is the portal rendering of `run_steps.list()`,
which the lab reads in code.

<details>
<summary>The whole thing in Python</summary>

```python
from azure.ai.agents.models import FunctionTool, ToolSet

agents = project_client().agents

toolset = ToolSet()
toolset.add(FunctionTool({get_order_status}))
agents.enable_auto_function_calls(toolset)

agent = agents.create_agent(
    model=cfg["MODEL_MINI"],
    name="contoso-support",
    instructions=INSTRUCTIONS,
    toolset=toolset,
)
thread = agents.threads.create()
agents.messages.create(thread_id=thread.id, role="user", content="Where is ORD-12345?")
run = agents.runs.create_and_process(thread_id=thread.id, agent_id=agent.id)
```
</details>

---

## Troubleshooting

**Run sits in `requires_action` then goes to `expired`**
You never submitted tool outputs. Either poll and call
`runs.submit_tool_outputs(thread_id, run_id, tool_outputs=[...])`, or register the
functions with `enable_auto_function_calls` and use `create_and_process`.

**`Tool output submission failed: tool_call_id not found`**
Every `tool_call.id` in `run.required_action.submit_tool_outputs.tool_calls` must be
answered in a single `submit_tool_outputs` call. Partial submissions are rejected.

**The agent ignores a tool that would obviously help**
The `description` is doing no work. Say *when* to call it and what a good input looks
like. Also confirm the tool is in `tools`/`toolset` on the **agent** — adding a
function to your Python code does nothing on its own.

**`AzureAISearchTool` returns nothing**
Three usual causes: the project has no **connection** to the Search service; the
Foundry resource's managed identity lacks *Search Index Data Reader*; or the index
lacks the field shape the tool expects. Give the index a text content field and a
title field, and name them in the tool configuration.

**`Rate limit is exceeded` mid-run**
An agent run may make many model calls (planning, each tool result, synthesis).
Agent workloads consume far more TPM than a single chat call. Raise the deployment's
TPM or reduce tool count.

**Code Interpreter charges appear after the lab**
Sessions stay warm for up to an hour with a 30-minute idle timeout, and concurrent
conversations create separate sessions. Deleting the agent stops new sessions.

**`404` deleting a thread you just used**
Threads are deleted with `agents.threads.delete(thread_id)`. Deleting the **agent**
does not delete its threads — threads are independent objects, and forgetting this
leaves user content behind indefinitely.

---

## Check yourself

[quiz.md](quiz.md) — 15 questions on the object model, run states, tool selection,
and tool schema design.

## Next

[02.4 — Multi-agent orchestration, safeguards, and monitoring](../04_multi_agent_and_approvals/README.md)
