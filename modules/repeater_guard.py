REPEATER_MARKER = "[RPT]"


def is_repeater_forward(message_text):
    return REPEATER_MARKER in str(message_text or "")


def build_repeater_forward_message(message_text, sender_name):
    sender = str(sender_name or "unknown").strip() or "unknown"
    return f"{message_text} From:{sender} {REPEATER_MARKER}"
