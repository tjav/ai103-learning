# 02.3 — Build agents: quiz

15 questions. Answers at the bottom. Aim for 12+ before moving on.

---

**1.** Which object holds the conversation history in a Foundry Agent Service
solution?

- A. The agent
- B. The thread
- C. The run
- D. The run step

---

**2.** An application creates agent A and agent B, and a single thread T. It runs A
on T, then runs B on T. What happens?

- A. The second run fails — a thread belongs to the agent that first ran on it
- B. B sees the full history including A's replies, and appends to the same thread
- C. B starts with an empty context; only A can read its own messages
- D. The thread is duplicated

---

**3.** A run has been in status `requires_action` for eleven minutes and then
changes to `expired`. What did the application fail to do?

- A. Call `runs.cancel`
- B. Poll the run status
- C. Execute the requested tool and call `submit_tool_outputs`
- D. Create the assistant message

---

**4.** Which statement about function calling in the Agent Service is correct?

- A. Foundry executes your Python function inside the run
- B. The model returns a tool call; your application executes it and submits the output
- C. Functions run in the Code Interpreter sandbox
- D. Function results are written directly to the thread by the service

---

**5.** A team must log and authorise every tool invocation before it executes.
Which approach supports this?

- A. `runs.create_and_process` with `enable_auto_function_calls`
- B. `runs.create` plus a manual polling loop that inspects `required_action`
- C. Adding "ask permission first" to the agent instructions
- D. Setting `temperature=0`

---

**6.** An existing, documented REST API is reachable from Azure and the team does
not want to write or host wrapper code. Which tool fits best?

- A. Function calling
- B. Code Interpreter
- C. The OpenAPI spec tool
- D. File Search

---

**7.** Which two are true of the OpenAPI spec tool compared with function calling?
Choose two.

- A. Foundry makes the HTTP call itself; your process is not involved
- B. It produces a `requires_action` run status you must handle
- C. Authentication can be held in a project connection or managed identity
- D. It can call non-HTTP internal systems

---

**8.** An enterprise already has an Azure AI Search index with custom chunking,
security-trimming filters, and a semantic configuration, used by three other
applications. Which knowledge tool should the agent use?

- A. File Search with the same documents uploaded
- B. The Azure AI Search tool pointed at the existing index via a project connection
- C. Code Interpreter reading a CSV export
- D. Bing grounding

---

**9.** Which two are genuine drawbacks of File Search compared with the Azure AI
Search tool? Choose two.

- A. You cannot control chunking strategy
- B. It cannot return citations
- C. Content is duplicated into a managed vector store
- D. It requires a hub-based project

---

**10.** In a support conversation on one thread, `prompt_tokens` rises on every turn
even though the user's messages are short. Why?

- A. The agent's instructions grow automatically
- B. Each run replays the instructions, tool schemas, and full thread history
- C. Tokens are double-counted for tool calls
- D. The model caches nothing, so completions are re-billed as prompt

---

**11.** Where do you find which tools a run invoked, with what arguments, and what
each step cost?

- A. `messages.list`
- B. `run_steps.list`
- C. `threads.get`
- D. `agents.get_agent`

---

**12.** You delete an agent that has been used in twenty conversations. What happens
to the threads?

- A. They are deleted with the agent
- B. They persist until deleted individually
- C. They are archived for 30 days then purged
- D. They become read-only but are removed at end of month

---

**13.** Which is the **best** description of a tool's `description` field?

- A. Documentation for developers; the model ignores it
- B. The routing logic the model uses to decide whether and when to call the tool
- C. Text shown to the end user before the tool runs
- D. A fallback used only when the tool name is ambiguous

---

**14.** A workload calls an internal batch process that takes four minutes to
complete. Which integration avoids the run timing out?

- A. Function calling with a longer poll interval
- B. Code Interpreter
- C. The Azure Functions tool, which communicates asynchronously via storage queues
- D. Increasing `max_completion_tokens`

---

**15.** Which is **not** a reasonable conversation-tracking design?

- A. One thread per conversation, deleted after a retention period
- B. One thread per session, summarised into your own database on close
- C. A new thread per turn, with prior context re-injected by your application
- D. One thread shared by all users, filtered per user at read time

---
---

## Answers

**1 — B.** The thread is the persistent conversation and the service replays it on
every run — that is what "conversation memory" means in an agent solution. The agent
is a stateless configuration (model, instructions, tools). The run is one execution;
the run step is one action inside it.

**2 — B.** Threads are independent objects owned by no agent. Any agent can be run
against any thread and sees the whole history. This is precisely the primitive that
handoff orchestration is built on, and the lab demonstrates it.

**3 — C.** `requires_action` means the model emitted a tool call and is waiting for
your application to run it and return the result. If you never call
`submit_tool_outputs`, the run exceeds its window and expires. Cancelling would
produce `cancelled`, not `expired`, and polling alone changes nothing.

**4 — B.** The model never executes code. It emits a name and JSON arguments; your
application is responsible for running the function and submitting the output, at
which point the run resumes. Code Interpreter is a separate, sandboxed tool for code
the *model* writes.

**5 — B.** The manual loop is the only place where you can intercept a tool call
between the model requesting it and it executing.
`create_and_process` with auto function calling deliberately hides that seam.
Instructions (C) are a suggestion the model can ignore and are not a security
control; temperature is irrelevant.

**6 — C.** The OpenAPI tool takes an OpenAPI 3.0 document plus an auth scheme, and
Foundry calls the API directly — no wrapper function, no hosting, no
`requires_action`. Function calling would work but requires you to write and run the
client code, which is what the question rules out.

**7 — A and C.** Foundry performs the HTTP call using anonymous auth, a connection,
or managed identity, so credentials never enter your code and your process is not in
the path. B is exactly backwards — no `requires_action` is raised. D is the argument
*for* function calling, not against it.

**8 — B.** The Azure AI Search tool references an index you already own through a
project connection, preserving your chunking, filters, semantic configuration, and
other consumers. Re-uploading the documents into File Search (A) duplicates the data,
discards the filters and security trimming, and creates a second copy to keep in
sync.

**9 — A and C.** File Search is convenient precisely because Foundry does the
chunking and embedding — which means you cannot tune it, and your content is copied
into a managed vector store that bills for storage. It *does* return citations as
message annotations (B is false) and works fine from a Foundry project (D is false).

**10 — B.** Every run re-reads the thread and re-sends the instructions and tool
schemas. A three-word user turn can still cost hundreds of prompt tokens. Mitigate
with shorter instructions, fewer tools, fresh threads per session, summarisation, or
a run `truncation_strategy`.

**11 — B.** `run_steps.list(thread_id, run_id)` returns each step — `message_creation`
or `tool_calls` — with the tool name, arguments, output, status, and per-step usage.
`messages.list` shows only the conversation, not how it was produced.

**12 — B.** Threads are independent of agents and persist until explicitly deleted.
This matters for cost (they are replayed) and much more for **data retention** — user
content sits in the agent service indefinitely unless your application removes it.

**13 — B.** The model selects tools entirely from names, descriptions, and parameter
descriptions. A vague description means the tool is skipped or called with invented
arguments. Write descriptions that say *when* to call and what a valid input looks
like.

**14 — C.** The Azure Functions tool uses storage queues so the agent is not blocked
waiting on a synchronous HTTP response, which is the pattern for work that exceeds
the run window. A does not help — the run window is the constraint, not your polling
interval. Code Interpreter runs the model's own code, not your batch process.

**15 — D.** A shared thread across users leaks every user's messages into every other
user's context; the service replays the whole thread and there is no per-message
read filter. A, B, and C are all legitimate designs trading cost, retention, and
personalisation differently.

---

## Lab exercise solutions

**1. Starve the run.** The run goes `queued` → `in_progress` → `requires_action`,
then sits there. With default settings it becomes **`expired`** at around the
ten-minute mark. `run.last_error` is typically empty or reports that the run expired
while waiting for tool outputs — the important observation is that the terminal
status is `expired`, **not** `failed`. Two practical consequences: a stuck consumer
silently burns the run window rather than raising an error, and you should set an
explicit deadline in your own polling loop rather than trusting the service to tell
you promptly.

**2. Description-driven routing.** With `Gets stuff.` the tool is called
inconsistently — often not at all, with the model instead asking the user for
information it could have looked up, or answering from the instructions. When it
*is* called, fabricated order IDs appear more often, because nothing in the
description told it not to invent one. Restoring the original description ("Call
this whenever the user supplies an order ID. Never guess an order ID; ask for one
instead.") makes both behaviours reliable. The lesson: tool descriptions are
prompt engineering, not documentation, and negative constraints belong in them.

**3. Enum enforcement.** You will usually receive one of the allowed enum values
(most often `changed_mind` or `damaged`) — the model maps the free-text complaint
onto the closest legal value. But it is **not guaranteed**: agent tool schemas are
used to *guide* generation, and unlike chat completions' `response_format` with
`strict: true`, they are not compiled into a hard decoding constraint. Occasionally
you will see an out-of-enum string or a missing required field. The engineering
conclusion is that you must **validate tool arguments in your function** before
acting on them and return a structured error the model can recover from — never
treat a tool schema as a security or integrity boundary.

**4. Thread growth.** Prompt tokens grow roughly linearly with turn count, with a
large constant offset from the instructions and tool schemas — typically something
like `prompt ≈ 500 + 120 × turn` for this agent. Over ten turns you pay for the
early messages ten times. The summarise-and-restart variant flattens the curve to
near-constant and can cut total tokens by more than half on a long conversation. The
cost is fidelity: the summary loses detail, so the agent forgets specifics such as
an order ID mentioned once at turn 2 unless the summary prompt is explicitly told to
preserve identifiers and decisions. In practice the good design is hybrid — keep the
last N turns verbatim and summarise everything older, which is exactly what a run
`truncation_strategy` approximates.
