"""Experiment-only launcher: an inherited two-CPU ceiling, not a new R test runner."""
import ctypes
import json
import os
from pathlib import Path
import subprocess
import sys
import time


def windows_mask(pid=None):
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.GetCurrentProcess.restype = ctypes.c_void_p
    kernel.OpenProcess.restype = ctypes.c_void_p
    kernel.OpenProcess.argtypes = [ctypes.c_ulong, ctypes.c_int, ctypes.c_ulong]
    kernel.GetProcessAffinityMask.argtypes = [ctypes.c_void_p,
                                             ctypes.POINTER(ctypes.c_size_t),
                                             ctypes.POINTER(ctypes.c_size_t)]
    handle = kernel.GetCurrentProcess() if pid is None else kernel.OpenProcess(0x1000, False, pid)
    if not handle:
        raise ctypes.WinError(ctypes.get_last_error())
    process, system = ctypes.c_size_t(), ctypes.c_size_t()
    try:
        if not kernel.GetProcessAffinityMask(handle, ctypes.byref(process), ctypes.byref(system)):
            raise ctypes.WinError(ctypes.get_last_error())
        return process.value
    finally:
        if pid is not None:
            kernel.CloseHandle.argtypes = [ctypes.c_void_p]
            kernel.CloseHandle(handle)


def affinity(pid=0):
    if sys.platform == "win32":
        mask = windows_mask(None if pid == 0 else pid)
        return [i for i in range(mask.bit_length()) if mask & (1 << i)]
    if sys.platform.startswith("linux"):
        return sorted(os.sched_getaffinity(pid))
    return None


def main():
    if sys.argv[1:] == ["--verify-parent"]:
        cpus = affinity(os.getppid())
        if cpus is not None and not 1 <= len(cpus) <= 2:
            raise RuntimeError("R parent escaped the two-CPU ceiling")
        print(json.dumps({"r_pid": os.getppid(), "affinity": cpus}))
        return 0
    if len(sys.argv) < 2:
        raise ValueError("command required")
    cpus = affinity()
    if cpus is not None:
        cpus = cpus[:2]
        if sys.platform == "win32":
            kernel = ctypes.WinDLL("kernel32", use_last_error=True)
            kernel.GetCurrentProcess.restype = ctypes.c_void_p
            kernel.SetProcessAffinityMask.argtypes = [ctypes.c_void_p, ctypes.c_size_t]
            if not kernel.SetProcessAffinityMask(kernel.GetCurrentProcess(),
                                                 sum(1 << i for i in cpus)):
                raise ctypes.WinError(ctypes.get_last_error())
        else:
            os.sched_setaffinity(0, cpus)
        if affinity() != cpus:
            raise RuntimeError("affinity was not applied")
    os.environ["GPTR_PERF_PYTHON"] = sys.executable
    os.environ["GPTR_PERF_LAUNCHER"] = str(Path(__file__).resolve())
    os.environ["TESTTHAT_PARALLEL"] = str(
        os.environ.get("GPTR_CI_PERF_VARIANT") == "optimized"
        and sys.platform.startswith("linux") and cpus is not None).lower()
    started = time.monotonic()
    result = subprocess.run(sys.argv[1:], check=False)
    output = Path("perf-evidence")
    output.mkdir(exist_ok=True)
    (output / "launch.json").write_text(json.dumps({
        "variant": os.environ.get("GPTR_CI_PERF_VARIANT"),
        "affinity": cpus, "parallel": os.environ["TESTTHAT_PARALLEL"],
        "seconds": time.monotonic() - started, "exit": result.returncode}, indent=2),
        encoding="utf-8")
    return result.returncode


if __name__ == "__main__":
    sys.exit(main())
