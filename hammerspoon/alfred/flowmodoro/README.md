# Flowmodoro for Alfred

Type `fl`, followed by `start`, `pause`, `break`, or `reset`.

- During a running or paused session, `fl` shows the elapsed focused duration as
  its top result. While running, it refreshes once per second.
- `fl start` starts a fresh focus stopwatch or resumes a paused one.
- `fl pause` preserves the elapsed focus time.
- `fl break` logs the work block to the `Studying` calendar, then starts a
  native Clock timer of one minute per five focused minutes (rounded to the
  nearest minute). Sessions shorter than 10 minutes are discarded without a
  Calendar event or break.
- `fl reset` discards the active work block.

`fl start` and resume enable Do Not Disturb. `fl break` and `fl reset` disable
it; pausing leaves it enabled because the focus session remains active. Alfred's
built-in Run Shortcut action supplies the command directly to `Flowmodoro Focus`.

Alfred posts a notification after every session-changing command.

State is stored in Alfred's Workflow Data directory while focusing or paused.
Flowmodoro does not track breaks. On `fl break`, it passes four newline-separated
values to the installed `Flowmodoro Break` Shortcut: break seconds, focus start,
focus end, and calendar name. The Shortcut creates the Calendar event and, when
the break is non-zero, starts the visible Clock countdown and completion alarm.
Shortcut inputs are supplied through temporary text files using the supported
`shortcuts run --input-path` interface.

Install both `Flowmodoro Break.shortcut` and `Flowmodoro Focus.shortcut`.

The calendar can be changed with an Alfred workflow environment variable named
`FLOWMODORO_CALENDAR`. It defaults to `Studying`.

## Build

Run `./build.sh`. The installable workflow is written to
`dist/Flowmodoro.alfredworkflow`.
