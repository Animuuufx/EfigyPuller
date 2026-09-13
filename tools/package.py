"""Build the installable archive using Python's standard library."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

root = Path(__file__).resolve().parents[1]
destination = root / "dist" / "EfigyPuller-v0.1.0.zip"
destination.parent.mkdir(parents=True, exist_ok=True)
files = sorted((root / "EfigyPuller").rglob("*"))
files += [root / name for name in ("README.md", "LICENSE", "VALIDATION.md")]
with ZipFile(destination, "w", ZIP_DEFLATED) as archive:
    for path in files:
        if path.is_file():
            archive.write(path, path.relative_to(root).as_posix())
with ZipFile(destination) as archive:
    assert archive.testzip() is None
    assert "EfigyPuller/enabled.txt" in archive.namelist()
    assert "EfigyPuller/Scripts/main.lua" in archive.namelist()
print(destination)
