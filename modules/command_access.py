def normalize_admin_ids(admin_list):
    """Return configured admin IDs as normalized strings."""
    return {str(admin).strip() for admin in (admin_list or []) if str(admin).strip()}


def is_admin_sender(admin_list, sender_id):
    admin_ids = normalize_admin_ids(admin_list)
    return bool(admin_ids) and str(sender_id).strip() in admin_ids


def check_admin_dm_access(admin_list, sender_id, is_dm):
    """
    Validate privileged command access.

    Returns:
        (True, None) when access is allowed.
        (False, "dm_required") when the command must be sent via DM.
        (False, "admin_required") when the sender is not in the configured admin list.
    """
    if not is_dm:
        return False, "dm_required"
    if not is_admin_sender(admin_list, sender_id):
        return False, "admin_required"
    return True, None
