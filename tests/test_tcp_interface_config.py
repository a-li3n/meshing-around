import unittest

from modules.interface_config import parse_tcp_interface_target


class TcpInterfaceConfigTest(unittest.TestCase):
    def test_parse_tcp_target_with_explicit_port(self):
        self.assertEqual(
            parse_tcp_interface_target("127.0.0.1:4444"),
            ("127.0.0.1", 4444),
        )

    def test_parse_tcp_target_without_port_uses_default(self):
        self.assertEqual(
            parse_tcp_interface_target("localhost"),
            ("localhost", 4403),
        )


if __name__ == "__main__":
    unittest.main()
