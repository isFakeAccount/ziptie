import argparse
from pathlib import Path
from re import T
from ziptie.python_sysconf import handle_commands

parser = argparse.ArgumentParser()
sub = parser.add_subparsers(dest="command", required=True)

build_sp = sub.add_parser(
    "build",
    help="Build all C/C++/Zig extension modules in project.",
    formatter_class=argparse.ArgumentDefaultsHelpFormatter,
)
build_sp.add_argument(
    "-p",
    "--pyproject-path",
    default="pyproject.toml",
    help="Path for pyproject.toml",
    required=False,
)

sysconf_sp = sub.add_parser(name="python-sysconfig", help="Get Python system config info. Used by zigtie.build.zig.")
mut_ex_group = sysconf_sp.add_mutually_exclusive_group(required=True)
mut_ex_group.add_argument(
    "--ext-suffix",
    help="Get file extension suffix for a Python extension module based on the target platform",
    dest="ext_suffix",
)


def find_subdirectories_with_config(package_path: Path, ignore_dirs: list[str]) -> list[Path]:
    pass


def build_project(pyproject_path: Path):
    pass


def main() -> None:
    args = parser.parse_args()

    match args.command:
        case "build":
            build_project(Path(args.pyproject_path).resolve())
        case "python-sysconfig":
            handle_commands(args)
        case _:
            raise SystemExit("Unknown Command Passed", args)


if __name__ == "__main__":
    main()
