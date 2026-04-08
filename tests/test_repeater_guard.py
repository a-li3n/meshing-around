import unittest

from modules.repeater_guard import (
    REPEATER_MARKER,
    build_repeater_forward_message,
    is_repeater_forward,
)


class RepeaterGuardTest(unittest.TestCase):
    def test_build_repeater_forward_message_appends_sender_and_marker(self):
        forwarded = build_repeater_forward_message("hello world", "alice")

        self.assertEqual(forwarded, f"hello world From:alice {REPEATER_MARKER}")

    def test_is_repeater_forward_detects_marker(self):
        self.assertTrue(is_repeater_forward(f"hello {REPEATER_MARKER}"))
        self.assertFalse(is_repeater_forward("hello world"))


if __name__ == "__main__":
    unittest.main()
