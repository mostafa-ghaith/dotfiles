# Interrupts and Human-in-the-Loop in LangGraph

## Table of Contents
- [Overview](#overview)
- [Interrupt Function](#interrupt-function)
- [Static Interrupts](#static-interrupts)
- [Dynamic Interrupts](#dynamic-interrupts)
- [Command Object](#command-object)
- [Resuming Execution](#resuming-execution)
- [Common Patterns](#common-patterns)
- [Best Practices](#best-practices)

---

## Overview

Human-in-the-loop (HITL) enables human oversight and input during graph execution. LangGraph supports two approaches:

1. **Static Interrupts**: Predetermined breakpoints before/after specific nodes
2. **Dynamic Interrupts**: Runtime interrupts based on current state

### Requirements

A checkpointer is **required** for interrupts:

```python
from langgraph.checkpoint.memory import InMemorySaver

checkpointer = InMemorySaver()  # Use PostgresSaver in production
app = graph.compile(checkpointer=checkpointer)
```

---

## Interrupt Function

The `interrupt` function pauses execution and presents data to humans.

### Basic Usage

```python
from langgraph.types import interrupt

def approval_node(state):
    # Pause and present data to human
    response = interrupt({
        "question": "Do you approve this action?",
        "action": state["pending_action"],
        "context": state["context"]
    })

    # response contains human input after resume
    return {"approval": response}
```

### Interrupt with Options

```python
def choice_node(state):
    response = interrupt({
        "question": "Select processing mode:",
        "options": ["fast", "thorough", "custom"],
        "default": "fast",
        "data": state["preview"]
    })

    return {"mode": response}
```

---

## Static Interrupts

Configure breakpoints at compile time.

### Interrupt Before Node

```python
app = graph.compile(
    checkpointer=checkpointer,
    interrupt_before=["sensitive_action"]  # Pause before this node
)
```

### Interrupt After Node

```python
app = graph.compile(
    checkpointer=checkpointer,
    interrupt_after=["review_results"]  # Pause after this node
)
```

### Multiple Breakpoints

```python
app = graph.compile(
    checkpointer=checkpointer,
    interrupt_before=["delete_data", "send_email"],
    interrupt_after=["generate_report"]
)
```

### Checking Interrupted State

```python
# After invoke, check if interrupted
state = app.get_state(config)

if state.next:  # Has next nodes = interrupted
    print(f"Interrupted before: {state.next}")
    print(f"Current values: {state.values}")
```

---

## Dynamic Interrupts

Interrupt based on runtime conditions.

### Conditional Interrupt

```python
from langgraph.types import interrupt

def conditional_approval(state):
    # Only interrupt for high-value actions
    if state["action_value"] > 1000:
        approval = interrupt({
            "question": "High-value action requires approval",
            "value": state["action_value"],
            "action": state["action"]
        })

        if approval != "approved":
            return {"status": "cancelled"}

    return {"status": "approved"}
```

### Interrupt in Tool

```python
from langgraph.types import interrupt
from langchain_core.tools import tool

@tool
def dangerous_delete(item_id: str) -> str:
    """Delete an item (requires confirmation)."""
    confirmation = interrupt({
        "action": "delete",
        "item_id": item_id,
        "warning": "This action cannot be undone"
    })

    if confirmation == "confirm":
        delete_item(item_id)
        return f"Deleted {item_id}"

    return "Deletion cancelled"
```

---

## Command Object

Command combines state updates and routing decisions.

### Basic Command

```python
from langgraph.types import Command

def router_node(state):
    if state["needs_review"]:
        return Command(goto="review")
    return Command(goto="process")
```

### Command with State Update

```python
def update_and_route(state):
    return Command(
        update={"processed": True, "timestamp": datetime.now()},
        goto="next_node"
    )
```

### Command with Interrupt Resume

```python
def approval_handler(state):
    approval = interrupt({"question": "Approve?"})

    if approval == "yes":
        return Command(
            update={"approved": True},
            goto="execute"
        )
    else:
        return Command(
            update={"approved": False, "reason": approval},
            goto="cancel"
        )
```

### Command to Parent Graph

```python
from langgraph.types import Command

def subgraph_node(state):
    # Route to parent graph
    return Command(
        update={"result": state["computation"]},
        goto=Command.PARENT  # Special value for parent
    )
```

### Command with Send (Parallel Execution)

```python
from langgraph.types import Command, Send

def fan_out_node(state):
    items = state["items_to_process"]

    # Send to multiple parallel instances
    return [
        Send("processor", {"item": item, "index": i})
        for i, item in enumerate(items)
    ]
```

---

## Resuming Execution

After an interrupt, resume with human input.

### Basic Resume

```python
from langgraph.types import Command

# Initial invoke (will interrupt)
config = {"configurable": {"thread_id": "thread-1"}}
result = app.invoke({"messages": [query]}, config)

# Check if interrupted
state = app.get_state(config)
if state.next:
    print("Awaiting input...")

    # Resume with human response
    result = app.invoke(
        Command(resume="approved"),
        config
    )
```

### Resume with Complex Data

```python
# Resume with structured response
result = app.invoke(
    Command(resume={
        "decision": "modify",
        "changes": {"field": "new_value"},
        "notes": "Updated per user request"
    }),
    config
)
```

### Resume from Specific Checkpoint

```python
# Get checkpoint history
history = list(app.get_state_history(config))

# Find specific checkpoint
target_checkpoint = history[3]  # 4th checkpoint

# Resume from that point
result = app.invoke(
    Command(resume="proceed"),
    {**config, "configurable": {**config["configurable"],
     "checkpoint_id": target_checkpoint.config["configurable"]["checkpoint_id"]}}
)
```

---

## Common Patterns

### Approve/Reject Pattern

```python
def approval_flow(state):
    response = interrupt({
        "type": "approval",
        "data": state["pending_data"]
    })

    if response == "approve":
        return Command(update={"status": "approved"}, goto="execute")
    elif response == "reject":
        return Command(update={"status": "rejected"}, goto="notify_rejection")
    else:
        return Command(update={"status": "revision_requested", "feedback": response}, goto="revise")
```

### Edit State Pattern

```python
def edit_node(state):
    response = interrupt({
        "type": "edit",
        "current_value": state["draft"],
        "instructions": "Please review and edit the draft"
    })

    # response contains the edited content
    return {"draft": response, "edited": True}
```

### Multi-Step Review

```python
def multi_step_review(state):
    # Step 1: Initial review
    initial = interrupt({"step": 1, "data": state["initial_output"]})

    if initial != "proceed":
        return {"feedback": initial, "step": 1}

    # Step 2: Final approval
    final = interrupt({"step": 2, "data": state["final_output"]})

    return {"approved": final == "approve", "step": 2}
```

### Tool Call Review

```python
def review_tool_calls(state):
    last_message = state["messages"][-1]

    if hasattr(last_message, "tool_calls") and last_message.tool_calls:
        for tool_call in last_message.tool_calls:
            response = interrupt({
                "type": "tool_review",
                "tool": tool_call["name"],
                "args": tool_call["args"]
            })

            if response != "approve":
                return {"status": "tool_rejected", "reason": response}

    return {"status": "tools_approved"}
```

### Input Validation

```python
def validate_input(state):
    while True:
        response = interrupt({
            "type": "input",
            "prompt": state["input_prompt"],
            "validation": state.get("validation_rules", {})
        })

        if validate(response, state.get("validation_rules")):
            return {"user_input": response, "valid": True}

        # Invalid input, will interrupt again with error
        state = {**state, "error": "Invalid input, please try again"}
```

---

## Best Practices

### 1. Always Use Checkpointer

```python
# Required for any interrupt functionality
app = graph.compile(checkpointer=checkpointer)
```

### 2. Provide Clear Context in Interrupts

```python
# Good: Clear, actionable
response = interrupt({
    "question": "Approve sending email to 500 customers?",
    "details": {
        "subject": state["email_subject"],
        "recipient_count": 500,
        "preview": state["email_preview"][:200]
    },
    "options": ["approve", "edit", "cancel"]
})

# Bad: Vague
response = interrupt({"q": "ok?"})
```

### 3. Handle All Response Cases

```python
def robust_approval(state):
    response = interrupt({"question": "Proceed?"})

    # Handle various responses
    if response in ["yes", "approve", "proceed", True]:
        return Command(goto="execute")
    elif response in ["no", "reject", "cancel", False]:
        return Command(goto="cancel")
    else:
        # Treat as feedback/revision request
        return Command(
            update={"feedback": response},
            goto="revise"
        )
```

### 4. Use Meaningful Thread IDs

```python
# Include context in thread ID
config = {
    "configurable": {
        "thread_id": f"approval-{workflow_id}-{user_id}"
    }
}
```

### 5. Implement Timeout Handling

```python
import asyncio

async def invoke_with_timeout(app, input_data, config, timeout=300):
    """Invoke with timeout for human response."""
    try:
        return await asyncio.wait_for(
            app.ainvoke(input_data, config),
            timeout=timeout
        )
    except asyncio.TimeoutError:
        # Handle timeout - maybe auto-reject or escalate
        return await app.ainvoke(
            Command(resume="timeout_auto_reject"),
            config
        )
```

### 6. Log Interrupt Events

```python
def logged_interrupt(data, logger):
    """Interrupt with logging."""
    logger.info(f"Interrupt requested: {data.get('type', 'unknown')}")

    response = interrupt(data)

    logger.info(f"Interrupt response received: {response}")
    return response
```
