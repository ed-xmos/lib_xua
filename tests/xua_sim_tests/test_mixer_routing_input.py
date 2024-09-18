# Copyright 2023-2024 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
import pytest
import Pyxsim
from Pyxsim import testers
import sys
from pathlib import Path


def do_test(options, capfd, test_file, test_seed):

    testname = Path(__file__).stem
    binary = Path(__file__).parent / testname / "bin" / f"{testname}.xe"

    tester = testers.ComparisonTester(open(Path(__file__).parent / "pass.expect"))

    max_cycles = 15000000

    simargs = [
        "--max-cycles",
        str(max_cycles),
    ]

    seed_rsp = Path(__file__).parent / testname / "test_seed.rsp"
    with open(seed_rsp, "w") as f:
        f.write(f"-DTEST_SEED={test_seed}")

    result = Pyxsim.run_on_simulator(
        binary,
        cmake=True,
        tester=tester,
        simargs=simargs,
        capfd=capfd,
        instTracing=options.enabletracing,
        vcdTracing=options.enablevcdtracing,
    )

    return result


def test_mixer_routing_input(options, capfd, test_file, test_seed):

    result = do_test(options, capfd, test_file, test_seed)

    assert result
