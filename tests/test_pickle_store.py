import logging
import os
import tempfile
import unittest

from modules.pickle_store import load_pickle_store, save_pickle_store


class PickleStoreTest(unittest.TestCase):
    def test_load_pickle_store_creates_missing_file_with_default(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            path = os.path.join(temp_dir, "email.pkl")

            value = load_pickle_store(path, dict, logging.getLogger("pickle-test"), "email db")

            self.assertEqual(value, {})
            self.assertTrue(os.path.exists(path))

    def test_load_pickle_store_returns_default_for_corrupt_file_without_overwriting(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            path = os.path.join(temp_dir, "email.pkl")
            with open(path, "wb") as handle:
                handle.write(b"not-a-pickle")

            value = load_pickle_store(path, dict, logging.getLogger("pickle-test"), "email db")

            self.assertEqual(value, {})
            with open(path, "rb") as handle:
                self.assertEqual(handle.read(), b"not-a-pickle")

    def test_save_pickle_store_writes_round_trippable_value(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            path = os.path.join(temp_dir, "email.pkl")
            payload = {"a": 1}

            save_pickle_store(path, payload)
            value = load_pickle_store(path, dict, logging.getLogger("pickle-test"), "email db")

            self.assertEqual(value, payload)


if __name__ == "__main__":
    unittest.main()
