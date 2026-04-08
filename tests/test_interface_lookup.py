import unittest

from modules.interface_lookup import resolve_rx_interface_index


class TCPInterface:
    def __init__(self, hostname, port_number):
        self.hostname = hostname
        self.portNumber = port_number


class InterfaceLookupTest(unittest.TestCase):
    def test_resolve_rx_interface_prefers_live_object_identity_for_tcp(self):
        primary = TCPInterface("127.0.0.1", 4403)
        secondary = TCPInterface("127.0.0.1", 4444)

        interface_index = resolve_rx_interface_index(
            secondary,
            interface_map={1: primary, 2: secondary},
            interface_types={1: "tcp", 2: "tcp"},
            tcp_targets={1: "127.0.0.1:4403", 2: "127.0.0.1:4444"},
        )

        self.assertEqual(interface_index, 2)

    def test_resolve_rx_interface_falls_back_to_host_and_port_for_tcp(self):
        incoming = TCPInterface("127.0.0.1", 4444)

        interface_index = resolve_rx_interface_index(
            incoming,
            interface_map={1: object(), 2: object()},
            interface_types={1: "tcp", 2: "tcp"},
            tcp_targets={1: "127.0.0.1:4403", 2: "127.0.0.1:4444"},
        )

        self.assertEqual(interface_index, 2)


if __name__ == "__main__":
    unittest.main()
