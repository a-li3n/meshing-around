import asyncio
import unittest

from modules.service_tasks import run_service_tasks


class ServiceTasksTest(unittest.IsolatedAsyncioTestCase):
    async def test_run_service_tasks_raises_first_task_exception(self):
        async def fails():
            raise ValueError("boom")

        async def waits_forever():
            await asyncio.Event().wait()

        tasks = [
            asyncio.create_task(waits_forever(), name="waiter"),
            asyncio.create_task(fails(), name="failing"),
        ]

        with self.assertRaisesRegex(ValueError, "boom"):
            await run_service_tasks(tasks)

        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)

    async def test_run_service_tasks_raises_when_task_exits_unexpectedly(self):
        async def exits_cleanly():
            return None

        tasks = [asyncio.create_task(exits_cleanly(), name="starter")]

        with self.assertRaisesRegex(RuntimeError, "exited unexpectedly"):
            await run_service_tasks(tasks)


if __name__ == "__main__":
    unittest.main()
