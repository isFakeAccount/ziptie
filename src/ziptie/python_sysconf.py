from ast import arg
import os
import sys
from argparse import Namespace
from platform import system
from sysconfig import get_config_var, get_path


def handle_commands(args: Namespace) -> None:
    if hasattr(args, "ext_suffix") and args.ext_suffix is not None:
        print(get_ext_suffix(args.ext_suffix), end="")
    elif hasattr(args, "include_dir") and args.include_dir:
        print(get_include_dir(), end="")
    elif hasattr(args, "lib_dir") and args.lib_dir:
        print(get_lib_dir(), end="")



def get_include_dir() -> str:
    """Get the Python include directory.

    Returns:
        str: The Python include directory path.
    """
    return get_path('include')
        

def get_lib_dir() -> str:
    """Get the Python lib directory based on os.

    Returns:
        str: Python lib directory path.
    """
    if system() == "Windows":
        return os.path.join(sys.prefix, "libs")
    else:
        return get_config_var('LIBDIR')


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
