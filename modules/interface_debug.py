def _get_interface_attr(interface, attr_name, default=None):
    if interface is None:
        return default

    value = getattr(interface, attr_name, default)
    if value is not default:
        return value

    return interface.__dict__.get(attr_name, default)


def describe_interface(interface):
    """Return a compact description of a live interface object."""
    if interface is None:
        return "class=None object_id=None endpoint=None nodes=0"

    class_name = interface.__class__.__name__
    object_id = hex(id(interface))
    endpoint = None

    if class_name == "TCPInterface":
        hostname = _get_interface_attr(interface, "hostname")
        port_number = _get_interface_attr(interface, "portNumber")
        endpoint = f"{hostname}:{port_number}" if hostname and port_number is not None else hostname
    elif class_name == "SerialInterface":
        endpoint = _get_interface_attr(interface, "devPath")
    elif class_name == "BLEInterface":
        endpoint = (
            _get_interface_attr(interface, "macAddress")
            or _get_interface_attr(interface, "address")
            or _get_interface_attr(interface, "mac")
        )

    nodes = _get_interface_attr(interface, "nodes", {})
    node_count = len(nodes) if isinstance(nodes, dict) else 0

    return (
        f"class={class_name} object_id={object_id} "
        f"endpoint={endpoint if endpoint is not None else 'None'} nodes={node_count}"
    )


def describe_configured_interface(
    index,
    interface,
    configured_type="",
    config_target=None,
    retry_pending=None,
    retries_left=None,
):
    """Return a compact configured-slot snapshot for recovery logging."""
    parts = [f"interface{index}", describe_interface(interface), f"configured_type={configured_type or 'unknown'}"]

    if config_target is not None:
        parts.append(f"config_target={config_target!r}")
    if retry_pending is not None:
        parts.append(f"retry_pending={retry_pending}")
    if retries_left is not None:
        parts.append(f"retries_left={retries_left}")

    return " ".join(parts)
