# Custom Tools in LangGraph

## Table of Contents
- [Creating Tools](#creating-tools)
- [ToolNode](#toolnode)
- [State Injection](#state-injection)
- [State Updates from Tools](#state-updates-from-tools)
- [Tool Artifacts](#tool-artifacts)
- [Error Handling](#error-handling)
- [Advanced Patterns](#advanced-patterns)

---

## Creating Tools

Tools are functions that agents can call to interact with external systems.

### Using @tool Decorator

```python
from langchain_core.tools import tool

@tool
def search_database(query: str) -> str:
    """Search the database for relevant information.

    Args:
        query: The search query string.

    Returns:
        Search results as a string.
    """
    results = db.search(query)
    return f"Found: {results}"
```

### Tool with Structured Input

```python
from langchain_core.tools import tool
from pydantic import BaseModel, Field

class SearchInput(BaseModel):
    query: str = Field(description="Search query")
    limit: int = Field(default=10, description="Max results")
    category: str = Field(default="all", description="Filter category")

@tool(args_schema=SearchInput)
def advanced_search(query: str, limit: int, category: str) -> str:
    """Perform advanced search with filters."""
    return search_service.query(query, limit=limit, category=category)
```

### Async Tools

```python
@tool
async def fetch_data(url: str) -> str:
    """Fetch data from URL asynchronously."""
    async with aiohttp.ClientSession() as session:
        async with session.get(url) as response:
            return await response.text()
```

### Tool with Return Artifacts

```python
@tool(response_format="content_and_artifact")
def generate_chart(data: list) -> tuple[str, bytes]:
    """Generate a chart from data.

    Returns:
        Tuple of (description, chart_image_bytes)
    """
    chart = create_chart(data)
    return "Chart generated successfully", chart.to_bytes()
```

---

## ToolNode

ToolNode executes tools requested in AIMessage tool calls.

### Basic Usage

```python
from langgraph.prebuilt import ToolNode, tools_condition

# Define tools
tools = [search_database, fetch_data, generate_chart]

# Create ToolNode
tool_node = ToolNode(tools)

# Add to graph
graph.add_node("tools", tool_node)
graph.add_conditional_edges(
    "agent",
    tools_condition,
    {"tools": "tools", "__end__": END}
)
graph.add_edge("tools", "agent")
```

### ToolNode Features

- **Parallel execution**: Multiple tool calls run concurrently
- **Error handling**: Configurable error responses
- **State injection**: Tools can access graph state
- **Store injection**: Tools can access persistent storage

### Custom ToolNode

```python
def custom_tool_node(state):
    """Custom tool execution with state updates."""
    messages = state["messages"]
    last_message = messages[-1]

    results = []
    for tool_call in last_message.tool_calls:
        tool = tool_map[tool_call["name"]]
        result = tool.invoke(tool_call["args"])
        results.append(
            ToolMessage(
                content=str(result),
                tool_call_id=tool_call["id"]
            )
        )

    # Can update additional state keys
    return {
        "messages": results,
        "tool_call_count": state.get("tool_call_count", 0) + len(results)
    }
```

---

## State Injection

Tools can access graph state using InjectedState.

### Basic State Access

```python
from langgraph.prebuilt import InjectedState
from typing import Annotated

@tool
def context_aware_search(
    query: str,
    state: Annotated[dict, InjectedState]
) -> str:
    """Search using context from state."""
    context = state.get("context", "")
    user_id = state.get("user_id", "anonymous")

    return search_with_context(query, context, user_id)
```

### Typed State Injection

```python
from langgraph.prebuilt import InjectedState

@tool
def get_user_info(
    state: Annotated[AgentState, InjectedState]
) -> str:
    """Get information about current user."""
    return f"User: {state['user_id']}, Session: {state['session_id']}"
```

### Partial State Injection

```python
from langgraph.prebuilt import InjectedState

@tool
def check_permissions(
    action: str,
    state: Annotated[dict, InjectedState(keys=["user_role", "permissions"])]
) -> bool:
    """Check if action is permitted."""
    role = state["user_role"]
    perms = state["permissions"]
    return action in perms.get(role, [])
```

---

## State Updates from Tools

Tools can update graph state using Command.

### Using Command for State Updates

```python
from langgraph.types import Command
from langgraph.prebuilt import InjectedState
from typing import Annotated

@tool
def update_context(
    new_context: str,
    state: Annotated[dict, InjectedState]
) -> Command:
    """Update the context in graph state."""
    return Command(
        update={"context": new_context},
        # Optionally route to specific node
        goto="process_context"
    )
```

### State Update with Response

```python
@tool
def fetch_and_store(
    url: str,
    state: Annotated[dict, InjectedState]
) -> Command:
    """Fetch data and store in state."""
    data = requests.get(url).json()

    return Command(
        update={
            "fetched_data": data,
            "fetch_count": state.get("fetch_count", 0) + 1
        }
    )
```

### Conditional Routing from Tools

```python
@tool
def classify_and_route(
    text: str,
    state: Annotated[dict, InjectedState]
) -> Command:
    """Classify text and route to appropriate handler."""
    category = classifier.predict(text)

    route_map = {
        "urgent": "priority_handler",
        "question": "qa_handler",
        "feedback": "feedback_handler"
    }

    return Command(
        update={"category": category},
        goto=route_map.get(category, "default_handler")
    )
```

---

## Tool Artifacts

Return additional data alongside tool responses.

### Content and Artifact Pattern

```python
@tool(response_format="content_and_artifact")
def generate_report(data: dict) -> tuple[str, dict]:
    """Generate a report with metadata artifact."""
    report = create_report(data)

    artifact = {
        "report_id": report.id,
        "generated_at": datetime.now().isoformat(),
        "word_count": len(report.content.split())
    }

    return report.summary, artifact
```

### Using Artifacts for State Updates

```python
def custom_tool_node(state):
    """Process tool calls and extract artifacts for state."""
    messages = state["messages"]
    artifacts = []

    for tool_call in messages[-1].tool_calls:
        tool = tool_map[tool_call["name"]]
        content, artifact = tool.invoke(tool_call["args"])

        if artifact:
            artifacts.append(artifact)

        messages.append(ToolMessage(content=content, tool_call_id=tool_call["id"]))

    return {
        "messages": messages,
        "artifacts": state.get("artifacts", []) + artifacts
    }
```

---

## Error Handling

Handle tool execution errors gracefully.

### ToolNode Error Handling

```python
from langgraph.prebuilt import ToolNode

# Default: Returns error as ToolMessage
tool_node = ToolNode(tools)

# Custom error handling
tool_node = ToolNode(
    tools,
    handle_tool_error=True  # Include error in response
)
```

### Custom Error Handler

```python
def safe_tool_node(state):
    """Execute tools with custom error handling."""
    messages = state["messages"]
    results = []

    for tool_call in messages[-1].tool_calls:
        try:
            tool = tool_map[tool_call["name"]]
            result = tool.invoke(tool_call["args"])
            content = str(result)
        except Exception as e:
            content = f"Error executing {tool_call['name']}: {str(e)}"
            # Log error, notify monitoring, etc.
            logger.error(f"Tool error: {e}", exc_info=True)

        results.append(
            ToolMessage(content=content, tool_call_id=tool_call["id"])
        )

    return {"messages": results}
```

### Retry Logic

```python
from tenacity import retry, stop_after_attempt, wait_exponential

@tool
@retry(stop=stop_after_attempt(3), wait=wait_exponential(min=1, max=10))
def reliable_api_call(endpoint: str) -> str:
    """Call API with automatic retry."""
    response = requests.get(endpoint, timeout=30)
    response.raise_for_status()
    return response.json()
```

---

## Advanced Patterns

### Dynamic Tool Selection

```python
def get_tools_for_context(state):
    """Return different tools based on state."""
    user_role = state.get("user_role", "basic")

    base_tools = [search, calculate]

    if user_role == "admin":
        return base_tools + [admin_tool, delete_tool]
    elif user_role == "analyst":
        return base_tools + [export_tool, visualize_tool]

    return base_tools
```

### Tool with Confirmation

```python
from langgraph.types import interrupt

@tool
def dangerous_action(
    action: str,
    state: Annotated[dict, InjectedState]
) -> str:
    """Perform action that requires confirmation."""
    # Interrupt for human approval
    approval = interrupt({
        "action": action,
        "question": f"Approve action: {action}?",
        "details": state.get("action_details", {})
    })

    if approval != "approved":
        return "Action cancelled by user"

    return perform_action(action)
```

### Streaming Tool Output

```python
from langgraph.types import StreamWriter

@tool
def stream_analysis(
    data: str,
    writer: Annotated[StreamWriter, InjectedState]
) -> str:
    """Analyze data with streaming progress."""
    steps = ["parsing", "analyzing", "summarizing"]

    for i, step in enumerate(steps):
        writer({"progress": f"{step}...", "percent": (i+1)/len(steps)*100})
        result = process_step(data, step)

    return result
```

### Tool Registry Pattern

```python
class ToolRegistry:
    """Central registry for tool management."""

    def __init__(self):
        self._tools = {}

    def register(self, name: str):
        def decorator(func):
            self._tools[name] = tool(func)
            return func
        return decorator

    def get(self, name: str):
        return self._tools.get(name)

    def all(self) -> list:
        return list(self._tools.values())

registry = ToolRegistry()

@registry.register("search")
def search_tool(query: str) -> str:
    """Search for information."""
    return search(query)

# Use in graph
tool_node = ToolNode(registry.all())
```
