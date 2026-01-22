"""
Power Grid LLM - Backend API
FastAPI application for power grid data and LLM interactions
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import os

app = FastAPI(
    title="Power Grid LLM API",
    description="API for power grid data and carbon-aware scheduling",
    version="0.1.0"
)

# CORS configuration
allowed_origins = os.getenv("ALLOWED_ORIGINS", "http://localhost:3001").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
async def root():
    """Root endpoint - basic info"""
    return {
        "service": "Power Grid LLM API",
        "version": "0.1.0",
        "status": "running"
    }


@app.get("/api/health")
async def health_check():
    """Health check endpoint for container orchestration"""
    return {
        "status": "healthy",
        "service": "power-grid-llm-backend"
    }


@app.get("/api/hello")
async def hello():
    """Hello world endpoint for testing"""
    return {
        "message": "Hello from Power Grid LLM!",
        "hint": "When is the best time to do laundry?"
    }
