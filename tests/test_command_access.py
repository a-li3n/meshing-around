import unittest

from modules.command_access import check_admin_dm_access, normalize_admin_ids


class CommandAccessTest(unittest.TestCase):
    def test_normalize_admin_ids_filters_empty_values(self):
        self.assertEqual(normalize_admin_ids(["", "  ", "123", 456]), {"123", "456"})

    def test_check_admin_dm_access_denies_when_admin_list_empty(self):
        allowed, reason = check_admin_dm_access([""], 123, True)

        self.assertFalse(allowed)
        self.assertEqual(reason, "admin_required")

    def test_check_admin_dm_access_denies_when_not_dm(self):
        allowed, reason = check_admin_dm_access(["123"], 123, False)

        self.assertFalse(allowed)
        self.assertEqual(reason, "dm_required")

    def test_check_admin_dm_access_allows_configured_admin_in_dm(self):
        allowed, reason = check_admin_dm_access(["123"], 123, True)

        self.assertTrue(allowed)
        self.assertIsNone(reason)


if __name__ == "__main__":
    unittest.main()
