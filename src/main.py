import json
import os
from datetime import datetime, timezone

import boto3
import pymysql
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from pydantic import BaseModel

app = FastAPI(title="to-do-list-api")
_table_ready = False


class TaskIn(BaseModel):
    title: str
    done: bool = False


def get_credentials():
    client = boto3.client(
        "secretsmanager", region_name=os.getenv("AWS_REGION", "us-east-1")
    )
    secret = client.get_secret_value(SecretId=os.environ["SECRET_NAME"])
    return json.loads(secret["SecretString"])


def get_conn():
    global _table_ready
    c = get_credentials()
    conn = pymysql.connect(
        host=c["host"],
        user=c["username"],
        password=c["password"],
        database=c["dbname"],
        port=int(c["port"]),
        connect_timeout=5,
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=True,
    )
    if not _table_ready:
        with conn.cursor() as cur:
            cur.execute(
                "CREATE TABLE IF NOT EXISTS tasks ("
                "id INT AUTO_INCREMENT PRIMARY KEY, "
                "title VARCHAR(255) NOT NULL, "
                "done BOOLEAN NOT NULL DEFAULT FALSE)"
            )
        _table_ready = True
    return conn


def fetch_tasks():
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id, title, done FROM tasks ORDER BY id")
            return [
                {"id": r["id"], "title": r["title"], "done": bool(r["done"])}
                for r in cur.fetchall()
            ]
    finally:
        conn.close()


def insert_task(title, done):
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO tasks (title, done) VALUES (%s, %s)", (title, done)
            )
            return {"id": cur.lastrowid, "title": title, "done": done}
    finally:
        conn.close()


def check_db():
    try:
        conn = get_conn()
        try:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
            return True
        finally:
            conn.close()
    except Exception:
        return False


def app_version():
    return os.getenv("APP_VERSION", "unknown")


@app.get("/tasks")
def list_tasks():
    return fetch_tasks()


@app.post("/tasks", status_code=201)
def create_task(task: TaskIn):
    return insert_task(task.title, task.done)


@app.get("/version")
def version():
    return {"version": app_version()}


@app.get("/health")
def health():
    ok = check_db()
    body = {
        "status": "OK" if ok else "FAIL",
        "version": app_version(),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    return JSONResponse(content=body, status_code=200 if ok else 503)
