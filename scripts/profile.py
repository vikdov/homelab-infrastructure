#!/usr/bin/env python3
"""Guardrail for the 16 GB host: check whether a set of profiles fits before anything
is actually started.

    python3 scripts/profile.py budget core apps
    python3 scripts/profile.py budget core k8s lab
    python3 scripts/profile.py list core            # guests in a profile, for the Taskfile

Exit code is non-zero when a combination would exceed the available RAM, so this doubles
as a CI check (see .github/workflows/validate.yml) and as a pre-flight the Taskfile runs
before `task up`.
"""
import argparse
import os
import sys

import yaml

HERE = os.path.dirname(os.path.abspath(__file__))
NETWORK_YAML = os.path.normpath(os.path.join(HERE, "..", "network.yaml"))


def load_config():
    with open(NETWORK_YAML, "r", encoding="utf-8") as fh:
        return yaml.safe_load(fh)


def available_mb(cfg):
    b = cfg["budget"]
    return b["total_mb"] - b["host_reserve_mb"] - b["headroom_mb"]


def profile_usage_mb(cfg, profile):
    return sum(
        g["memory_mb"] for g in cfg["guests"].values() if g["profile"] == profile
    )


def cmd_budget(cfg, profiles):
    unknown = [p for p in profiles if p not in cfg["profiles"]]
    if unknown:
        print(f"unknown profile(s): {', '.join(unknown)}", file=sys.stderr)
        return 2

    avail = available_mb(cfg)
    used = sum(profile_usage_mb(cfg, p) for p in profiles)
    pct = (used / avail) * 100 if avail else 0

    print(f"profiles:        {' + '.join(profiles)}")
    print(f"available:       {avail} MB  (of {cfg['budget']['total_mb']} MB total)")
    print(f"requested:       {used} MB  ({pct:.0f}%)")

    if used > avail:
        print(f"OVER BUDGET by {used - avail} MB", file=sys.stderr)
        return 1

    print(f"headroom left:   {avail - used} MB")
    return 0


def cmd_list(cfg, profile):
    names = sorted(n for n, g in cfg["guests"].items() if g["profile"] == profile)
    for n in names:
        print(n)
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    p_budget = sub.add_parser("budget", help="check whether these profiles fit together")
    p_budget.add_argument("profiles", nargs="+")

    p_list = sub.add_parser("list", help="list guest names in a profile")
    p_list.add_argument("profile")

    args = parser.parse_args()
    cfg = load_config()

    if args.command == "budget":
        sys.exit(cmd_budget(cfg, args.profiles))
    elif args.command == "list":
        sys.exit(cmd_list(cfg, args.profile))


if __name__ == "__main__":
    main()
