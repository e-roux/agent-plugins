import pytest
from pathlib import Path

def pytest_collection_modifyitems(items):
    """
    Dynamically add markers based on test location:
    - test/e2e/ -> @pytest.mark.e2e
    - test/benchmark/ -> @pytest.mark.benchmark
    - test/integration/ -> @pytest.mark.integration
    """
    for item in items:
        path = Path(item.fspath)
        
        if "test/e2e" in str(path):
            item.add_marker(pytest.mark.e2e)
        elif "test/benchmark" in str(path):
            item.add_marker(pytest.mark.benchmark)
        elif "test/integration" in str(path):
            item.add_marker(pytest.mark.integration)
