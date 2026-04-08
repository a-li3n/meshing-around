import unittest

import modules.settings as settings


class SettingsAliasesTest(unittest.TestCase):
    def test_emergency_alert_compatibility_aliases_exist(self):
        self.assertTrue(hasattr(settings, "emergencyAlertBrodcastEnabled"))
        self.assertTrue(hasattr(settings, "emergencyAlertBroadcastCh"))
        self.assertEqual(settings.emergencyAlertBrodcastEnabled, settings.eAlertBroadcastEnabled)
        self.assertEqual(settings.emergencyAlertBroadcastCh, settings.eAlertBroadcastChannel)


if __name__ == "__main__":
    unittest.main()
