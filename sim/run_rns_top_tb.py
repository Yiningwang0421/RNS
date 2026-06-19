#!/usr/bin/env python3

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent

SOURCES = [
    "rtl/adder/mod63_add.sv",
    "rtl/adder/mod64_add.sv",
    "rtl/adder/mod65_add.sv",
    "rtl/adder/rns_add_63_64_65.sv",
    "rtl/substractor/mod63_sub.sv",
    "rtl/substractor/mod64_sub.sv",
    "rtl/substractor/mod65_sub.sv",
    "rtl/substractor/rns_sub_63_64_65.sv",
    "rtl/multiplication/csa/csa_circular.sv",
    "rtl/multiplication/csa/mod64/mod64_multiply.sv",
    "rtl/multiplication/mod63/mod63_add_final.sv",
    "rtl/multiplication/mod63/mod63_reduce_7bit .sv",
    "rtl/multiplication/mod63/mod63_multiply.sv",
    "rtl/multiplication/mod65/mod65_multiply.sv",
    "rtl/mod_section/mod_63_64_65_precompute.sv",
    "rtl/mod_section/mod_63_64_65_correct.sv",
    "rtl/mod_section/mod_63_64_65_pipe.sv",
    "rtl/convert_back/rns_63_64_65_to_binary_pipe.sv",
    "rtl/rns_top.sv",
    "sim/rns_golden_model.sv",
    "sim/rns_top_tb.sv",
]

SUMMARY_PATTERN = re.compile(
    r"^(\[config|\[scenario|\[drive|\[meaning|\[check|\[scoreboard|\[coverage|\[result\]|FAIL|PASS)"
)

HEADER_PATTERN = re.compile(
    r"^(\[result\]|\[scoreboard-summary\]|\[coverage\] TOTAL:|\[coverage\] PASS:|\[config\])"
)


def write_summary(summary_file: Path, full_log: str) -> None:
    detail_lines = [
        line for line in full_log.splitlines() if SUMMARY_PATTERN.match(line)
    ]
    header_lines = [line for line in detail_lines if HEADER_PATTERN.match(line)]

    dashboard = [
        "================ RNS TEST SUMMARY ================",
        *header_lines,
        "==================================================",
        "",
        "DETAILED SCOREBOARD AND STIMULUS",
        "",
        *detail_lines,
    ]
    summary_file.write_text("\n".join(dashboard) + "\n", encoding="utf-8")


def resolve_from_project(value: str) -> Path:
    path = Path(value).expanduser()
    return path.resolve() if path.is_absolute() else (PROJECT_ROOT / path).resolve()


def resolve_tool(explicit_path: str | None, command: str) -> str | None:
    if explicit_path:
        path = Path(explicit_path).expanduser().resolve()
        if not path.is_file():
            raise FileNotFoundError(f"{command} path '{path}' does not exist.")
        return str(path)

    path_from_environment = shutil.which(command)
    if path_from_environment:
        return path_from_environment

    windows_iverilog_path = Path("C:/iverilog/bin") / f"{command}.exe"
    if windows_iverilog_path.is_file():
        return str(windows_iverilog_path)

    return None


def run_and_capture(command: list[str], cwd: Path) -> tuple[int, str, str]:
    result = subprocess.run(
        command,
        cwd=cwd,
        text=True,
        capture_output=True,
        check=False,
    )
    return result.returncode, result.stdout, result.stderr


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Compile and run the rns_top SystemVerilog testbench."
    )
    parser.add_argument(
        "--output-dir",
        help="Directory for summary.log. Defaults to build/rns_top_tb.",
    )
    parser.add_argument("--iverilog", help="Explicit path to iverilog.")
    parser.add_argument("--vvp", help="Explicit path to vvp.")
    parser.add_argument(
        "--random-tests",
        type=int,
        default=500,
        help="Number of constrained-random transactions. Default: 500.",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=1592594996,
        help="Random seed used by the testbench. Default: 1592594996.",
    )
    parser.add_argument(
        "--no-prompt",
        action="store_true",
        help="Use the default output directory without prompting.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    default_build_dir = PROJECT_ROOT / "build"
    if not default_build_dir.exists():
        default_build_dir.mkdir(parents=True)

    output_dir_text = args.output_dir
    if output_dir_text is None and not args.no_prompt:
        output_dir_text = (
            input("Output directory [build/rns_top_tb]: ").strip()
            or "build/rns_top_tb"
        )
    output_dir = resolve_from_project(output_dir_text or "build/rns_top_tb")

    summary_file = output_dir / "summary.log"
    output_image = output_dir / "rns_top_tb.vvp"

    output_dir.mkdir(parents=True, exist_ok=True)

    try:
        iverilog = resolve_tool(args.iverilog, "iverilog")
        vvp = resolve_tool(args.vvp, "vvp")
    except FileNotFoundError as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 2

    if not iverilog or not vvp:
        print(
            "FAIL: Icarus Verilog was not found. Install iverilog/vvp or pass "
            "--iverilog and --vvp.",
            file=sys.stderr,
        )
        return 2

    source_paths = [str(PROJECT_ROOT / source) for source in SOURCES]
    compile_command = [
        iverilog,
        "-g2012",
        "-Wall",
        "-o",
        str(output_image),
        *source_paths,
    ]

    log_parts = ["[compile] running iverilog\n"]
    compile_code, compile_stdout, compile_stderr = run_and_capture(
        compile_command, PROJECT_ROOT
    )
    log_parts.extend([compile_stdout, compile_stderr])

    if compile_code != 0:
        log_parts.append("[compile] failed\n")
        write_summary(summary_file, "".join(log_parts))
        output_image.unlink(missing_ok=True)
        print(f"FAIL: iverilog compilation failed. See {summary_file}")
        return compile_code

    log_parts.append("[simulate] running vvp\n")
    sim_code, sim_stdout, sim_stderr = run_and_capture(
        [
            vvp,
            str(output_image),
            f"+RANDOM_TESTS={args.random_tests}",
            f"+SEED={args.seed}",
        ],
        PROJECT_ROOT,
    )
    log_parts.extend([sim_stdout, sim_stderr])

    if sim_code != 0:
        log_parts.append("[simulate] failed\n")
        write_summary(summary_file, "".join(log_parts))
        output_image.unlink(missing_ok=True)
        print(f"FAIL: simulation failed. See {summary_file}")
        return sim_code

    full_log = "".join(log_parts)
    write_summary(summary_file, full_log)
    output_image.unlink(missing_ok=True)

    print("PASS: simulation completed successfully")
    print(f"Summary: {summary_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
