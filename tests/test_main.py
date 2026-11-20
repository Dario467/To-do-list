from fastapi.testclient import TestClient

import main

client = TestClient(main.app)


def test_version(monkeypatch):
    monkeypatch.setenv("APP_VERSION", "v9.9.9")
    r = client.get("/version")
    assert r.status_code == 200
    assert r.json() == {"version": "v9.9.9"}


def test_list_tasks(monkeypatch):
    monkeypatch.setattr(
        main, "fetch_tasks", lambda: [{"id": 1, "title": "a", "done": False}]
    )
    r = client.get("/tasks")
    assert r.status_code == 200
    assert r.json()[0]["title"] == "a"


def test_create_task(monkeypatch):
    monkeypatch.setattr(
        main, "insert_task", lambda title, done: {"id": 1, "title": title, "done": done}
    )
    r = client.post("/tasks", json={"title": "estudiar", "done": False})
    assert r.status_code == 201
    assert r.json()["title"] == "estudiar"


def test_create_task_without_title_is_rejected():
    r = client.post("/tasks", json={"done": False})
    assert r.status_code == 422


def test_health_ok(monkeypatch):
    monkeypatch.setattr(main, "check_db", lambda: True)
    r = client.get("/health")
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "OK"
    assert "version" in body and "timestamp" in body


def test_health_fail(monkeypatch):
    monkeypatch.setattr(main, "check_db", lambda: False)
    r = client.get("/health")
    assert r.status_code == 503
    assert r.json()["status"] == "FAIL"
