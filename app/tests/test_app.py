import pytest

from app import create_app


@pytest.fixture()
def client():
    return create_app().test_client()


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.get_json() == {"status": "ok"}


def test_version_present(client):
    assert "version" in client.get("/version").get_json()


def test_create_and_list_items(client):
    r = client.post("/api/items", json={"name": "widget"})
    assert r.status_code == 201
    names = [i["name"] for i in client.get("/api/items").get_json()["items"]]
    assert "widget" in names


@pytest.mark.parametrize("payload", [{}, {"name": ""}, {"name": "x" * 101}])
def test_rejects_bad_input(client, payload):
    assert client.post("/api/items", json=payload).status_code == 400


def test_metrics_exposed(client):
    client.get("/health")
    assert b"http_requests_total" in client.get("/metrics").data
