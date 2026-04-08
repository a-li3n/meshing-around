import unittest

from modules.interface_debug import describe_configured_interface


class TCPInterface:
    def __init__(self, hostname, port_number, nodes=None):
        self.hostname = hostname
        self.portNumber = port_number
        self.nodes = nodes or {}


class InterfaceDebugTest(unittest.TestCase):
    def test_describe_configured_interface_for_tcp_includes_recovery_context(self):
        interface = TCPInterface("127.0.0.1", 4403, nodes={"!abc": {}})

        description = describe_configured_interface(
            1,
            interface,
            configured_type="tcp",
            config_target="127.0.0.1:4403",
            retry_pending=True,
            retries_left=2,
        )

        self.assertIn("interface1", description)
        self.assertIn("configured_type=tcp", description)
        self.assertIn("endpoint=127.0.0.1:4403", description)
        self.assertIn("config_target='127.0.0.1:4403'", description)
        self.assertIn("retry_pending=True", description)
        self.assertIn("retries_left=2", description)
        self.assertIn("nodes=1", description)

    def test_describe_configured_interface_for_missing_interface_reports_none(self):
        description = describe_configured_interface(
            1,
            None,
            configured_type="tcp",
            config_target="127.0.0.1:4403",
            retry_pending=False,
            retries_left=3,
        )

        self.assertIn("interface1", description)
        self.assertIn("class=None", description)
        self.assertIn("endpoint=None", description)
        self.assertIn("nodes=0", description)


if __name__ == "__main__":
    unittest.main()
