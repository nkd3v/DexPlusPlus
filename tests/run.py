"""Run regression tests with the Luau CLI and compile every shipped script."""

import importlib.util
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def literal(source: str) -> str:
    delimiter = "="
    while f"]{delimiter}]" in source:
        delimiter += "="
    return f"[{delimiter}[\n{source}]{delimiter}]"


def main() -> None:
    spec = importlib.util.spec_from_file_location("dex_build", ROOT / "build.py")
    builder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(builder)
    first = builder.build().read_bytes()
    assert builder.build().read_bytes() == first, "Build must be deterministic"
    subprocess.run(
        ["luau-compile", "--null", str(ROOT / "out.lua"),
         *map(str, sorted((ROOT / "modules").glob("*.lua")))],
        check=True, stdout=subprocess.DEVNULL,
    )
    sources = {
        name: (ROOT / "modules" / f"{name}.lua").read_text(encoding="utf-8")
        for name in ("Explorer", "Properties", "Tags")
    }
    main_source = (ROOT / "main.lua").read_text(encoding="utf-8")
    sources["Cloneref"] = main_source.split("local isFsSupported", 1)[0] + "\nreturn cloneref"
    sources["Loader"] = (
        main_source.split("\tMain.LoadModule = function", 1)[1]
        .split("\tMain.LoadPluginFile = function", 1)[0]
    )
    sources["Loader"] = "Main.LoadModule = function" + sources["Loader"] + "\nreturn Main.LoadModule"
    script = "local sources = {\n" + "".join(
        f"{name} = {literal(source)},\n" for name, source in sources.items()
    ) + "}\n" + (ROOT / "tests" / "regression.luau").read_text(encoding="utf-8")
    with tempfile.TemporaryDirectory(prefix="dex-tests-") as directory:
        path = Path(directory) / "regression.luau"
        path.write_text(script, encoding="utf-8")
        subprocess.run(["luau", str(path)], check=True)
    print("Build is deterministic; all modules and out.lua compile.")


if __name__ == "__main__":
    main()
