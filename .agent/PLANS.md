# Codex Execution Plans

This file defines how execution plans are written and maintained in this repository.

## When To Use A Plan

Use a plan for complex features, significant refactors, multi-step debugging, cross-cutting changes, or any task that benefits from explicit milestones and acceptance criteria.

## Plan Principles

- A plan is a living document.
- A plan must be self-contained.
- A plan must be understandable by someone with only the repository and the plan file.
- A plan must define what success looks like in observable terms.
- A plan must specify what must not change.
- A plan must surface assumptions before implementation starts.
- Each implementation step should have a corresponding verification check.

## Required Sections

Every plan file under `.agent/contracts/` must contain the following sections.

### Purpose

What user-visible or system-visible outcome this work enables.

### Current State

What exists now, what is broken or missing, and any relevant repository facts.

### Assumptions And Questions

Known assumptions, ambiguous requirements, and tradeoffs that could affect the implementation.

### Constraints

Technical, product, security, or timeline limits.

### Non-Goals

What this plan intentionally does not do.

### Done When

A measurable definition of done.

### Implementation Steps

Ordered milestones with enough detail to execute. Each step should include a verification check.

### Change Discipline

How the plan keeps the implementation minimal, scoped, and traceable to the request.

### Verification

Exact commands, checks, and expected observations.

### Risks

Likely failure modes and how to detect them.

### Rollback

How to back out or contain the change safely.

### Progress Log

Timestamped notes about decisions, discoveries, and current status.

## Maintenance Rules

- Update the plan as the work evolves.
- If assumptions change, record them.
- If scope expands, explicitly note it.
- If verification fails, log the failure and the next step.
