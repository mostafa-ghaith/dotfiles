# Advanced Patterns in LangGraph

## Table of Contents
- [Multi-Agent Systems](#multi-agent-systems)
- [Subgraphs](#subgraphs)
- [Branching and Parallelism](#branching-and-parallelism)
- [Streaming](#streaming)
- [Time Travel and Debugging](#time-travel-and-debugging)
- [Error Handling](#error-handling)
- [Production Patterns](#production-patterns)

---

## Multi-Agent Systems

### Supervisor Pattern

A central supervisor coordinates specialized agents:

```python
from langgraph_supervisor import create_supervisor

# Define specialized agents
researcher = create_react_agent(llm, [search_tool, wiki_tool])
writer = create_react_agent(llm, [write_tool, edit_tool])
critic = create_react_agent(llm, [analyze_tool, score_tool])

# Create supervisor
supervisor = create_supervisor(
    agents=[researcher, writer, critic],
    model=llm,
    prompt="""You are a project manager coordinating a team.
    - researcher: finds information and data
    - writer: creates content
    - critic: reviews and improves content

    Route tasks to the appropriate specialist."""
)

# Compile and use
app = supervisor.compile(checkpointer=checkpointer)
```

### Hierarchical Multi-Agent

Multi-level supervision for complex workflows:

```python
# Level 1: Specialized teams
research_team = create_supervisor(
    agents=[web_researcher, db_researcher, api_researcher],
    model=llm,
    prompt="Coordinate research across sources"
)

content_team = create_supervisor(
    agents=[writer, editor, formatter],
    model=llm,
    prompt="Coordinate content creation"
)

# Level 2: Top-level coordinator
coordinator = create_supervisor(
    agents=[research_team, content_team],
    model=llm,
    prompt="Coordinate research and content teams"
)
```

### Tool-Based Agent Handoff

Modern pattern using tools for agent communication:

```python
from langchain_core.tools import tool

@tool
def transfer_to_specialist(
    specialist: str,
    context: str,
    task: str
) -> str:
    """Transfer conversation to a specialist agent.

    Args:
        specialist: Name of specialist (researcher, writer, analyst)
        context: Relevant context to pass
        task: Specific task for the specialist
    """
    return f"Transferring to {specialist}"

# In your graph
def router_node(state):
    last_message = state["messages"][-1]

    if hasattr(last_message, "tool_calls"):
        for call in last_message.tool_calls:
            if call["name"] == "transfer_to_specialist":
                return Command(
                    goto=call["args"]["specialist"],
                    update={"transfer_context": call["args"]["context"]}
                )

    return Command(goto="respond")
```

### Shared State Multi-Agent

```python
class SharedState(TypedDict):
    messages: Annotated[list, add_messages]
    research_notes: Annotated[list, add]
    draft: str
    feedback: list

def researcher_node(state):
    # Access shared state
    notes = research(state["messages"][-1].content)
    return {"research_notes": notes}

def writer_node(state):
    # Use research notes from shared state
    draft = write_content(state["research_notes"])
    return {"draft": draft}

def critic_node(state):
    feedback = critique(state["draft"])
    return {"feedback": feedback}
```

---

## Subgraphs

Modular, reusable graph components.

### Creating a Subgraph

```python
# Define subgraph
def create_research_subgraph():
    class ResearchState(TypedDict):
        query: str
        results: list
        summary: str

    subgraph = StateGraph(ResearchState)

    subgraph.add_node("search", search_node)
    subgraph.add_node("analyze", analyze_node)
    subgraph.add_node("summarize", summarize_node)

    subgraph.add_edge(START, "search")
    subgraph.add_edge("search", "analyze")
    subgraph.add_edge("analyze", "summarize")
    subgraph.add_edge("summarize", END)

    return subgraph.compile()

# Use in parent graph
research_subgraph = create_research_subgraph()

parent_graph = StateGraph(ParentState)
parent_graph.add_node("research", research_subgraph)
parent_graph.add_node("process", process_node)

parent_graph.add_edge(START, "research")
parent_graph.add_edge("research", "process")
```

### State Mapping Between Graphs

```python
def state_mapper(parent_state):
    """Map parent state to subgraph input."""
    return {
        "query": parent_state["user_query"],
        "results": [],
        "summary": ""
    }

def result_mapper(subgraph_output):
    """Map subgraph output back to parent state."""
    return {
        "research_summary": subgraph_output["summary"],
        "raw_results": subgraph_output["results"]
    }

# Add subgraph with mappers
parent_graph.add_node(
    "research",
    research_subgraph,
    input_mapper=state_mapper,
    output_mapper=result_mapper
)
```

### Communicating with Parent

```python
from langgraph.types import Command

def subgraph_node(state):
    if state["needs_parent_approval"]:
        return Command(
            goto=Command.PARENT,  # Route to parent
            update={"pending_approval": state["data"]}
        )
    return {"processed": True}
```

---

## Branching and Parallelism

### Fan-Out with Send

```python
from langgraph.types import Send

def fan_out_node(state):
    """Send items to parallel processors."""
    items = state["items"]

    return [
        Send("processor", {"item": item, "index": i})
        for i, item in enumerate(items)
    ]
```

### Conditional Branching

```python
def branch_router(state):
    """Route to different branches based on state."""
    category = state["category"]

    if category == "urgent":
        return "priority_handler"
    elif category == "question":
        return "qa_handler"
    elif category == "feedback":
        return "feedback_handler"
    else:
        return "default_handler"

graph.add_conditional_edges(
    "classifier",
    branch_router,
    {
        "priority_handler": "priority_handler",
        "qa_handler": "qa_handler",
        "feedback_handler": "feedback_handler",
        "default_handler": "default_handler"
    }
)
```

### Parallel Execution with Join

```python
class ParallelState(TypedDict):
    input: str
    path_a_result: str
    path_b_result: str
    combined: str

# Parallel paths
graph.add_node("path_a", path_a_node)
graph.add_node("path_b", path_b_node)
graph.add_node("join", join_node)

# Fan out from start
graph.add_edge(START, "path_a")
graph.add_edge(START, "path_b")

# Join results
graph.add_edge("path_a", "join")
graph.add_edge("path_b", "join")
graph.add_edge("join", END)

def join_node(state):
    """Combine results from parallel paths."""
    return {
        "combined": f"{state['path_a_result']} + {state['path_b_result']}"
    }
```

### Dynamic Parallel Branches

```python
def dynamic_fan_out(state):
    """Create parallel branches based on runtime data."""
    tasks = analyze_and_split(state["input"])

    if not tasks:
        return []  # No branches = skip edge

    return [
        Send("task_processor", {"task": task, "task_id": i})
        for i, task in enumerate(tasks)
    ]

graph.add_conditional_edges(
    "analyzer",
    dynamic_fan_out,
    ["task_processor"]
)
```

---

## Streaming

### Basic Streaming

```python
# Stream state updates
for event in app.stream({"messages": []}, stream_mode="updates"):
    print(f"Node: {event}")

# Stream full state
for state in app.stream({"messages": []}, stream_mode="values"):
    print(f"State: {state}")
```

### Token Streaming with astream_events

```python
async def stream_tokens():
    async for event in app.astream_events(
        {"messages": [query]},
        version="v2"
    ):
        if event["event"] == "on_chat_model_stream":
            chunk = event["data"]["chunk"]
            if chunk.content:
                print(chunk.content, end="", flush=True)
```

### Custom Stream Events

```python
from langgraph.types import StreamWriter

def streaming_node(state, writer: StreamWriter):
    """Node that emits custom stream events."""
    writer({"type": "progress", "step": "starting"})

    for i, item in enumerate(state["items"]):
        result = process(item)
        writer({
            "type": "progress",
            "step": f"processed {i+1}/{len(state['items'])}"
        })

    writer({"type": "progress", "step": "complete"})
    return {"processed": True}

# Consume custom events
for event in app.stream(input_data, stream_mode=["updates", "custom"]):
    if isinstance(event, dict) and event.get("type") == "progress":
        print(f"Progress: {event['step']}")
```

### Multiple Stream Modes

```python
# Combine modes
for event in app.stream(
    {"messages": []},
    stream_mode=["values", "updates", "messages"]
):
    mode = event.get("__stream_mode__")
    if mode == "values":
        print(f"Full state: {event}")
    elif mode == "updates":
        print(f"Update: {event}")
    elif mode == "messages":
        print(f"Message: {event}")
```

---

## Time Travel and Debugging

### Viewing History

```python
# Get all checkpoints
for state in app.get_state_history(config):
    print(f"Step {state.metadata['step']}")
    print(f"  Created: {state.created_at}")
    print(f"  Values: {state.values}")
    print(f"  Next: {state.next}")
```

### Replaying from Checkpoint

```python
# Get history
history = list(app.get_state_history(config))

# Select checkpoint to replay from
checkpoint = history[5]  # 6th state

# Create new config with checkpoint
replay_config = {
    **config,
    "configurable": {
        **config["configurable"],
        "checkpoint_id": checkpoint.config["configurable"]["checkpoint_id"]
    }
}

# Replay from that point
result = app.invoke(None, replay_config)
```

### Forking Execution

```python
# Fork from a past state with modified values
fork_state = history[3].values.copy()
fork_state["user_input"] = "different input"

# Update state at checkpoint
app.update_state(
    {**config, "configurable": {
        **config["configurable"],
        "checkpoint_id": history[3].config["configurable"]["checkpoint_id"]
    }},
    fork_state
)

# Continue from fork
result = app.invoke(None, config)
```

### Graph Visualization

```python
# Generate Mermaid diagram
mermaid = app.get_graph().draw_mermaid()
print(mermaid)

# Save as image
app.get_graph().draw_png("workflow.png")

# ASCII representation
print(app.get_graph().draw_ascii())
```

### LangSmith Integration

```python
import os
os.environ["LANGCHAIN_TRACING_V2"] = "true"
os.environ["LANGCHAIN_API_KEY"] = "your-key"

# All executions are now traced
result = app.invoke({"messages": []}, config)

# View traces at https://smith.langchain.com
```

---

## Error Handling

### Node-Level Error Handling

```python
def safe_node(state):
    try:
        result = risky_operation(state)
        return {"result": result, "error": None}
    except ValueError as e:
        return {"result": None, "error": str(e)}
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        raise  # Re-raise for graph-level handling
```

### Retry Pattern

```python
from tenacity import retry, stop_after_attempt, wait_exponential

@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=1, max=10)
)
def reliable_node(state):
    return external_api_call(state["data"])
```

### Fallback Pattern

```python
def node_with_fallback(state):
    try:
        return primary_processor(state)
    except PrimaryError:
        try:
            return fallback_processor(state)
        except FallbackError:
            return {"status": "failed", "error": "All processors failed"}
```

### Circuit Breaker

```python
from datetime import datetime, timedelta

class CircuitBreaker:
    def __init__(self, failure_threshold=5, recovery_time=60):
        self.failures = 0
        self.threshold = failure_threshold
        self.recovery_time = timedelta(seconds=recovery_time)
        self.last_failure = None

    def can_proceed(self):
        if self.failures >= self.threshold:
            if datetime.now() - self.last_failure < self.recovery_time:
                return False
            self.failures = 0
        return True

    def record_failure(self):
        self.failures += 1
        self.last_failure = datetime.now()

    def record_success(self):
        self.failures = 0

circuit = CircuitBreaker()

def protected_node(state):
    if not circuit.can_proceed():
        return {"status": "circuit_open", "retry_after": circuit.recovery_time}

    try:
        result = risky_call(state)
        circuit.record_success()
        return {"result": result}
    except Exception:
        circuit.record_failure()
        raise
```

---

## Production Patterns

### Rate Limiting

```python
from asyncio import Semaphore
from functools import wraps

semaphore = Semaphore(10)  # Max 10 concurrent

async def rate_limited_node(state):
    async with semaphore:
        return await process(state)
```

### Caching

```python
from functools import lru_cache
from hashlib import md5

def cached_node(state):
    cache_key = md5(str(state["query"]).encode()).hexdigest()

    if cache_key in cache:
        return {"result": cache[cache_key], "cached": True}

    result = expensive_computation(state["query"])
    cache[cache_key] = result
    return {"result": result, "cached": False}
```

### Health Checks

```python
async def health_check():
    """Check all dependencies."""
    checks = {
        "database": check_database(),
        "llm": check_llm(),
        "checkpointer": check_checkpointer()
    }

    return {
        "healthy": all(checks.values()),
        "checks": checks
    }
```

### Graceful Degradation

```python
def resilient_node(state):
    features = []

    # Try premium features
    try:
        features.append(premium_feature(state))
    except PremiumUnavailable:
        pass  # Skip if unavailable

    # Try standard features
    try:
        features.append(standard_feature(state))
    except StandardUnavailable:
        features.append(basic_fallback(state))

    return {"features": features}
```

### Observability

```python
import structlog

logger = structlog.get_logger()

def observed_node(state, config):
    request_id = config.get("metadata", {}).get("request_id")

    logger.info(
        "node_started",
        node="observed_node",
        request_id=request_id,
        input_size=len(str(state))
    )

    start = time.time()
    result = process(state)
    duration = time.time() - start

    logger.info(
        "node_completed",
        node="observed_node",
        request_id=request_id,
        duration_ms=duration * 1000
    )

    return result
```
