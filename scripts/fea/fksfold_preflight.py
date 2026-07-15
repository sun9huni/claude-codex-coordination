"""FKSFold anchor-residue preflight (W400 tryptophan check).

Two layers:

  * ``verify_anchor_residues`` is PURE: it takes an already-parsed residue
    list and checks that the anchor position holds the expected one-letter
    code. It imports nothing heavy and never touches the filesystem.
  * ``run_anchor_preflight`` is the CIF adapter. It reuses
    ``verify_heldout_anchor.modeled()`` (under
    ``FKSFold-Boltz_Advancement/analysis/heldout_placement_20260601``) to
    parse a CIF into ``(author_resi, one_letter)`` tuples. That helper pulls
    in Bio.PDB transitively, so the import is done LAZILY inside the function
    and wrapped in try/except -- the rest of FEA must not require Bio.PDB, and
    a missing dependency degrades to a WARN rather than crashing.

Reuses ``Issue`` / ``PreflightReport`` from ``scripts.fea.preflight``.
"""

from __future__ import annotations

from scripts.fea.preflight import Issue, PreflightReport


def verify_anchor_residues(residues, w400_idx, expected="W") -> list[Issue]:
    """Check the anchor (W400) residue at 1-based sequence position ``w400_idx``.

    ``residues`` is a list of ``(author_resi:int, one_letter:str)``; the lookup
    uses 1-based LIST position, so position ``i`` is ``residues[i - 1]``.
    """
    if w400_idx < 1 or w400_idx > len(residues):
        return [
            Issue(
                "error",
                "anchor_out_of_range",
                f"w400 index {w400_idx} out of range 1..{len(residues)}",
            )
        ]
    found = residues[w400_idx - 1][1]
    if found != expected:
        return [
            Issue(
                "error",
                "anchor_not_tryptophan",
                f"anchor position {w400_idx} is '{found}', expected "
                f"'{expected}' (W400 tryptophan)",
            )
        ]
    return []


def run_anchor_preflight(cif_path, chain, w400_idx, expected="W") -> PreflightReport:
    """Parse ``cif_path`` chain ``chain`` and run the anchor check.

    Bio.PDB (via ``verify_heldout_anchor.modeled``) is imported lazily; any
    import/parse failure degrades to a WARN rather than crashing.
    """
    try:
        import sys

        sys.path.append(
            "/home/ubuntu/FKSFold-Boltz_Advancement/analysis/heldout_placement_20260601"
        )
        from verify_heldout_anchor import modeled

        residues = modeled(cif_path, chain)
    except Exception as e:  # noqa: BLE001 -- never hard-crash on missing Bio.PDB
        return PreflightReport(
            [
                Issue(
                    "warn",
                    "anchor_check_unavailable",
                    f"could not run CIF anchor check: {e}",
                )
            ]
        )

    return PreflightReport(verify_anchor_residues(residues, w400_idx, expected))
