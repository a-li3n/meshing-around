def schedule_interface_retry(disconnected_interface, interfaces, enabled, retry_flags):
    """Mark the matching enabled interface for reconnect and clear its slot."""
    for index, interface in interfaces.items():
        if interface is disconnected_interface and enabled.get(index, False):
            retry_flags[index] = True
            interfaces[index] = None
            return index
    return None
