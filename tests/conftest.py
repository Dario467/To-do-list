import pytest
import src.main as main


@pytest.fixture(autouse=True)
def no_cloudwatch(monkeypatch):
    monkeypatch.setattr(main, "put_metric", lambda *args, **kwargs: None)