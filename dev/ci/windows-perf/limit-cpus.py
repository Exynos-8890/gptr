"""Bound the whole experimental process tree to two Windows CPUs."""
import ctypes
import json
import os
import subprocess
import sys


def mask(pid=None):
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.GetCurrentProcess.restype = ctypes.c_void_p
    kernel.OpenProcess.argtypes = [ctypes.c_ulong, ctypes.c_int, ctypes.c_ulong]
    kernel.OpenProcess.restype = ctypes.c_void_p
    kernel.GetProcessAffinityMask.argtypes = [ctypes.c_void_p,
                                             ctypes.POINTER(ctypes.c_size_t),
                                             ctypes.POINTER(ctypes.c_size_t)]
    handle = kernel.GetCurrentProcess() if pid is None else kernel.OpenProcess(0x1000, False, pid)
    if not handle:
        raise ctypes.WinError(ctypes.get_last_error())
    current, system = ctypes.c_size_t(), ctypes.c_size_t()
    try:
        if not kernel.GetProcessAffinityMask(handle, ctypes.byref(current), ctypes.byref(system)):
            raise ctypes.WinError(ctypes.get_last_error())
        return current.value
    finally:
        if pid is not None:
            kernel.CloseHandle.argtypes = [ctypes.c_void_p]
            kernel.CloseHandle(handle)


def main():
    if os.name != "nt":
        raise SystemExit("Windows only")
    if sys.argv[1:] == ["--verify-parent"]:
        value = mask(os.getppid())
        assert 1 <= value.bit_count() <= 2, "R worker escaped the two-CPU ceiling"
        print(json.dumps(dict(pid=os.getppid(), mask=value, cpus=value.bit_count())))
        return 0
    allowed = mask()
    cpus = [i for i in range(allowed.bit_length()) if allowed & (1 << i)][:2]
    selected = sum(1 << i for i in cpus)
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.GetCurrentProcess.restype = ctypes.c_void_p
    kernel.SetProcessAffinityMask.argtypes = [ctypes.c_void_p, ctypes.c_size_t]
    if not kernel.SetProcessAffinityMask(kernel.GetCurrentProcess(), selected):
        raise ctypes.WinError(ctypes.get_last_error())
    assert selected == mask() and 1 <= len(cpus) <= 2
    os.environ["GPTR_WINDOWS_PERF_PYTHON"] = sys.executable
    os.environ["GPTR_WINDOWS_PERF_LAUNCHER"] = os.path.abspath(__file__)
    print(json.dumps(dict(affinity=cpus)), flush=True)
    return subprocess.run(sys.argv[1:], check=False).returncode


if __name__ == "__main__":
    sys.exit(main())
