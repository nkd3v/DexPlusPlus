"""Build the self-contained Dex++ script, independent of the working directory."""

from pathlib import Path
from typing import Optional


def build(root: Optional[Path] = None) -> Path:
    root = root or Path(__file__).resolve().parent
    chunks = [root.joinpath("header.lua").read_text(encoding="utf-8")]
    chunks.append("\n\nlocal EmbeddedModules = {\n")
    for path in sorted(root.joinpath("modules").glob("*.lua")):
        source = path.read_text(encoding="utf-8")
        chunks.append(f'["{path.stem}"] = function()\n{source}\nend,\n')
    chunks.extend(["}\n", root.joinpath("main.lua").read_text(encoding="utf-8")])
    output = root / "out.lua"
    with output.open("w", encoding="utf-8", newline="\n") as stream:
        stream.write("".join(chunks))
    return output


if __name__ == "__main__":
    print(f"Built {build()}")
