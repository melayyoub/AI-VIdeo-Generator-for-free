"""Boundary and CLI integration tests for the public port contract."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPOSITORY_ROOT))

from wan2_cli_args import MAX_PORT, MIN_PORT, port_number  # noqa: E402


class PortNumberTests(unittest.TestCase):
    def test_accepts_inclusive_boundaries(self) -> None:
        self.assertEqual(port_number(str(MIN_PORT)), MIN_PORT)
        self.assertEqual(port_number(str(MAX_PORT)), MAX_PORT)

    def test_rejects_values_outside_boundaries_and_non_integer_input(self) -> None:
        for value in ("0", "65536", "not-a-port"):
            with self.subTest(value=value):
                with self.assertRaisesRegex(
                    argparse.ArgumentTypeError, "1 through 65535"
                ):
                    port_number(value)


class LauncherPortTests(unittest.TestCase):
    def run_cli(
        self,
        script: str,
        *arguments: str,
        environment: dict[str, str] | None = None,
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(REPOSITORY_ROOT / script), *arguments],
            cwd=REPOSITORY_ROOT,
            env=environment,
            capture_output=True,
            check=False,
            text=True,
        )

    def assert_port_error(self, result: subprocess.CompletedProcess[str]) -> None:
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn("1 through 65535", result.stderr)

    def test_lightweight_launcher_accepts_boundaries(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            base = Path(temporary_directory)
            comfyui = base / "ComfyUI"
            comfyui.mkdir()
            (comfyui / "main.py").write_text("", encoding="utf-8")

            for value in (str(MIN_PORT), str(MAX_PORT)):
                with self.subTest(value=value):
                    result = self.run_cli(
                        "wan2_cli.py",
                        "start",
                        "--path",
                        str(base),
                        "--device",
                        "cpu",
                        "--port",
                        value,
                    )
                    self.assertEqual(
                        result.returncode, 0, result.stdout + result.stderr
                    )

    def test_lightweight_launcher_rejects_out_of_range_cli_ports(self) -> None:
        for value in ("0", "65536"):
            with self.subTest(value=value):
                result = self.run_cli("wan2_cli.py", "start", "--port", value)
                self.assert_port_error(result)

    def test_lightweight_launcher_validates_environment_default(self) -> None:
        environment = os.environ.copy()
        environment["CUSTOM_WAN_COMFYUI_PORT"] = "65536"
        result = self.run_cli("wan2_cli.py", "start", environment=environment)
        self.assert_port_error(result)

    def test_rtx_launcher_accepts_boundaries(self) -> None:
        for value in (str(MIN_PORT), str(MAX_PORT)):
            with self.subTest(value=value):
                result = self.run_cli(
                    "wan2_cli_RTX.py",
                    "start",
                    "--dry-run",
                    "--port",
                    value,
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_rtx_launcher_rejects_out_of_range_ports(self) -> None:
        for value in ("0", "65536"):
            with self.subTest(value=value):
                result = self.run_cli(
                    "wan2_cli_RTX.py",
                    "start",
                    "--dry-run",
                    "--port",
                    value,
                )
                self.assert_port_error(result)


if __name__ == "__main__":
    unittest.main()
