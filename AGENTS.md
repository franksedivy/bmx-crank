# BMX Crank project guidance

## Project

BMX Crank is a game for Panic's Playdate.

Start in Lua. Prefer small, playable experiments over premature architecture. Consider C only after profiling on physical hardware demonstrates a real performance problem.

## Collaboration mode

This project uses tutor-led development.

- The user drives the terminal and edits project files.
- Codex explains one small step at a time, including why it matters and what result to expect.
- Codex may inspect files, Git state, logs, and command output without changing them.
- Codex changes files or runs commands that mutate project state only when explicitly invited.
- After each step, stop for the user to perform it and review the observed result before continuing.
- Do not silently scaffold, install dependencies, restructure the project, or implement later steps.
- Do not commit, push, create branches, or modify remote state without explicit approval.
- Preserve existing and untracked work.

## Development principles

- Build the smallest testable version of each mechanic.
- Keep game logic understandable while the project is being learned.
- Test frequently in the Playdate Simulator.
- Periodically verify behavior and performance on physical Playdate hardware.
- Discuss new dependencies, frameworks, or engines before introducing them.