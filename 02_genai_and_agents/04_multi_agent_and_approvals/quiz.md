# 02.4 — Multi-agent, approvals, and monitoring: quiz

15 questions. Answers at the bottom. Aim for 12+ before moving on.

---

**1.** A main agent uses `ConnectedAgentTool` to call `policy_bot`, which itself has
a `ConnectedAgentTool` pointing at `citation_bot`. What happens?

- A. It works; nesting is unlimited
- B. It fails with a tool-call-depth error — connected agents allow a maximum depth of 2
- C. `citation_bot` is silently ignored
- D. The main agent calls `citation_bot` directly instead

---

**2.** A connected sub-agent needs to query an internal Python function that reads a
local database. What should you do?

- A. Give the sub-agent a `FunctionTool` and handle `requires_action`
- B. Expose the lookup as an HTTP API and use the OpenAPI tool, or as an Azure Function
- C. Move the database into a vector store
- D. Give the main agent the function and let it pass results down

---

**3.** Which pattern transfers ownership of the conversation, so the specialist
replies to the user directly for subsequent turns?

- A. Connected agents
- B. Concurrent (fan-out/fan-in)
- C. Handoff
- D. Sequential

---

**4.** A compliance workflow must always run extract, then validate, then summarise,
in that exact order, with an auditable record of each stage. Which orchestration?

- A. Group chat
- B. Sequential
- C. Magentic
- D. Connected agents

---

**5.** Three agents must review the same draft from risk, legal, and tone
perspectives, and their opinions are independent. Which orchestration minimises
latency?

- A. Sequential
- B. Handoff
- C. Concurrent, with a fan-in merge
- D. Magentic

---

**6.** Which orchestration maintains an explicit task ledger, tracks progress,
detects stalls, and replans when a step fails?

- A. Group chat
- B. Magentic
- C. Concurrent
- D. Handoff

---

**7.** An agent is instructed "never issue a refund above $200" and is given an
unguarded refund tool. Why is this insufficient?

- A. Instructions are truncated after 500 tokens
- B. The instruction is a suggestion the model may violate under confusion or prompt injection; the control must sit between the tool call and its execution
- C. Refund tools ignore instructions by design
- D. Instructions apply only to the first run on a thread

---

**8.** Where must a human-approval gate be implemented for a function tool?

- A. In the agent's instructions
- B. In the Foundry portal's agent settings
- C. In your application's run loop, between `requires_action` and executing the function
- D. In the content filter configuration

---

**9.** Which method makes an approval gate **impossible** to implement?

- A. `runs.create` followed by manual polling
- B. `runs.create_and_process` with `enable_auto_function_calls`
- C. `runs.submit_tool_outputs`
- D. `run_steps.list`

---

**10.** Your gate denies a tool call. What should you send back?

- A. Raise an exception and abandon the run
- B. Cancel the run
- C. A tool output describing the denial, so the agent can explain it to the user
- D. An empty string

---

**11.** An agent consistently calls the search tool when the user asked about a
specific order ID. Which evaluator surfaces this?

- A. `IntentResolutionEvaluator`
- B. `ToolCallAccuracyEvaluator`
- C. `GroundednessEvaluator`
- D. `FluencyEvaluator`

---

**12.** An agent instructed never to discuss competitors produces a detailed
comparison with a competitor. Which evaluator scores this poorly?

- A. `CoherenceEvaluator`
- B. `RelevanceEvaluator`
- C. `TaskAdherenceEvaluator`
- D. `RetrievalEvaluator`

---

**13.** Which two are appropriate safeguards for a fully **autonomous** agent that
runs unattended overnight? Choose two.

- A. Restricting it to read-only or reversible tools
- B. Requiring a human to confirm every action
- C. A hard cap on iterations and spend, plus alerting
- D. Increasing temperature to encourage exploration

---

**14.** What does `AIAgentConverter` do?

- A. Converts a hub-based project to a Foundry project
- B. Converts thread and run data into the input format the agent evaluators expect
- C. Converts function tools into OpenAPI tools
- D. Converts a single agent into a connected-agent topology

---

**15.** Which is **not** a real cost consideration when moving from one agent to a
connected-agent topology?

- A. The orchestrator pays prompt tokens to read each sub-agent's full answer
- B. Each sub-agent replays its own instructions on every invocation
- C. Multiple model calls replace one
- D. Each connected agent requires its own model deployment and quota allocation

---
---

## Answers

**1 — B.** Connected agents have a maximum depth of 2: a parent may have many
sub-agent siblings, but sub-agents cannot have sub-agents. Exceeding it raises an
`Assistant Tool Call Depth Error`. Flatten the topology — attach the third
specialist directly to the main agent.

**2 — B.** Connected agents cannot use local function calling; they cannot raise
`requires_action` into your process, so A is impossible. The documented workaround is
the OpenAPI spec tool or the Azure Functions tool, both of which Foundry invokes
directly. D changes the topology so the sub-agent is no longer doing the work.

**3 — C.** Handoff transfers control: the specialist owns the conversation from that
point and replies to the user directly. Connected agents *delegate* — control returns
to the main agent, which composes the final reply. Sequential and concurrent are
deterministic pipelines with no notion of conversational ownership.

**4 — B.** "Always in this exact order, with an auditable record" is the definition
of deterministic sequential orchestration. Group chat, magentic, and connected agents
are all model-routed, so the order is not guaranteed — which is exactly what a
compliance workflow cannot accept.

**5 — C.** Independent perspectives fan out in parallel and fan in for a merge, so
latency is the slowest branch rather than the sum. Sequential would triple the wall
time for no benefit; handoff and magentic are dynamic patterns for problems where
you do not know who should act.

**6 — B.** Magentic orchestration is defined by its manager maintaining a task ledger
— a plan with progress tracking, stall detection, and replanning. Group chat has a
roster and a speaker-selection policy but no explicit plan.

**7 — B.** Instructions shape behaviour probabilistically; they are not an
authorisation boundary. A crafted message claiming manager approval, or simple
model confusion, can produce the forbidden call. Real controls execute in your code,
where the model cannot reach them.

**8 — C.** The only point at which you can intervene before a function executes is
the `requires_action` state in your own run loop. The portal shows tool calls after
they have run; instructions are advisory; content filters police text, not actions.
(The MCP tool is the one exception with platform-level `require_approval`.)

**9 — B.** `create_and_process` with auto function calling executes tool calls inside
the SDK before returning, so there is no seam to intervene at. It is the right choice
for read-only helpers and the wrong choice for anything with side effects.

**10 — C.** Return a structured tool output such as
`{"error": "denied_by_policy", "reason": "..."}`. The run continues, the agent reads
the denial, and it can explain the situation to the user or offer an alternative.
Raising or cancelling turns a governed refusal into an outage.

**11 — B.** `ToolCallAccuracyEvaluator` judges whether the right tools were selected,
whether the parameters were correct, and whether the calls were necessary. Intent
resolution is about understanding the request, groundedness is about the supporting
context, and fluency is about the prose.

**12 — C.** Task adherence measures whether the agent followed its system
instructions and stayed within its remit. The answer could be coherent, relevant, and
well written while still violating an explicit rule — which is precisely the gap task
adherence exists to close.

**13 — A and C.** With no human in the loop, safety has to come from limiting blast
radius (read-only or reversible actions) and from hard, non-negotiable caps plus
alerting so a runaway is bounded and visible. B describes a supervised workflow, not
an autonomous one. D increases variability, which is the opposite of what unattended
operation needs.

**14 — B.** `AIAgentConverter(project_client).convert(thread_id, run_id)` reshapes
Foundry thread and run data — messages, tool calls, tool definitions — into the
dictionary the agent evaluators consume, so you do not assemble it by hand and get
`nan` scores from a mis-shaped input.

**15 — D.** Connected agents share the project's model deployments; creating five
agents does not create five deployments or five quota allocations. (Quota pressure
*is* real, but it comes from more calls against the same deployment, not from
per-agent allocations.) A, B, and C are all genuine and are why multi-agent
typically costs several times a single agent.

---

## Lab exercise solutions

**1. Depth limit.** The run fails with an `Assistant Tool Call Depth Error` (surfaced
in `run.last_error`, with the run status `failed`) as soon as `policy_bot` tries to
invoke its own connected agent. Maximum legal depth is **2** — one parent, one layer
of children. The fix is to flatten: attach the third specialist directly to the
orchestrator so all specialists are siblings. If you genuinely need deeper
composition, the second level must reach its dependency through a non-agent tool
(OpenAPI, Azure Function, search) rather than through another connected agent.

**2. Beat the gate.** With the gate in place, `AUDIT` stays empty for all three
attempts regardless of how convincing the message is — invented override codes,
claimed prior approvals, and manufactured urgency all reach the gate as an
`issue_refund` call with `amount_usd = 412`, and the threshold check rejects it
before `issue_refund` is ever invoked. The model's reply changes; the outcome does
not. With the threshold removed, at least one of the three usually succeeds and the
audit log records a real money movement.

One sentence: **a security control must live in code the model cannot influence —
between the request to act and the act itself — because anything expressed in the
prompt is advice, not enforcement.**

**3. Is multi-agent worth it?** On this small, well-scoped workload the honest answer
is usually **no**. The single agent, given the policy in its instructions and one
lookup tool, scores comparably on intent resolution while using roughly a third to a
half of the total tokens once you count the sub-agents' spend as well as the
orchestrator's. Multi-agent starts to win when: the tool count grows past roughly ten
and tool selection degrades; specialists need genuinely different models, prompts, or
permissions; or teams need to own and evaluate their agent independently. The
discipline is to **keep the single-agent baseline and re-measure** — "we split it
into agents" is an architecture change that must justify itself on evaluator scores,
not on elegance.

**4. Group chat.** A workable shape:

```python
transcript = [f"CUSTOMER: {COMPLAINT}"]
roster = {"drafter": drafter, "compliance": compliance}

for turn in range(3):
    choice = one_shot(manager,
        "Transcript:\n" + "\n".join(transcript) +
        "\n\nReply with exactly one of: drafter, compliance, DONE.")
    name = choice.strip().lower()
    if "done" in name:
        break
    speaker = roster.get("compliance" if "compliance" in name else "drafter")
    said = one_shot(speaker, "\n".join(transcript))
    transcript.append(f"{name.upper()}: {said}")
```

Compared with the concurrent fan-out, group chat costs noticeably more — every turn
replays the growing transcript, so tokens grow quadratically with rounds — but it
produces a *better final artefact*, because the drafter actually sees and responds
to the compliance critique rather than a merger agent trying to reconcile three
opinions after the fact. That is the real trade: concurrent is cheap and parallel
but has no feedback loop; group chat is expensive and serial but iterates. Choose
concurrent when you need independent signals, group chat when you need revision.
