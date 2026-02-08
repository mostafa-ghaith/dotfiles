# Persistence and Checkpointing in LangGraph

## Table of Contents
- [Overview](#overview)
- [Checkpointer Types](#checkpointer-types)
- [InMemorySaver](#inmemorysaver)
- [PostgreSQL](#postgresql)
- [MongoDB](#mongodb)
- [Thread Management](#thread-management)
- [Memory Types](#memory-types)
- [TTL Configuration](#ttl-configuration)
- [Best Practices](#best-practices)

---

## Overview

Checkpointers persist graph state across interactions, enabling:
- **Conversation continuity**: Resume from where you left off
- **Human-in-the-loop**: Pause and resume for human input
- **Time travel**: Replay and fork from past states
- **Fault tolerance**: Recover from failures
- **Multi-turn interactions**: Maintain context across sessions

### Basic Setup

```python
from langgraph.graph import StateGraph

graph = StateGraph(MyState)
# ... add nodes and edges ...

# Compile with checkpointer
app = graph.compile(checkpointer=checkpointer)

# Use thread_id for conversation continuity
config = {"configurable": {"thread_id": "user-123"}}
result = app.invoke({"messages": []}, config=config)
```

---

## Checkpointer Types

| Checkpointer | Use Case | Persistence | Performance |
|--------------|----------|-------------|-------------|
| InMemorySaver | Dev/Testing | None (RAM) | Fastest |
| PostgresSaver | Production | Durable | Fast |
| AsyncPostgresSaver | Async Production | Durable | Fast |
| MongoDBSaver | Document-oriented | Durable | Fast |

---

## InMemorySaver

For development and testing only. Data is lost when process ends.

```python
from langgraph.checkpoint.memory import InMemorySaver

checkpointer = InMemorySaver()
app = graph.compile(checkpointer=checkpointer)
```

### Limitations
- No persistence across restarts
- Memory grows with conversation history
- Not suitable for production
- Single-process only

---

## PostgreSQL

Production-ready persistence with full durability.

### Installation

```bash
pip install langgraph-checkpoint-postgres
```

### Synchronous Setup

```python
from langgraph.checkpoint.postgres import PostgresSaver
import psycopg

# Connection string
DB_URI = "postgresql://user:password@localhost:5432/langgraph"

# Create connection with required settings
conn = psycopg.connect(
    DB_URI,
    autocommit=True,
    row_factory=psycopg.rows.dict_row
)

# Create checkpointer
checkpointer = PostgresSaver(conn)

# IMPORTANT: Run setup on first use
checkpointer.setup()

# Use in graph
app = graph.compile(checkpointer=checkpointer)
```

### Async Setup

```python
from langgraph.checkpoint.postgres import AsyncPostgresSaver
import psycopg

async def create_checkpointer():
    conn = await psycopg.AsyncConnection.connect(
        DB_URI,
        autocommit=True,
        row_factory=psycopg.rows.dict_row
    )
    checkpointer = AsyncPostgresSaver(conn)
    await checkpointer.setup()
    return checkpointer

# Usage
checkpointer = await create_checkpointer()
app = graph.compile(checkpointer=checkpointer)
```

### Connection Pool (Recommended for Production)

```python
from langgraph.checkpoint.postgres import AsyncPostgresSaver
from psycopg_pool import AsyncConnectionPool

async def create_pooled_checkpointer():
    pool = AsyncConnectionPool(
        DB_URI,
        min_size=5,
        max_size=20,
        kwargs={"autocommit": True, "row_factory": psycopg.rows.dict_row}
    )
    await pool.open()

    checkpointer = AsyncPostgresSaver(pool)
    await checkpointer.setup()
    return checkpointer
```

### PostgreSQL Schema

The checkpointer creates these tables:
- `checkpoints`: Stores state snapshots
- `checkpoint_blobs`: Stores large binary data
- `checkpoint_writes`: Stores pending writes

---

## MongoDB

Document-oriented persistence with flexible schemas.

### Installation

```bash
pip install langgraph-checkpoint-mongodb
```

### Setup

```python
from langgraph.checkpoint.mongodb import MongoDBSaver
from pymongo import MongoClient

# Create MongoDB connection
client = MongoClient("mongodb://localhost:27017")
db = client["langgraph"]

# Create checkpointer
checkpointer = MongoDBSaver(db)

# Use in graph
app = graph.compile(checkpointer=checkpointer)
```

### Async Setup

```python
from langgraph.checkpoint.mongodb import AsyncMongoDBSaver
from motor.motor_asyncio import AsyncIOMotorClient

async def create_mongo_checkpointer():
    client = AsyncIOMotorClient("mongodb://localhost:27017")
    db = client["langgraph"]
    return AsyncMongoDBSaver(db)
```

### MongoDB Collections

- `checkpoints`: State documents
- `checkpoint_writes`: Pending writes

### Document Size Limit

MongoDB has a 16MB document size limit. For larger states:
- Use PostgreSQL instead
- Reduce checkpoint size
- Store large data externally with references

---

## Thread Management

Threads isolate conversations and state.

### Thread Configuration

```python
# Each thread is an independent conversation
config = {"configurable": {"thread_id": "unique-thread-id"}}

# Different users get different threads
user_config = {"configurable": {"thread_id": f"user-{user_id}"}}

# Session-based threads
session_config = {"configurable": {"thread_id": f"session-{session_id}"}}
```

### Getting Thread State

```python
# Get current state
state = app.get_state(config)
print(state.values)  # Current state values
print(state.next)    # Next node(s) to execute

# Get state history
for state in app.get_state_history(config):
    print(f"Step: {state.metadata['step']}")
    print(f"Values: {state.values}")
```

### Updating Thread State

```python
# Update state externally
app.update_state(
    config,
    {"messages": [HumanMessage(content="Updated message")]},
    as_node="human_input"  # Attribute update to this node
)
```

---

## Memory Types

### Short-Term Memory (Thread-Scoped)

Maintained within a single thread/session:

```python
# Checkpointer handles short-term memory automatically
app = graph.compile(checkpointer=checkpointer)

# All invocations with same thread_id share state
config = {"configurable": {"thread_id": "session-123"}}
app.invoke({"messages": [msg1]}, config)  # First message
app.invoke({"messages": [msg2]}, config)  # Continues conversation
```

### Long-Term Memory (Cross-Thread)

Persist information across sessions using Store:

```python
from langgraph.store.memory import InMemoryStore
from langgraph.store.postgres import PostgresStore

# Create store for long-term memory
store = PostgresStore(conn)

# Compile with both checkpointer and store
app = graph.compile(
    checkpointer=checkpointer,
    store=store
)

# Access store in nodes
def node_with_memory(state, config, store):
    # Get user preferences from long-term memory
    user_id = config["configurable"]["user_id"]
    prefs = store.get(("users", user_id, "preferences"))

    # Update long-term memory
    store.put(("users", user_id, "last_seen"), datetime.now())

    return {"context": prefs}
```

---

## TTL Configuration

Automatic cleanup of old checkpoints.

### MongoDB TTL

```python
from langgraph.checkpoint.mongodb import MongoDBSaver

checkpointer = MongoDBSaver(
    db,
    ttl=timedelta(days=7)  # Auto-delete after 7 days
)
```

### PostgreSQL TTL

```python
from langgraph.checkpoint.postgres import PostgresSaver

checkpointer = PostgresSaver(
    conn,
    ttl=timedelta(hours=24)  # Keep for 24 hours
)
```

### Custom Cleanup

```python
async def cleanup_old_threads(checkpointer, max_age_days=30):
    """Remove threads older than max_age_days."""
    cutoff = datetime.now() - timedelta(days=max_age_days)

    # Implementation depends on checkpointer type
    if isinstance(checkpointer, PostgresSaver):
        await conn.execute(
            "DELETE FROM checkpoints WHERE created_at < %s",
            (cutoff,)
        )
```

---

## Best Practices

### 1. Use Appropriate Checkpointer

```python
# Development
checkpointer = InMemorySaver()

# Production
checkpointer = AsyncPostgresSaver(pool)
```

### 2. Configure Connection Pools

```python
# Don't create new connections per request
pool = AsyncConnectionPool(DB_URI, min_size=5, max_size=20)
checkpointer = AsyncPostgresSaver(pool)
```

### 3. Use Meaningful Thread IDs

```python
# Good: Descriptive, scoped
thread_id = f"user-{user_id}-session-{session_id}"

# Bad: Generic
thread_id = "thread1"
```

### 4. Handle Connection Errors

```python
from tenacity import retry, stop_after_attempt

@retry(stop=stop_after_attempt(3))
async def invoke_with_retry(app, input_data, config):
    try:
        return await app.ainvoke(input_data, config)
    except ConnectionError:
        # Reconnect and retry
        await reconnect_checkpointer()
        raise
```

### 5. Monitor Checkpoint Size

```python
def check_state_size(state):
    """Warn if state is getting too large."""
    import sys
    size = sys.getsizeof(state)
    if size > 1_000_000:  # 1MB
        logger.warning(f"Large state detected: {size} bytes")
```

### 6. Implement Graceful Shutdown

```python
async def shutdown():
    """Clean shutdown with pending writes flushed."""
    # Wait for pending operations
    await app.checkpointer.flush()

    # Close connections
    await pool.close()
```

### 7. Separate Read/Write Replicas

```python
# For high-traffic applications
write_pool = AsyncConnectionPool(PRIMARY_DB_URI)
read_pool = AsyncConnectionPool(REPLICA_DB_URI)

# Use write pool for checkpointer
checkpointer = AsyncPostgresSaver(write_pool)
```
