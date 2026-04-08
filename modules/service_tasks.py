import asyncio
import logging


logger = logging.getLogger("MeshBot Service Tasks")


def _task_name(task):
    return task.get_name() if hasattr(task, "get_name") else repr(task)


def raise_on_task_completion(task):
    """Raise if a background task fails or exits unexpectedly."""
    if task.cancelled():
        return

    task_name = _task_name(task)
    try:
        exc = task.exception()
    except asyncio.CancelledError:
        return

    if exc is not None:
        raise exc

    result = task.result()
    raise RuntimeError(f"Task {task_name} exited unexpectedly with result {result!r}")


async def run_service_tasks(tasks):
    """Wait for the first task failure or unexpected exit and surface it immediately."""
    if not tasks:
        return

    loop = asyncio.get_running_loop()
    first_failure = loop.create_future()

    def handle_task_done(task):
        if task.cancelled():
            return

        try:
            raise_on_task_completion(task)
        except asyncio.CancelledError:
            return
        except Exception as error:
            logger.error(
                f"Task {_task_name(task)} failed with: {error}",
                exc_info=(type(error), error, error.__traceback__),
            )
            if not first_failure.done():
                first_failure.set_exception(error)

    for task in tasks:
        task.add_done_callback(handle_task_done)

    try:
        await first_failure
    finally:
        for task in tasks:
            task.remove_done_callback(handle_task_done)
