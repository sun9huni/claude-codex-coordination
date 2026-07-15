# Browser QA Checklist

Use this checklist when a task changes web UI, routing, visual behavior, forms, navigation, or user-facing copy.

## Required Context

- target URL:
- local server command:
- changed pages/components:
- expected user-visible outcome:

## Viewports

- desktop: 1440 x 900
- tablet: 768 x 1024
- mobile: 390 x 844

## Page Health

- page loads without a blank screen
- no obvious console/runtime errors
- images, fonts, icons, and media render
- loading, empty, error, and success states are not visually broken

## Layout

- text does not overlap
- text is not clipped inside buttons, cards, tabs, or inputs
- primary actions remain visible and reachable
- sticky/fixed elements do not cover content
- responsive layout preserves the intended hierarchy

## Interaction

- primary flow can be completed
- forms accept input and show useful validation
- menus, tabs, toggles, dialogs, and drawers open and close correctly
- keyboard focus is visible for interactive elements
- disabled/loading states are clear

## Regression Checks

- existing navigation still works
- unchanged critical flows still render
- no unrelated visual style shift is visible

## Completion Note

Record the checked URL, viewports, user flows, issues found, and remaining manual risks in the task plan or final response.
