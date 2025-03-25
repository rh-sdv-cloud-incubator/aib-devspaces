import sys
import time
import logging

from jumpstarter_driver_network.adapters import PexpectAdapter

logging.getLogger().setLevel(logging.INFO)
logger = logging.getLogger(__name__)

class ConsoleHelper:
    def __init__(self, console, expected_str=None, delay=0):
        self.console = console
        self.expected_str: str | None = expected_str
        self.delay = delay

    def send_command(self, cmd: str, expect_str=None, timeout: int = 30, delay: int = 0):
        self.console.sendline(cmd)
        time.sleep(delay or self.delay)

        if expect_str is None and self.expected_str:
            expect_str = self.expected_str

        if expect_str:
            self.console.expect(expect_str, timeout=timeout)
            if self.console.before is not None:
                return self.console.before.decode('utf-8')
        return ""

    def wait_for_pattern(self, pattern: str, timeout: int = 60):
        self.console.expect(pattern, timeout=timeout)
        return (self.console.before + self.console.after).decode('utf-8')


def setup_environment(client):
    gpio = client.power
    serial = client.serial
    print("Restarting the board")
    gpio.cycle()
    time.sleep(6)

    with PexpectAdapter(client=serial) as console:
        console.logfile = sys.stdout.buffer

        helper = ConsoleHelper(console)
        console.expect("login:", timeout=300)
        helper.send_command("root", expect_str="Password:", timeout=10)
        helper.send_command("password", expect_str="#", timeout=10)
    return client


def test_radio(test_environment, request):
    with PexpectAdapter(client=test_environment.serial) as console:
        console.logfile = sys.stdout.buffer

        helper = ConsoleHelper(console)

        try:
            helper.send_command("podman exec -it systemd-radio /radio-client")
            logger.info("within the sample apps container")
            logger.info("within the radio client")
            time.sleep(5) # sleep because the serial console flakiness
            helper.send_command("+")
            logger.info("vol up")
            helper.send_command("+")
            logger.info("vol up")
            helper.send_command("-")
            helper.send_command("-")
            helper.send_command("-")
            logger.info("vol down")
            helper.send_command(b"\x1B") # escape
            logger.info("pause radio")
            helper.send_command(b"\x1B") # escape
            logger.info("continue radio")
            helper.send_command("q")
            logger.info("exit client")
            time.sleep(5) # sleep because the serial console flakiness

            helper.send_command("podman logs systemd-radio") # service logs printed to stdout
            
            assert helper.wait_for_pattern("Activate connection type"), "Activation of the radio client failed"
            assert helper.wait_for_pattern("50% volume"), "Failed to get initial volume"
            assert helper.wait_for_pattern("60% volume"), "Failed to increase the volume"
            assert helper.wait_for_pattern("70% volume"), "Failed to increase the volume"
            assert helper.wait_for_pattern("40% volume"), "Failed to decrease the volume"
            assert helper.wait_for_pattern("RADIO: Paused playing"), "Failed to pause the radio"
            assert helper.wait_for_pattern("RADIO: Started playing"), "Failed to resume the radio"
            assert helper.wait_for_pattern("Deactivate connection type"), "Failed to exit the radio client"

        except Exception as e:
            print(f"Test failed: {e}")
            raise
