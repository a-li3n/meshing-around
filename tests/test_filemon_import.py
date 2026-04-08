import os
import subprocess
import sys
import tempfile
import textwrap
import unittest


REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


class FilemonImportTest(unittest.TestCase):
    def test_filemon_imports_with_filemon_settings_present(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            os.makedirs(os.path.join(temp_dir, "logs"), exist_ok=True)
            os.makedirs(os.path.join(temp_dir, "data"), exist_ok=True)

            with open(os.path.join(temp_dir, "config.ini"), "w", encoding="utf-8") as config_file:
                config_file.write(
                    textwrap.dedent(
                        """\
                        [interface]
                        type = serial
                        port = /dev/null

                        [general]
                        respond_by_dm_only = True
                        defaultChannel = 0
                        zuluTime = False
                        SyslogToFile = False
                        LogMessagesToFile = False

                        [sentry]
                        SentryEnabled = False

                        [location]
                        enabled = False
                        lat = 0
                        lon = 0

                        [bbs]
                        enabled = False

                        [repeater]
                        enabled = False

                        [radioMon]
                        enabled = False

                        [games]
                        blackjack = False
                        videoPoker = False
                        lemonade = False
                        dopeWars = False
                        mastermind = False
                        golfSim = False
                        hangman = False
                        hamtest = False
                        tictactoe = False
                        quiz = False
                        survey = False
                        battleShip = False
                        wordOfTheDay = False

                        [messagingSettings]
                        responseDelay = 0.7
                        splitDelay = 0
                        MESSAGE_CHUNK_SIZE = 160

                        [fileMon]
                        filemon_enabled = False
                        enable_read_news = False
                        news_file_path = ../data/news.txt
                        news_random_line = False
                        news_block_mode = True
                        enable_runShellCmd = False
                        allowXcmd = False
                        twoFactor_enabled = True
                        twoFactor_timeout = 100

                        [scheduler]
                        enabled = False

                        [emergencyHandler]
                        enabled = False

                        [smtp]
                        enableSMTP = False
                        enableImap = False

                        [checklist]
                        enabled = False

                        [qrz]
                        enabled = False

                        [inventory]
                        enabled = False
                        """
                    )
                )

            process = subprocess.run(
                [sys.executable, "-c", "import modules.filemon"],
                cwd=temp_dir,
                env={**os.environ, "PYTHONPATH": REPO_ROOT},
                capture_output=True,
                text=True,
            )

            self.assertEqual(
                process.returncode,
                0,
                msg=f"stdout:\n{process.stdout}\nstderr:\n{process.stderr}",
            )


if __name__ == "__main__":
    unittest.main()
