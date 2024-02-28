import argparse
from pathlib import Path

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


def find_subdirectories_with_config(package_path: Path, ignore_dirs: list[str]) -> list[Path]:
    pass


def build_project(pyproject_path: Path):
    pass


def main() -> None:
    args = parser.parse_args()

    match args.command:
        case "build":
            build_project(Path(args.pyproject_path).resolve())
        case _:
            raise SystemExit("Unknown Command Passed")


if __name__ == "__main__":
    main()
