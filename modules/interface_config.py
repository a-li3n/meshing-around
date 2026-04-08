DEFAULT_TCP_PORT = 4403


def parse_tcp_interface_target(target, default_port=DEFAULT_TCP_PORT):
    """Return (hostname, port) for tcp interface config values."""
    value = (target or "").strip()
    if not value:
        return "", default_port

    if value.startswith("[") and "]" in value:
        host, _, remainder = value[1:].partition("]")
        if remainder.startswith(":") and remainder[1:].isdigit():
            return host, int(remainder[1:])
        return value, default_port

    if value.count(":") == 1:
        host, port = value.rsplit(":", 1)
        if port.isdigit():
            return host, int(port)

    return value, default_port
