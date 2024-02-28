from argparse import Namespace
from sysconfig import get_config_var


def handle_commands(args: Namespace) -> None:
    if hasattr(args, "ext_suffix"):
        print(get_ext_suffix(args.ext_suffix), end="")


def get_ext_suffix(target_platform: str) -> str:
    """Get the appropriate file extension suffix for a Python extension module based on the target platform.

    Args:
        target_platform (str): The target platform string, indicating the operating system (e.g., 'linux', 'windows').

    Returns:
        str: The file extension suffix corresponding to the given target platform.
    """
    cpython_version = f"cpython-{get_config_var('py_version_nodot')}"
    if "linux" in target_platform:
        return f".{cpython_version}-{target_platform}.so"
    elif "windows" in target_platform:
        return f".{cpython_version}-{target_platform}.pyd"
    else:
        return f".{get_config_var('EXT_SUFFIX')}"
