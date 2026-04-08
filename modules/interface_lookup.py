from modules.interface_config import parse_tcp_interface_target


def _get_interface_attr(interface, attr_name, default=None):
    value = getattr(interface, attr_name, default)
    if value is not default:
        return value
    return interface.__dict__.get(attr_name, default)


def build_interface_slots(config_source):
    """Build static interface slot metadata from module globals/config values."""
    return tuple(
        {
            "index": index,
            "type": config_source.get(f"interface{index}_type", ""),
            "tcp_target": config_source.get(f"hostname{index}", ""),
            "serial_port": config_source.get(f"port{index}", ""),
        }
        for index in range(1, 10)
    )


def resolve_rx_interface_index(
    interface,
    interface_map=None,
    interface_types=None,
    tcp_targets=None,
    serial_ports=None,
    interface_slots=None,
    interface_getter=None,
):
    """Resolve the configured interface slot for an incoming packet."""
    if interface_slots is None:
        indexes = set()
        if interface_map:
            indexes.update(interface_map.keys())
        if interface_types:
            indexes.update(interface_types.keys())
        if tcp_targets:
            indexes.update(tcp_targets.keys())
        if serial_ports:
            indexes.update(serial_ports.keys())
        interface_slots = tuple(
            {
                "index": index,
                "type": (interface_types or {}).get(index, ""),
                "tcp_target": (tcp_targets or {}).get(index, ""),
                "serial_port": (serial_ports or {}).get(index, ""),
            }
            for index in sorted(indexes)
        )

    def get_configured_interface(index):
        if interface_getter is not None:
            return interface_getter(index)
        return (interface_map or {}).get(index)

    for slot in interface_slots:
        index = slot["index"]
        configured_interface = get_configured_interface(index)
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

        for slot in interface_slots:
            index = slot["index"]
            configured_type = slot.get("type", "")
            if configured_type != "tcp":
                continue

            host, port = parse_tcp_interface_target(slot.get("tcp_target"))
            if not host:
                continue

            if rx_host == host and (rx_port is None or rx_port == port):
                return index

            if rx_host and host and host in rx_host and (rx_port is None or rx_port == port):
                return index

    if interface_type == "SerialInterface":
        rx_path = str(_get_interface_attr(interface, "devPath", "") or "")
        for slot in interface_slots:
            index = slot["index"]
            configured_type = slot.get("type", "")
            configured_port = str(slot.get("serial_port", "") or "")
            if configured_type == "serial" and configured_port and configured_port in rx_path:
                return index

    if interface_type == "BLEInterface":
        for slot in interface_slots:
            index = slot["index"]
            configured_type = slot.get("type", "")
            if configured_type == "ble":
                return index

    return None
