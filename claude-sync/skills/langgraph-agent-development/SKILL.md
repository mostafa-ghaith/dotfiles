---
name: langgraph-agent-development
description: |
  Comprehensive guide for building AI agents using LangGraph. Use this skill when:
  (1) Creating new LangGraph agents or graphs
  (2) Working with StateGraph, nodes, and edges
  (3) Implementing human-in-the-loop with interrupts
  (4) Building custom tools and ToolNodes
  (5) Managing state with reducers and annotations
  (6) Persisting state to databases (PostgreSQL, MongoDB)
  (7) Creating multi-agent systems with supervisors
  (8) Implementing complex workflows with subgraphs and branching
  (9) Debugging with time-travel and checkpoints
  (10) Streaming responses and events

  Trigger keywords: langgraph, stategraph, agent graph, checkpoint, interrupt, human-in-the-loop,
  multi-agent, supervisor, tool node, state reducer, graph persistence, agentic workflow
---

# LangGraph Agent Development

LangGraph is a low-level orchestration framework for building stateful, multi-actor applications with LLMs. It models workflows as graphs where nodes are functions and edges define execution flow.

## Quick Start

```python
from langgraph.graph import StateGraph, START, END
from typing import TypedDict, Annotated
from operator import add

# 1. Define State
class State(TypedDict):
    messages: Annotated[list, add]
    context: str

# 2. Create Graph
graph = StateGraph(State)

# 3. Add Nodes
graph.add_node("process", process_node)
graph.add_node("respond", respond_node)

# 4. Add Edges
graph.add_edge(START, "process")
graph.add_conditional_edges("process", route_function)
graph.add_edge("respond", END)

# 5. Compile and Run
app = graph.compile(checkpointer=checkpointer)
result = app.invoke({"messages": [], "context": ""})
```

## Core Concepts Reference

For detailed information on specific topics, consult:

- **[Core Concepts](references/core-concepts.md)**: StateGraph, nodes, edges, compilation
- **[State Management](references/state-management.md)**: Reducers, annotations, MessagesState
- **[Custom Tools](references/tools.md)**: Building tools, ToolNode, state updates from tools
- **[Persistence](references/persistence.md)**: Checkpointers, PostgreSQL, MongoDB setup
- **[Interrupts & HITL](references/interrupts.md)**: Human-in-the-loop, Command, dynamic routing
- **[Advanced Patterns](references/patterns.md)**: Multi-agent, subgraphs, streaming, time-travel

## Key Patterns

### Basic Agent Pattern

```python
from langgraph.prebuilt import create_react_agent

agent = create_react_agent(
    model=llm,
    tools=[tool1, tool2],
    checkpointer=checkpointer
)
```

### Human-in-the-Loop Pattern

```python
from langgraph.types import interrupt, Command

def approval_node(state):
    response = interrupt({"question": "Approve this action?", "data": state["pending_action"]})
    if response == "approved":
        return Command(goto="execute")
    return Command(goto="cancel")
```

### State Update from Tools Pattern

```python
from langgraph.prebuilt import InjectedState
from langgraph.types import Command

@tool
def update_context(query: str, state: Annotated[dict, InjectedState]) -> Command:
    new_data = fetch_data(query)
    return Command(update={"context": new_data})
```

### Multi-Agent Supervisor Pattern

```python
from langgraph_supervisor import create_supervisor

supervisor = create_supervisor(
    agents=[researcher, writer, critic],
    model=llm,
    prompt="Route tasks to appropriate specialists"
)
```

## Installation

```bash
# Core
pip install langgraph

# With PostgreSQL persistence
pip install langgraph-checkpoint-postgres

# With MongoDB persistence
pip install langgraph-checkpoint-mongodb

# Multi-agent supervisor
pip install langgraph-supervisor
```

## Essential Imports

```python
# Core
from langgraph.graph import StateGraph, START, END
from langgraph.types import Command, Send, interrupt

# State Management
from typing import TypedDict, Annotated
from langgraph.graph import MessagesState
from langgraph.graph.message import add_messages

# Tools
from langgraph.prebuilt import ToolNode, tools_condition, InjectedState
from langchain_core.tools import tool

# Checkpointers
from langgraph.checkpoint.memory import InMemorySaver
from langgraph.checkpoint.postgres import PostgresSaver, AsyncPostgresSaver
from langgraph.checkpoint.mongodb import MongoDBSaver

# Agents
from langgraph.prebuilt import create_react_agent
from langgraph_supervisor import create_supervisor
```

## Workflow

1. **Define State Schema** - Use TypedDict/Pydantic with reducers
2. **Create Nodes** - Functions that process and update state
3. **Connect with Edges** - Normal or conditional routing
4. **Add Checkpointer** - For persistence and interrupts
5. **Compile Graph** - Validate and prepare for execution
6. **Invoke/Stream** - Run with input state

## Common Mistakes to Avoid

- Forgetting to call `.compile()` before execution
- Not configuring a checkpointer when using interrupts
- Using InMemorySaver in production (use PostgresSaver instead)
- Returning state keys not defined in schema
- Missing reducers for list/accumulating fields
- Not handling tool errors in custom ToolNodes
