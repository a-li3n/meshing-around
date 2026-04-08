import copy
import pickle


RECOVERABLE_PICKLE_EXCEPTIONS = (
    FileNotFoundError,
    EOFError,
    pickle.UnpicklingError,
    AttributeError,
    ValueError,
    OSError,
)


def _materialize_default(default_factory_or_value):
    if callable(default_factory_or_value):
        return default_factory_or_value()
    return copy.deepcopy(default_factory_or_value)


def save_pickle_store(path, value):
    with open(path, "wb") as handle:
        pickle.dump(value, handle)


def load_pickle_store(path, default_factory_or_value, logger, label):
    try:
        with open(path, "rb") as handle:
            return pickle.load(handle)
    except FileNotFoundError:
        value = _materialize_default(default_factory_or_value)
        logger.warning(f"System: {label} not found, creating a new one")
        try:
            save_pickle_store(path, value)
        except OSError as error:
            logger.error(f"System: Error creating {label}: {error}")
        return value
    except RECOVERABLE_PICKLE_EXCEPTIONS[1:] as error:
        logger.error(f"System: Error loading {label}: {error}")
        return _materialize_default(default_factory_or_value)
