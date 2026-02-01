"""
Power Grid LLM - Backend API
FastAPI application for power grid data and LLM interactions

Uses OpenAI Agents SDK with MCP for tool integration.
"""

from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import os
import logging

from agents import Agent, Runner
from agents.mcp import MCPServerStreamableHttp
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Rate limiting configuration
# Uses X-Forwarded-For header when behind nginx proxy
limiter = Limiter(key_func=get_remote_address)

# Configuration
MCP_SERVER_URL = os.getenv("MCP_SERVER_URL", "http://mcp-server:8080/mcp")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

# System prompt for power grid assistant
SYSTEM_PROMPT = """You are a helpful assistant that provides information about the New England power grid.
You have access to real-time data from ISO New England through tools.

When users ask about the current power grid status, marginal fuel, or generation mix, use the available tools to get real-time data.

Be concise but informative. Explain technical terms when helpful."""


# Global MCP server reference (set during lifespan)
mcp_server = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Manage MCP server connection lifecycle.

    The MCP server connection is established at startup and maintained
    throughout the application lifecycle. The OpenAI Agents SDK handles
    all protocol details (initialization, session management, tool discovery).
    """
    global mcp_server

    logger.info(f"Connecting to MCP server at {MCP_SERVER_URL}")

    async with MCPServerStreamableHttp(
        name="PowerGrid MCP Server",
        params={
            "url": MCP_SERVER_URL,
            "timeout": 30,
        },
        cache_tools_list=True,
    ) as server:
        mcp_server = server
        logger.info("MCP server connected successfully")

        # List available tools for logging
        tools = await server.list_tools()
        tool_names = [t.name for t in tools]
        logger.info(f"Available MCP tools: {tool_names}")

        yield

    logger.info("MCP server disconnected")


app = FastAPI(
    title="Power Grid LLM API",
    description="API for power grid data and carbon-aware scheduling",
    version="0.2.0",
    lifespan=lifespan
)

# Register rate limiter
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS configuration
allowed_origins = os.getenv("ALLOWED_ORIGINS", "http://localhost:3001").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Request/Response models
class ChatMessage(BaseModel):
    role: str  # "user" or "assistant"
    content: str


class ChatRequest(BaseModel):
    message: str
    history: Optional[List[ChatMessage]] = []


class ChatResponse(BaseModel):
    response: str
    history: List[ChatMessage]


@app.get("/")
async def root():
    """Root endpoint - basic info"""
    return {
        "service": "Power Grid LLM API",
        "version": "0.2.0",
        "status": "running"
    }


@app.get("/api/health")
@limiter.limit("60/minute")
async def health_check(request: Request):
    """Health check endpoint for container orchestration"""
    return {
        "status": "healthy",
        "service": "power-grid-llm-backend",
        "mcp_connected": mcp_server is not None
    }


@app.get("/api/hello")
async def hello():
    """Hello world endpoint for testing"""
    return {
        "message": "Hello from Power Grid LLM!",
        "hint": "When is the best time to do laundry?"
    }


@app.post("/api/chat", response_model=ChatResponse)
@limiter.limit("10/minute")
async def chat(request: Request, chat_request: ChatRequest):
    """
    Chat endpoint using OpenAI Agents SDK with MCP tools.

    The Agent SDK handles:
    - Sending messages to OpenAI
    - Tool discovery from MCP server
    - Tool call execution via MCP
    - Multi-turn conversation loop
    """
    if not OPENAI_API_KEY:
        raise HTTPException(status_code=500, detail="OPENAI_API_KEY not configured")

    if mcp_server is None:
        raise HTTPException(status_code=503, detail="MCP server not connected")

    # Build conversation input from history
    conversation_input = ""
    for msg in chat_request.history:
        if msg.role == "user":
            conversation_input += f"User: {msg.content}\n"
        else:
            conversation_input += f"Assistant: {msg.content}\n"

    # Add the new user message
    conversation_input += f"User: {chat_request.message}"

    logger.info(f"Processing chat request with {len(chat_request.history)} history messages")

    # Create agent with MCP server tools
    agent = Agent(
        name="PowerGridAssistant",
        instructions=SYSTEM_PROMPT,
        mcp_servers=[mcp_server],
        model="gpt-4o",
    )

    # Run the agent
    try:
        result = await Runner.run(agent, conversation_input)
        final_text = result.final_output
        logger.info("Agent completed successfully")
    except Exception as e:
        logger.error(f"Agent execution failed: {e}")
        raise HTTPException(status_code=500, detail=f"Chat processing failed: {str(e)}")

    # Build updated history
    updated_history = list(chat_request.history)
    updated_history.append(ChatMessage(role="user", content=chat_request.message))
    updated_history.append(ChatMessage(role="assistant", content=final_text))

    return ChatResponse(response=final_text, history=updated_history)
