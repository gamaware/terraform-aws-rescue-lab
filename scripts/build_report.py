"""Build report/REPORT.pdf from report/REPORT.md with pandoc and Typst.

REPORT.md is the canonical deliverable; the PDF is generated from it and never
edited by hand. Relative links become links to the repository on GitHub, so
they still work when the PDF travels on its own.

    make report          # rebuild the PDF
    make report-check    # rebuild into a temp dir and compare (part of make verify)

Run through uv so the Typst compiler is pinned (see the Makefile). pandoc must
be the version in PANDOC_VERSION: another version renders slightly different
Typst, and the byte comparison would fail for that reason alone.
"""

from __future__ import annotations

import argparse
import pathlib
import re
import subprocess
import sys
import tempfile

import typst

PANDOC_VERSION = "3.11"
REPO_URL = "https://github.com/gamaware/terraform-aws-rescue-lab/blob/main"
ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "report" / "REPORT.md"
TEMPLATE = ROOT / "report" / "template.typ"
OUTPUT = ROOT / "report" / "REPORT.pdf"

# Markdown link targets that are relative paths, e.g. ](../after/) or ](../docs/adr/0001-x.md#a)
RELATIVE_LINK = re.compile(r"\]\((?!https?://|#|mailto:)([^)\s]+)\)")


def absolutize(markdown: str) -> str:
    def repl(match: re.Match[str]) -> str:
        target = (SOURCE.parent / match.group(1)).resolve()
        path, _, anchor = str(target.relative_to(ROOT)).partition("#")
        return f"]({REPO_URL}/{path}{'#' + anchor if anchor else ''})"

    return RELATIVE_LINK.sub(repl, markdown)


def pandoc_version() -> str:
    out = subprocess.run(["pandoc", "--version"], check=True, capture_output=True, text=True).stdout
    return out.splitlines()[0].split()[-1]


def build(output: pathlib.Path) -> None:
    markdown = SOURCE.read_text(encoding="utf-8")
    title = markdown.splitlines()[0].removeprefix("# ").strip()
    with tempfile.TemporaryDirectory() as tmp:
        source = pathlib.Path(tmp, "REPORT.md")
        source.write_text(absolutize(markdown), encoding="utf-8")
        typ = pathlib.Path(tmp, "REPORT.typ")
        subprocess.run(
            [
                "pandoc", str(source), "--from=gfm", "--to=typst", "--standalone",
                f"--template={TEMPLATE}", f"--metadata=title:{title}", f"--output={typ}",
            ],
            check=True,
        )
        typst.compile(str(typ), output=str(output), ignore_system_fonts=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="fail if report/REPORT.pdf is out of date")
    args = parser.parse_args()

    version = pandoc_version()
    if version != PANDOC_VERSION:
        print(f"error: pandoc {PANDOC_VERSION} required, found {version}", file=sys.stderr)
        return 2

    if not args.check:
        build(OUTPUT)
        print(f"wrote {OUTPUT.relative_to(ROOT)}")
        return 0

    with tempfile.TemporaryDirectory() as tmp:
        fresh = pathlib.Path(tmp, "REPORT.pdf")
        build(fresh)
        if not OUTPUT.exists() or OUTPUT.read_bytes() != fresh.read_bytes():
            print("FAIL  report/REPORT.pdf is out of date: run make report and commit it", file=sys.stderr)
            return 1
    print("pass  report/REPORT.pdf matches report/REPORT.md")
    return 0


if __name__ == "__main__":
    sys.exit(main())
