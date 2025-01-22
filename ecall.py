# Generates some preamble to make ECalls easy

import sys

names = sys.stdin.read().split()

print("[data]")
for name in names:
    print(f"@{name}_name {len(name)} \"{name}\"")
    print(f"@{name} [resw]")

print("[code]")
for name in names:
    print(f"#&{name}_name ECALLi 0 WRWi &{name}")
