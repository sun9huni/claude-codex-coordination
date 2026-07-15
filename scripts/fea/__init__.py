"""FragMap Experiment Autopilot (FEA) — Phase 1 package.

Scope (Phase 1): Stage 3+4 fragmap postflight + results card capture.
See README.md for the contract and plan links.

The submodules below do not exist yet — they land in later plan tasks.
Imports are intentionally deferred (commented) so this package import
stays side-effect free until those modules are created.
"""

# from . import postflight  # noqa: ERA001 — added in a later task
# from . import results_card  # noqa: ERA001 — added in a later task
# from . import capture  # noqa: ERA001 — added in a later task

__all__ = ["postflight", "results_card", "capture", "watch"]
