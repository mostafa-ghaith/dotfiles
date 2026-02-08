# LangGraph Core Concepts

## Table of Contents
- [StateGraph](#stategraph)
- [State Schema](#state-schema)
- [Nodes](#nodes)
- [Edges](#edges)
- [Compilation](#compilation)
- [Execution Model](#execution-model)

---

## StateGraph

StateGraph is the primary graph class that manages workflow execution. It's parameterized by a user-defined State object.

```python
from langgraph.graph import StateGraph, START, END

class MyState(TypedDict):
    messages: list
    context: str

graph = StateGraph(MyState)
```

### Key Properties
- **State**: Shared data structure representing current snapshot
- **Nodes**: Functions that process state
- **Edges**: Routing functions between nodes

### Special Nodes
- `START`: Entry point (virtual node)
- `END`: Terminal node (graph completion)

---

## State Schema

State can be defined using TypedDict, dataclass, or Pydantic BaseModel.

### TypedDict (Recommended)

```python
from typing import TypedDict, Annotated
from operator import add

class AgentState(TypedDict):
    messages: Annotated[list, add]  # With reducer
    context: str                      # Overwrites
    count: Annotated[int, add]       # Accumulates
```

### Pydantic BaseModel

```python
from pydantic import BaseModel
from typing import Annotated
from operator import add

class AgentState(BaseModel):
    messages: Annotated[list, add]
    context: str = ""

    class Config:
        arbitrary_types_allowed = True
```

### Multiple Schemas

Graphs support input, output, and private schemas:

```python
class InputState(TypedDict):
    query: str

class OutputState(TypedDict):
    response: str

class PrivateState(TypedDict):
    query: str
    response: str
    internal_data: dict  # Not exposed

graph = StateGraph(PrivateState, input=InputState, output=OutputState)
```

---

## Nodes

Nodes are Python functions that process state and return updates.

### Basic Node

```python
def process_node(state: AgentState) -> dict:
    # Process state
    result = process(state["messages"])
    # Return updates (only changed keys)
    return {"context": result}
```

### Node with Config

```python
from langchain_core.runnables import RunnableConfig

def node_with_config(state: AgentState, config: RunnableConfig) -> dict:
    # Access config metadata
    thread_id = config["configurable"]["thread_id"]
    return {"context": f"Thread: {thread_id}"}
```

### Async Node

```python
async def async_node(state: AgentState) -> dict:
    result = await async_process(state["messages"])
    return {"context": result}
```

### Adding Nodes

```python
graph.add_node("processor", process_node)
graph.add_node("responder", respond_node)

# With lambda
graph.add_node("simple", lambda state: {"count": 1})
```

---

## Edges

Edges define the execution flow between nodes.

### Normal Edges

```python
# Direct connection
graph.add_edge(START, "first_node")
graph.add_edge("first_node", "second_node")
graph.add_edge("second_node", END)
```

### Conditional Edges

```python
def route_function(state: AgentState) -> str:
    if state["context"] == "done":
        return "finish"
    return "continue"

graph.add_conditional_edges(
    "processor",
    route_function,
    {
        "continue": "processor",  # Loop back
        "finish": "responder"
    }
)
```

### Conditional Entry Point

```python
def entry_router(state: AgentState) -> str:
    if state.get("fast_path"):
        return "quick_response"
    return "full_process"

graph.add_conditional_edges(START, entry_router)
```

### Tools Condition (Prebuilt)

```python
from langgraph.prebuilt import tools_condition

graph.add_conditional_edges(
    "agent",
    tools_condition,  # Routes to "tools" if tool calls present
    {"tools": "tools", END: END}
)
```

---

## Compilation

Graphs must be compiled before execution.

### Basic Compilation

```python
app = graph.compile()
```

### With Checkpointer

```python
from langgraph.checkpoint.memory import InMemorySaver

checkpointer = InMemorySaver()
app = graph.compile(checkpointer=checkpointer)
```

### With Breakpoints (Debugging)

```python
app = graph.compile(
    checkpointer=checkpointer,
    interrupt_before=["sensitive_node"],  # Pause before
    interrupt_after=["review_node"]       # Pause after
)
```

### Validation

Compilation validates:
- All edges connect to valid nodes
- No orphan nodes
- Proper START/END connections
- State schema compatibility

---

## Execution Model

LangGraph uses a message-passing model inspired by Google's Pregel system.

### Super-Steps

Execution proceeds in discrete "super-steps":
1. Nodes receive messages and become active
2. Active nodes execute and emit messages
3. Nodes become inactive when no messages arrive
4. Process repeats until all nodes are inactive

### Recursion Limit

Default limit is 1000 steps to prevent infinite loops:

```python
# Check current step
def node(state, config):
    step = config["metadata"]["langgraph_step"]
    if step > 50:
        return {"status": "max_steps_reached"}
    return {"status": "processing"}
```

### Invocation Methods

```python
# Synchronous
result = app.invoke({"messages": []}, config={"configurable": {"thread_id": "1"}})

# Streaming
for event in app.stream({"messages": []}, stream_mode="updates"):
    print(event)

# Async
result = await app.ainvoke({"messages": []})

# Async streaming
async for event in app.astream({"messages": []}, stream_mode="values"):
    print(event)
```

### Stream Modes

- `"values"`: Full state after each step
- `"updates"`: Only state changes
- `"messages"`: Message-specific streaming
- `"custom"`: User-defined events
- `["updates", "custom"]`: Multiple modes

---

## Graph Visualization

```python
# Get Mermaid diagram
print(app.get_graph().draw_mermaid())

# Save as PNG (requires graphviz)
app.get_graph().draw_png("graph.png")
```

---

## Best Practices

1. **Keep nodes focused**: Each node should do one thing well
2. **Use descriptive names**: `"validate_input"` not `"node1"`
3. **Return minimal updates**: Only return changed keys
4. **Handle errors gracefully**: Catch exceptions in nodes
5. **Use typing**: Full type hints for state and returns
6. **Test incrementally**: Verify each node before connecting
