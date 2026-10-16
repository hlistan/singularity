---
name: accessibility
description: Web accessibility to WCAG 2.2 level AA for user-facing UI. For specifying, implementing, reviewing and browser-testing changes to web pages and components.
---

# Accessibility (WCAG 2.2 AA)

The bar is WCAG 2.2 level AA (W3C Recommendation, 2023): <https://www.w3.org/TR/WCAG22/>. Numbers below are its success criteria. Project specifics (the component library, an accessibility test command, known exceptions) are in the project's guidelines.

## Semantics

- Native elements first: `button` for actions, `a href` for navigation, `label` for inputs, headings in order, landmarks (`main`, `nav`). ARIA only where no native element does the job, and then the complete pattern (W3C, *Using ARIA*, first rule) (1.3.1, 4.1.2).
- Every image has a text alternative; decorative images `alt=""` (1.1.1).
- Status changes that don't move focus (saved, 3 results, error count) are announced through a live region (4.1.3).

## Keyboard and focus

- Everything works by keyboard alone, with no trap, in a logical order (2.1.1, 2.1.2, 2.4.3).
- Focus is always visible and not hidden behind sticky headers, banners or dialogs (2.4.7, 2.4.11).
- A dialog moves focus into itself, keeps it there while open, and returns it on close.
- Dragging has a single-pointer alternative (2.5.7). Targets are at least 24 by 24 CSS pixels, or spaced as if they were (2.5.8).

## Forms and authentication

- Every input has a visible label or instructions (3.3.2); an error says what is wrong in text, next to the field, and is tied to it (3.3.1).
- Don't ask again for what the user already entered in the same process (3.3.7).
- Sign-in needs no cognitive test (remembering, transcribing, solving); allow paste and password managers (3.3.8).

## Visual

- Contrast: text 4.5:1, large text 3:1; UI components and graphics that carry meaning 3:1 (1.4.3, 1.4.11). Never colour alone (1.4.1).
- Works at 200% text size and at 320 CSS pixels wide without horizontal scrolling (1.4.4, 1.4.10).
- Nothing flashes more than three times a second (2.3.1); motion stops on request, and honours `prefers-reduced-motion`.

## By role

- **Spec**: new or changed UI gets acceptance criteria for keyboard use, focus and what a screen reader announces.
- **Implement**: an automated check in component or end-to-end tests (axe-core, e.g. `jest-axe` or `@axe-core/playwright`) where the project has one; automated checks find only part of the issues, so also tab through the change.
- **Review**: the criteria above on the changed markup; a custom widget without its keyboard pattern is a finding.
- **Browser QA**: walk each criterion by keyboard only; check focus visibility and the zoomed, narrow layout.
