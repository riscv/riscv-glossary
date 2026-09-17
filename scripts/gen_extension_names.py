#!/usr/bin/env python3
"""Generate src/extensions.adoc from the RISC-V Unified Database.

Usage:
    gen_extension_names.py <path-to-riscv-unified-db> [output.adoc]

Reads the extension definitions under spec/std/isa/ext/*.yaml, keeps the
extensions that have at least one ratified version, and writes an AsciiDoc
table of their abbreviated name and long form. Writes to stdout when no
output file is given.
"""
import glob
import os
import sys

import yaml

HEADER = """[[extension-names]]
== RISC-V extension names

This chapter lists RISC-V ISA extension names in their abbreviated form alongside their long form. The list is derived from the https://github.com/riscv/riscv-unified-db[RISC-V Unified Database (UDB)] and covers the ratified standard extensions.

For the naming scheme these abbreviations follow, see Appendix C, ISA Extension Naming Conventions, in the Unprivileged ISA manual.

[cols="1,3",options="header",stripes=even]
|===
| Extension | Long form

"""


def is_ratified(ext):
    return any(v.get("state") == "ratified" for v in ext.get("versions") or [])


def main(argv):
    if len(argv) < 2:
        sys.exit("usage: gen_extension_names.py <path-to-riscv-unified-db> [output.adoc]")
    ext_dir = os.path.join(argv[1], "spec", "std", "isa", "ext")
    rows = []
    for path in glob.glob(os.path.join(ext_dir, "*.yaml")):
        with open(path) as f:
            ext = yaml.safe_load(f)
        if is_ratified(ext):
            rows.append((ext["name"], ext["long_name"]))
    rows.sort(key=lambda r: r[0])

    out = [HEADER]
    for name, long_name in rows:
        out.append("| {} | {}\n".format(name, long_name))
    out.append("|===\n")
    text = "".join(out)

    if len(argv) >= 3:
        with open(argv[2], "w") as f:
            f.write(text)
    else:
        sys.stdout.write(text)


if __name__ == "__main__":
    main(sys.argv)
