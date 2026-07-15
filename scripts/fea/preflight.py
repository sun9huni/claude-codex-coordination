"""FragMap conditioning preflight validator.

Validates a fragmap_conditioning config block before launch: mode legality,
path existence, and channel presence. The pocket audit is added later
(Task 3/4); this module covers the core checks only.
"""

from __future__ import annotations

import os
from dataclasses import dataclass

import yaml

# Source of truth for legal/forbidden modes:
#   /home/ubuntu/FKSFold-Boltz_Advancement/src/boltz_extension/steering/fragmap_steering.py
#   ~L345-430
FORBIDDEN_MODES = {"feature", "atom", "feature_probability"}
VALID_MODES = {"cluster_then_grid", "grid", "target_occupancy"}

# Canonical VAV1 pocket (1-based seq); hardcoded as --w400_vav1_residues
# across submit scripts.
VAV1_POCKET_GT = frozenset({16, 17, 18, 19, 20})
POCKET_TOLERANCE = 1  # ±1-neighbor tolerance (residues within 1 of GT not flagged)


@dataclass
class Issue:
    severity: str  # "error" | "warn"
    code: str
    message: str


@dataclass
class PreflightReport:
    issues: list[Issue]

    @property
    def ok(self) -> bool:
        """True iff no error-severity issue is present."""
        return not any(i.severity == "error" for i in self.issues)


def _audit_pocket(input_yaml_path) -> list[Issue]:
    """Compare chain-B (VAV1) pocket contacts against the canonical GT set.

    Residues within POCKET_TOLERANCE of any GT residue are not flagged. Any
    observed residue farther than the tolerance from the whole GT set is
    reported (WARN; advisory, warn-first policy).
    """
    with open(input_yaml_path) as fh:
        doc = yaml.safe_load(fh) or {}

    observed: set[int] = set()
    for item in doc.get("constraints") or []:
        if not isinstance(item, dict):
            continue
        pocket = item.get("pocket")
        if not isinstance(pocket, dict):
            continue
        for pair in pocket.get("contacts") or []:
            # Tolerant of list/tuple [chain, resid].
            chain, resid = pair[0], pair[1]
            if chain == "B":
                observed.add(int(resid))

    if not observed:
        return []

    offending = {
        r
        for r in observed
        if min(abs(r - g) for g in VAV1_POCKET_GT) > POCKET_TOLERANCE
    }
    if offending:
        return [
            Issue(
                "warn",
                "pocket_residue_mismatch",
                f"VAV1 pocket contacts {sorted(offending)} are off the canonical "
                f"GT {sorted(VAV1_POCKET_GT)} (>±{POCKET_TOLERANCE})",
            )
        ]
    return []


def run_preflight(config_path, input_yaml=None) -> PreflightReport:
    with open(config_path) as fh:
        cfg = yaml.safe_load(fh) or {}

    # Be lenient: accept either a wrapped config or a bare block.
    block = cfg.get("fragmap_conditioning", cfg)

    issues: list[Issue] = []

    # --- mode check ---
    mode = block.get("mode")
    if mode is None:
        issues.append(Issue("error", "missing_mode", "mode is missing"))
    elif mode in FORBIDDEN_MODES:
        issues.append(
            Issue(
                "error",
                "forbidden_mode",
                f"mode '{mode}' is forbidden (use one of {sorted(VALID_MODES)})",
            )
        )
    elif mode not in VALID_MODES:
        issues.append(
            Issue(
                "warn",
                "unknown_mode",
                f"mode '{mode}' is not a recognized mode (expected one of {sorted(VALID_MODES)})",
            )
        )

    # --- path existence ---
    if "fragmap_npz" not in block:
        issues.append(
            Issue("error", "missing_npz_key", "fragmap_npz key is required but missing")
        )
    for key in ("fragmap_npz", "reference_pdb"):
        if key in block:
            value = block[key]
            if not os.path.exists(value):
                issues.append(
                    Issue(
                        "error", "missing_path", f"{key} path does not exist: {value}"
                    )
                )

    # --- channels ---
    channels = block.get("channels")
    if not isinstance(channels, list) or not channels:
        issues.append(
            Issue("error", "empty_channels", "channels must be a non-empty list")
        )

    # --- pocket audit ---
    if input_yaml is not None:
        issues.extend(_audit_pocket(input_yaml))

    return PreflightReport(issues)
