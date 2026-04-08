import unittest

from modules.interface_recovery import schedule_interface_retry


class InterfaceRecoveryTest(unittest.TestCase):
    def test_schedule_interface_retry_marks_primary_interface_for_retry(self):
        primary = object()
        secondary = object()
        interfaces = {1: primary, 2: secondary}
        enabled = {1: True, 2: True}
        retry_flags = {1: False, 2: False}

        index = schedule_interface_retry(primary, interfaces, enabled, retry_flags)

        self.assertEqual(index, 1)
        self.assertIsNone(interfaces[1])
        self.assertTrue(retry_flags[1])
        self.assertIs(interfaces[2], secondary)
        self.assertFalse(retry_flags[2])

    def test_schedule_interface_retry_ignores_unknown_interface(self):
        primary = object()
        interfaces = {1: primary}
        enabled = {1: True}
        retry_flags = {1: False}

        index = schedule_interface_retry(object(), interfaces, enabled, retry_flags)

        self.assertIsNone(index)
        self.assertIs(interfaces[1], primary)
        self.assertFalse(retry_flags[1])


if __name__ == "__main__":
    unittest.main()
