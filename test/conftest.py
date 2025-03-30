import pytest
import os
from pathlib import Path
from jumpstarter.config import ClientConfigV1Alpha1
from test_radio import setup_environment
import logging
import signal
from contextlib import contextmanager

logging.getLogger().setLevel(logging.INFO)
logger = logging.getLogger(__name__)

@contextmanager
def handle_interrupt():
    """Context manager to handle interrupts gracefully"""
    original_handler = signal.getsignal(signal.SIGINT)
    try:
        yield
    finally:
        signal.signal(signal.SIGINT, original_handler)

@pytest.fixture(scope="session")
def test_environment(request):
    config_name = request.config.getoption("--config")
    board_name = request.config.getoption("--board")

    if not config_name:
        pytest.fail("Config name must be specified with --config")

    config_file = Path(os.environ['HOME']) / '.config/jumpstarter/clients' / config_name
    client_config = ClientConfigV1Alpha1.from_file(str(config_file))
    lease = None
    client = None
    selector = None
    if board_name:
        selector = f"board={board_name}"

    with handle_interrupt():
        try:
            with client_config.lease(
                selector=selector,
                lease_name=None,
            ) as lease:
                with lease.connect() as client:
                    logger.info("Connected to client")
                    setup_environment(client)

                    def sigint_handler(signum, frame):
                        logger.info("Received interrupt signal")
                        raise KeyboardInterrupt

                    signal.signal(signal.SIGINT, sigint_handler)

                    yield client

        except KeyboardInterrupt:
            logger.info("Handling keyboard interrupt")
            raise
        except Exception as e:
            logger.error(f"Unexpected error: {e}")
            raise
        finally:
            logger.info("Cleanup complete")

def pytest_addoption(parser):
    parser.addoption(
        "--config",
        action="store",
        help="Path to jumpstarter config file",
        required=True
    )
    parser.addoption(
        "--board",
        action="store",
        help="Board to use",
        required=False
    )
