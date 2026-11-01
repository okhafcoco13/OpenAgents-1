"""
Unit tests for structured error responses and error codes in OpenAgents API.
"""
import pytest
from fastapi.testclient import TestClient
import sys
import os

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from api.main import app

client = TestClient(app)

def test_not_found_error():
    response = client.get("/agents/nonexistent")
    assert response.status_code == 404
    data = response.json()
    assert data["code"] == "NOT_FOUND"
    assert "message" in data
    assert "request_id" in data

def test_validation_error():
    response = client.get("/agents?limit=invalid")
    assert response.status_code == 422
    data = response.json()
    assert data["code"] == "VALIDATION_ERROR"
    assert "details" in data
    assert "request_id" in data

def test_health_endpoint():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
