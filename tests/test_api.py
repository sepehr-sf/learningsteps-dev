import asyncio
import os

import asyncpg
import pytest
from fastapi.testclient import TestClient

# Read the isolated test database URL before importing the application.
DATABASE_URL = os.environ["DATABASE_URL"]

# Import the FastAPI application after DATABASE_URL is available.
from main import app  # noqa: E402



# Prepare and clean the isolated PostgreSQL database for the test session.
@pytest.fixture(scope="session", autouse=True)
def prepare_test_database():

    # Create the test table and remove leftover data before testing.
    async def setup():
        conn = await asyncpg.connect(DATABASE_URL)
        try:
            await conn.execute("""
                CREATE TABLE IF NOT EXISTS entries (
                    id VARCHAR PRIMARY KEY,
                    data JSONB NOT NULL,
                    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
                    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
                );
            """)
            await conn.execute("DELETE FROM entries")
        finally:
            await conn.close()

    # Remove test data after the test session.
    async def cleanup():
        conn = await asyncpg.connect(DATABASE_URL)
        try:
            await conn.execute("DELETE FROM entries")
        finally:
            await conn.close()

    asyncio.run(setup())
    try:
        yield
    finally:
        asyncio.run(cleanup())


@pytest.fixture
def client():
    with TestClient(app) as test_client:
        yield test_client


def test_create_and_read_entry(client):
    payload = {
        "work": "Studied FastAPI integration testing",
        "struggle": "Understanding database connections",
        "intention": "Improve automated testing"
    }

    # Create
    response = client.post("/entries", json=payload)
    assert response.status_code == 200

    created = response.json()["entry"]
    entry_id = created["id"]

    assert created["work"] == payload["work"]

    # Read all
    response = client.get("/entries")
    assert response.status_code == 200
    assert response.json()["count"] >= 1

    # Read one
    response = client.get(f"/entries/{entry_id}")
    assert response.status_code == 200
    assert response.json()["id"] == entry_id

    # Update
    updated_payload = {
        "work": "Completed FastAPI integration tests",
        "struggle": "Understanding database connections",
        "intention": "Improve automated testing"
    }

    response = client.patch(
        f"/entries/{entry_id}",
        json=updated_payload
    )
    assert response.status_code == 200
    assert response.json()["work"] == updated_payload["work"]

    # Delete
    response = client.delete(f"/entries/{entry_id}")
    assert response.status_code == 200

    # Confirm deletion
    response = client.get(f"/entries/{entry_id}")
    assert response.status_code == 404


def test_create_entry_rejects_empty_fields(client):
    payload = {
        "work": "",
        "struggle": "A valid struggle",
        "intention": "A valid intention"
    }

    response = client.post("/entries", json=payload)

    assert response.status_code == 422


def test_create_entry_rejects_short_fields(client):
    payload = {
        "work": "ab",
        "struggle": "A valid struggle",
        "intention": "A valid intention"
    }

    response = client.post("/entries", json=payload)

    assert response.status_code == 422