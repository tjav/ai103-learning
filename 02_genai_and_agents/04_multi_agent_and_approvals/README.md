# 02.4 — Multi-agent orchestration, safeguards, and monitoring

**Time:** 90–120 minutes · **Cost:** tokens only, but **multi-agent runs cost
several times a single-agent run** — a main agent plus three connected agents means
the orchestrator's tokens plus every sub-agent's tokens. The lab deletes every agent
and thread it creates.

By the end you will have:

- [ ] Built a connected-agent (agent-as-tool) solution and traced the delegation
- [ ] Implemented sequential, concurrent, and handoff orchestration by hand
- [ ] Described group chat and magentic orchestration and when each applies
- [ ] Built a human-in-the-loop approval gate that blocks a tool *before* it executes
- [ ] Classified a workflow as autonomous, semiautonomous, or supervised, and picked safeguards to match
- [ ] Run agent evaluators — intent resolution, tool call accuracy, task adherence
- [ ] Performed error analysis on a failing run using run steps

---

## Concepts

### Why more than one agent

One agent with fifteen tools degrades: the tool schemas dominate the prompt, tool
selection gets noisy, and one bad instruction line affects everything. Splitting into
specialists gives you narrower prompts, independent evaluation, independent
permissions, and a traceable delegation record.

The cost is real. Every delegation is another model call, and the orchestrator pays
tokens to read every sub-agent's answer. **Do not reach for multi-agent until a
single agent is measurably failing.**

### Connected agents — agent as a tool

`ConnectedAgentTool` wraps an existing agent's ID so a "main" agent can call it like
any other tool. The main agent routes in natural language; there is no orchestration
code.

```python
from azure.ai.agents.models import ConnectedAgentTool

sub = agents.create_agent(model=..., name="policy_bot", instructions="...")
tool = ConnectedAgentTool(id=sub.id, name=sub.name,
                          description="Answers questions about returns and warranty policy")
main = agents.create_agent(model=..., name="orchestrator",
                           instructions="Delegate to the right specialist.",
                           tools=tool.definitions)
```

Limitations you are expected to know:

| Limitation | Consequence |
|---|---|
| **Maximum depth 2** | A parent may have many children; children may not have children. Exceeding it raises a tool-call-depth error. |
| **Connected agents cannot use local function calling** | Sub-agents cannot raise `requires_action` to your process. Use the OpenAPI tool or the Azure Functions tool instead. |
| **Citations are not guaranteed to propagate** | The main agent may summarise away a sub-agent's citations. |
| **`name` must be a valid tool name** | No spaces; it becomes the function name the model calls. |

> **Exam note.** "Connected agent needs to call an internal Python function" is a
> trap — it cannot. The answer is to expose that logic as an HTTP API and use the
> OpenAPI tool, or as an Azure Function.

### Orchestration patterns

The exam names five. Only *connected agents* is a first-class Foundry primitive; the
others are patterns you implement in code, or that the Microsoft Agent Framework
provides as built-in orchestrations.

| Pattern | Shape | Control flow | Use when |
|---|---|---|---|
| **Sequential** | A → B → C | Deterministic pipeline; each output feeds the next | Stages with a fixed order: extract → validate → summarise |
| **Concurrent** (fan-out/fan-in) | A, B, C in parallel → merge | Deterministic, then aggregate | Independent perspectives on the same input: risk, legal, cost |
| **Handoff** | A decides to pass to B, who owns the conversation | Dynamic; one active agent at a time | Triage → specialist, where the specialist keeps talking to the user |
| **Group chat** | Several agents share a transcript, a manager picks who speaks | Dynamic; a manager/selection function chooses each turn | Debate, review boards, iterative critique |
| **Magentic** | A manager builds and maintains a *task ledger*, plans, delegates, replans on failure | Dynamic and open-ended | Complex tasks where the plan is not known up front |
| **Connected agents** | Main agent calls sub-agents as tools | Dynamic, model-routed, depth 2 | The Foundry-native default |

Two contrasts to hold onto:

- **Handoff vs connected agents.** In handoff, control *transfers* — B now owns the
  conversation and replies directly. With connected agents, control *returns* — the
  sub-agent answers the main agent, and the main agent replies to the user. Handoff
  suits "escalate to a human-like specialist"; connected agents suit "go and find
  this out for me."
- **Group chat vs magentic.** Group chat has a fixed roster and a selection policy.
  Magentic maintains an explicit plan (the task ledger), tracks progress, detects
  stalls, and replans. Magentic is for open-ended problems; group chat is for
  structured multi-perspective work.

> **Exam note.** The word "deterministic" points at sequential or concurrent. "The
> system decides which specialist should respond" points at handoff or group chat.
> "The plan is not known in advance and must adapt" points at magentic.

### Autonomy levels and safeguards

The study guide says "autonomous or semiautonomous workflows with safeguards and
approval flow controls." Three levels, each with a matching control set:

| Level | Human involvement | Appropriate safeguards |
|---|---|---|
| **Autonomous** | none in the loop; humans review after the fact | Read-only or reversible tools, hard spend and iteration caps, content filters, full tracing, alerting, kill switch |
| **Semiautonomous** | approval required for a defined subset of actions | Approval gate on side-effecting tools, allow-listed parameters, value thresholds, timeout-to-deny |
| **Supervised** | every action confirmed | Preview of the exact call before execution, one-click reject, full audit |

The load-bearing distinction: a safeguard is only real if the agent **cannot route
around it**. Instructions ("never issue a refund over $200") are a *suggestion* —
the model may violate them under prompt injection or simple confusion. The control
must live in your code, between the tool call being requested and the tool
executing. That seam is `requires_action`.

Practical controls worth naming:

| Control | Where it lives | Beats |
|---|---|---|
| Approval gate on the manual run loop | your code | Unauthorised side effects |
| Parameter validation against an allow-list | your function | Bad or injected arguments |
| Value thresholds (refund ≤ $200 auto, above → human) | your code | Blast radius |
| Idempotency keys | your function | Duplicate execution on retry |
| Per-run tool-call cap | your loop | Runaway loops |
| Least-privilege identity per agent | Entra ID / RBAC | Lateral movement |
| Content filters + prompt shields | Foundry | Jailbreak and indirect injection |
| MCP tool approval (`require_approval`) | Foundry | Third-party tool execution |

The **MCP tool** has an approval flow built in: with `require_approval` set, the run
enters `requires_action` with a `SubmitToolApprovalAction`, and you respond with
approve/deny rather than with a tool output. That is the platform's own expression of
the pattern the lab builds by hand.

### Monitoring and evaluating agents

Three distinct things people conflate:

| Activity | Question | Mechanism |
|---|---|---|
| **Tracing** | What happened in this run? | OpenTelemetry → Application Insights; run steps |
| **Evaluation** | Was the behaviour good? | `azure-ai-evaluation` agent evaluators |
| **Error analysis** | Why did this class of run fail? | Aggregate run steps + evaluator scores, grouped by failure mode |

The **agent-specific evaluators** (preview) are exam-relevant by name:

| Evaluator | Asks | Input |
|---|---|---|
| **`IntentResolutionEvaluator`** | Did the agent correctly identify and address what the user actually wanted? | query, response |
| **`ToolCallAccuracyEvaluator`** | Were the right tools called, with the right parameters, and were they needed? | query, tool calls, tool definitions |
| **`TaskAdherenceEvaluator`** | Did the agent follow its instructions and stay on task? | query, response (+ system message) |

Plus the general evaluators from unit 02.1 (groundedness, relevance, safety), and
`AIAgentConverter`, which turns a thread + run into the evaluator input format so you
do not have to assemble it by hand:

```python
from azure.ai.evaluation import AIAgentConverter
converter = AIAgentConverter(project_client)
data = converter.convert(thread_id=thread.id, run_id=run.id)
```

> **Exam note.** Match the symptom to the evaluator. *"The agent answered a
> different question"* → intent resolution. *"It called the search tool when it
> should have called the order tool, or passed the wrong ID"* → tool call accuracy.
> *"It gave a refund it was told never to give"* → task adherence.

**Continuous evaluation** runs a subset of evaluators against live production traces
on a sampling rate and emits the results to Application Insights, so quality is
monitored the same way latency is. That is the answer to "how do you detect quality
regressions in a deployed agent."

---

## Portal walkthrough

### Step 1 — Connected agents in the portal

**https://ai.azure.com** → your project → **Agents**.

1. Create two specialists first, because you cannot connect an agent that does not
   exist:

   | Agent | Instructions (abbreviated) |
   |---|---|
   | `policy_bot` | "Answer only questions about returns, warranty, and shipping policy. Cite the section." |
   | `order_bot` | "Look up order status. Never invent an order ID." |

2. Create `triage_agent`. In its editor, find **Connected agents** (under Actions in
   newer portal builds; a dedicated pane in older ones) → **+ Add**:

   | Field | Value | Why it matters |
   |---|---|---|
   | Agent | `policy_bot` | which agent to call |
   | Name | `policy_bot` | becomes the **tool name** — no spaces |
   | Description | "Answers questions about returns, warranty and shipping policy." | this is the routing logic |

3. Repeat for `order_bot`.
4. Test in the playground: *"My CX-4400 arrived broken — where is order ORD-12345 and
   can I return it?"* The thread view shows the delegation.

> If your portal build shows no **Connected agents** pane, you are on the newer
> Foundry experience where agents are composed with tools, skills, and
> orchestration rather than an explicit connection pane. The **SDK surface used in
> the lab (`ConnectedAgentTool`) still works**, and the lab is authoritative for
> this course.

### Step 2 — Turn on tracing before you need it

1. Left nav → **Tracing** (under *Observability*).
2. If prompted, **connect an Application Insights resource**. `02_provision_core.ps1`
   creates one; otherwise create it here.
3. Run an agent, then return to **Tracing**. Each run appears as a trace with nested
   spans: the run, each tool call, each model call, with durations and token counts.

That view is what OpenTelemetry instrumentation produces. Unit 02.5 wires it up in
code; here just confirm the connection exists.

### Step 3 — Evaluate an agent run in the portal

1. **Evaluation** → **+ New evaluation** → **Evaluate an agent** (preview).
2. Select the agent and either a dataset of queries or existing threads.
3. Choose the agent evaluators:

   | Evaluator | Detects |
   |---|---|
   | Intent resolution | Answered the wrong question |
   | Tool call accuracy | Wrong tool, wrong parameters, unnecessary call |
   | Task adherence | Violated its instructions |

4. Pick a judge deployment and run it. Results show per-thread scores plus reasons.

### Step 4 — Look at where an approval would go

Open a run's detail and find the tool call. Note that by the time you see it in the
portal, **it has already executed**. There is no portal switch for "ask me first" on
function tools — the gate has to be in your application, on the `requires_action`
seam. (The MCP tool is the exception; it has `require_approval` built in.)

<details>
<summary>Approval gate in code — the shape</summary>

```python
run = agents.runs.create(thread_id=thread.id, agent_id=agent.id)
while run.status in ("queued", "in_progress", "requires_action"):
    if run.status == "requires_action":
        outputs = []
        for call in run.required_action.submit_tool_outputs.tool_calls:
            args = json.loads(call.function.arguments)
            decision = authorise(call.function.name, args)   # your policy
            if decision.allowed:
                result = FUNCTIONS[call.function.name](**args)
            else:
                result = json.dumps({"error": "denied", "reason": decision.reason})
            outputs.append({"tool_call_id": call.id, "output": result})
        run = agents.runs.submit_tool_outputs(thread_id=thread.id, run_id=run.id,
                                              tool_outputs=outputs)
        continue
    time.sleep(0.5)
    run = agents.runs.get(thread_id=thread.id, run_id=run.id)
```

A denial is returned as a **tool result**, not an exception. The agent then explains
to the user why it cannot proceed — which is what you want, and is much better than
crashing the run.
</details>

---

## Troubleshooting

**`Assistant Tool Call Depth Error`**
You nested connected agents more than two levels. Flatten: give the main agent all
the specialists directly, or move the third level into a tool on the second.

**A connected agent never gets called**
Its `description` on the `ConnectedAgentTool` is too vague, or the main agent's
instructions do not tell it to delegate. Both are prompt problems, not code problems.

**A connected agent tries to use a function tool and fails**
Connected agents cannot raise `requires_action` to your process. Re-expose that
capability as an OpenAPI tool or an Azure Function.

**Citations vanish in a multi-agent answer**
Known limitation — the main agent summarises the sub-agent's reply and drops
annotations. Instruct the main agent to reproduce citations verbatim, and verify;
results vary by model.

**Approval gate never triggers**
You used `create_and_process` with `enable_auto_function_calls`, which executes tool
calls before you can see them. Use `runs.create` and your own loop.

**Token cost jumped 5x after splitting into agents**
Expected. The orchestrator pays for its own reasoning plus every sub-agent's full
answer, and each sub-agent replays its own instructions. Reduce the number of
specialists, tighten their instructions, and confirm multi-agent is actually beating
your single-agent baseline on the evaluators.

**Agent evaluators return `nan` or refuse to run**
The evaluator input shape is specific. Use `AIAgentConverter(project_client).convert(thread_id, run_id)`
rather than hand-assembling `tool_calls` and `tool_definitions`.

**Traces do not appear in Application Insights**
The project has no Application Insights connection, or your code never called
`configure_azure_monitor` / enabled the agent instrumentation. Unit 02.5 covers it.

---

## Check yourself

[quiz.md](quiz.md) — 15 questions on orchestration patterns, connected-agent limits,
approval controls, and agent evaluators.

## Next

[02.5 — Optimize and operationalize generative AI systems](../05_optimize_and_observe/README.md)
