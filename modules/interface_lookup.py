from modules.interface_config import parse_tcp_interface_target


def _get_interface_attr(interface, attr_name, default=None):
    value = getattr(interface, attr_name, default)
    if value is not default:
        return value
    return interface.__dict__.get(attr_name, default)


def resolve_rx_interface_index(
    interface,
    interface_map,
    interface_types,
    tcp_targets=None,
    serial_ports=None,
):
    """Resolve the configured interface slot for an incoming packet."""
    for index, configured_interface in interface_map.items():
        if configured_interface is interface:
            return index

    if interface is None:
        return None

    interface_type = interface.__class__.__name__

    if interface_type == "TCPInterface":
        rx_host = str(_get_interface_attr(interface, "hostname", "") or "").strip()
        rx_port = _get_interface_attr(interface, "portNumber")
        if isinstance(rx_port, str) and rx_port.isdigit():
            rx_port = int(rx_port)

        for index, configured_type in interface_types.items():
            if configured_type != "tcp":
                continue

            host, port = parse_tcp_interface_target((tcp_targets or {}).get(index))
            if not host:
                continue

            if rx_host == host and (rx_port is None or rx_port == port):
                return index

            if rx_host and host and host in rx_host and (rx_port is None or rx_port == port):
                return index

    if interface_type == "SerialInterface":
        rx_path = str(_get_interface_attr(interface, "devPath", "") or "")
        for index, configured_type in interface_types.items():
            configured_port = str((serial_ports or {}).get(index, "") or "")
            if configured_type == "serial" and configured_port and configured_port in rx_path:
                return index

    if interface_type == "BLEInterface":
        for index, configured_type in interface_types.items():
            if configured_type == "ble":
                return index

    return None
