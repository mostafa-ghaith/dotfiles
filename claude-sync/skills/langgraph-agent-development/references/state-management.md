# State Management in LangGraph

## Table of Contents
- [State Overview](#state-overview)
- [Reducers](#reducers)
- [Annotations](#annotations)
- [MessagesState](#messagesstate)
- [Custom Reducers](#custom-reducers)
- [State Channels](#state-channels)
- [Private State](#private-state)

---

## State Overview

State in LangGraph is a shared data structure that maintains information as the graph processes data. It's updated by nodes and passed along edges.

### Basic State Definition

```python
from typing import TypedDict

class SimpleState(TypedDict):
    input: str
    output: str
    intermediate: list
```

### How State Updates Work

1. Node receives current state
2. Node processes and returns updates
3. Updates are merged into state using reducers
4. Updated state is passed to next node

```python
def my_node(state: SimpleState) -> dict:
    # Only return keys you want to update
    return {"output": "processed: " + state["input"]}
```

---

## Reducers

Reducers define how new data combines with existing data. Without a reducer, values are overwritten.

### Default Behavior (Overwrite)

```python
class OverwriteState(TypedDict):
    value: str  # Each update replaces the previous value

# Node returns {"value": "new"} -> state["value"] becomes "new"
```

### With Reducer (Merge)

```python
from typing import Annotated
from operator import add

class AccumulatingState(TypedDict):
    values: Annotated[list, add]  # Lists are concatenated

# Node returns {"values": [1, 2]} -> appends to existing list
```

### Common Reducer Patterns

```python
from operator import add

# List concatenation
messages: Annotated[list, add]

# Integer addition
count: Annotated[int, add]

# String concatenation
log: Annotated[str, add]

# Set union
from operator import or_
tags: Annotated[set, or_]
```

---

## Annotations

Annotations attach metadata to state fields, including reducers.

### Using Annotated Type

```python
from typing import Annotated

class State(TypedDict):
    # Field with reducer
    messages: Annotated[list, add_messages]

    # Field with custom reducer
    data: Annotated[dict, merge_dicts]

    # Field without reducer (overwrites)
    status: str
```

### Multiple Annotations

```python
from typing import Annotated

class State(TypedDict):
    # Can combine with other annotations
    messages: Annotated[list[Message], add_messages]
```

---

## MessagesState

MessagesState is a prebuilt state for message-based applications.

### Using MessagesState

```python
from langgraph.graph import MessagesState

# MessagesState is equivalent to:
# class MessagesState(TypedDict):
#     messages: Annotated[list[AnyMessage], add_messages]

graph = StateGraph(MessagesState)
```

### The add_messages Reducer

`add_messages` provides intelligent message handling:

```python
from langgraph.graph.message import add_messages

# Features:
# - Deserializes message formats
# - Handles message ID-based updates
# - Converts OpenAI format to LangChain format
# - Supports message replacement by ID

class State(TypedDict):
    messages: Annotated[list, add_messages]
```

### Message Updates by ID

```python
from langchain_core.messages import ToolMessage

# Original message with ID "msg-123"
# To update/replace it:
def node(state):
    return {
        "messages": [
            ToolMessage(
                content="Updated content",
                tool_call_id="call-456",
                id="msg-123"  # Same ID replaces the original
            )
        ]
    }
```

### Extending MessagesState

```python
from langgraph.graph import MessagesState

class ExtendedState(MessagesState):
    context: str
    user_id: str
    metadata: dict

# Or using spread:
from langgraph.graph import MessagesState

class ExtendedState(TypedDict):
    messages: Annotated[list, add_messages]  # From MessagesState
    documents: list[str]
    summary: str
```

---

## Custom Reducers

Create custom reducers for complex merge logic.

### Basic Custom Reducer

```python
def merge_lists_unique(left: list, right: list) -> list:
    """Merge lists keeping only unique items."""
    return list(set(left + right))

class State(TypedDict):
    items: Annotated[list, merge_lists_unique]
```

### Reducer with Type Handling

```python
def flexible_append(left: list, right) -> list:
    """Append single item or extend with list."""
    if isinstance(right, list):
        return left + right
    return left + [right]

class State(TypedDict):
    logs: Annotated[list, flexible_append]
```

### Conditional Reducer

```python
def max_value(left: int, right: int) -> int:
    """Keep the maximum value."""
    return max(left, right)

class State(TypedDict):
    high_score: Annotated[int, max_value]
```

### Dictionary Merger

```python
def deep_merge(left: dict, right: dict) -> dict:
    """Deep merge dictionaries."""
    result = left.copy()
    for key, value in right.items():
        if key in result and isinstance(result[key], dict) and isinstance(value, dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = value
    return result

class State(TypedDict):
    config: Annotated[dict, deep_merge]
```

---

## State Channels

Channels allow nodes to write to keys beyond their input schema.

### Channel Communication

```python
class PublicState(TypedDict):
    query: str
    response: str

class InternalState(TypedDict):
    query: str
    response: str
    internal_cache: dict  # Only accessible internally

graph = StateGraph(InternalState, input=PublicState, output=PublicState)

def cache_node(state):
    # Can write to internal_cache even though it's not in input
    return {"internal_cache": {"data": "cached"}}
```

---

## Private State

Keep internal data separate from public interface.

### Input/Output Schemas

```python
class InputSchema(TypedDict):
    user_query: str

class OutputSchema(TypedDict):
    final_response: str

class FullState(TypedDict):
    user_query: str
    final_response: str
    # Private fields
    intermediate_results: list
    processing_metadata: dict
    retry_count: int

graph = StateGraph(
    FullState,
    input=InputSchema,
    output=OutputSchema
)

# When invoking:
# - Only user_query accepted as input
# - Only final_response returned as output
# - Internal fields managed by nodes
```

---

## State Best Practices

### 1. Use Reducers for Collections

```python
# Good: Explicit accumulation
items: Annotated[list, add]

# Bad: Ambiguous behavior
items: list  # Will overwrite, not append
```

### 2. Initialize State Properly

```python
# At invocation, provide initial values
result = app.invoke({
    "messages": [],  # Initialize empty list
    "context": "",   # Initialize empty string
    "count": 0       # Initialize counter
})
```

### 3. Type Everything

```python
from typing import TypedDict, Annotated, Optional
from langchain_core.messages import BaseMessage

class TypedState(TypedDict):
    messages: Annotated[list[BaseMessage], add_messages]
    context: Optional[str]
    metadata: dict[str, any]
```

### 4. Keep State Minimal

```python
# Good: Focused state
class FocusedState(TypedDict):
    messages: Annotated[list, add_messages]
    current_step: str

# Bad: Bloated state
class BloatedState(TypedDict):
    messages: list
    step1_result: str
    step2_result: str
    step3_result: str
    # ... many unused fields
```

### 5. Document State Fields

```python
class DocumentedState(TypedDict):
    """Agent state for customer support workflow."""

    messages: Annotated[list, add_messages]
    """Conversation history with customer."""

    customer_id: str
    """Unique identifier for the customer."""

    ticket_status: str
    """Current status: open, pending, resolved."""
```
