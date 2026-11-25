# KrakenChat

- Work on `main`, commit to `main` and push to `main`: the author pulls from there. No feature branches.
- Run the tests before pushing: `cd tests && npm install && node run.js` (check the exit code, not only the output).
- Each new version: bump `## Version` in `KrakenChat.toc` and the fallback in `Core.lua`, and add a section at the top of `CHANGELOG.md`.
- When giving the author a changelog (for CurseForge), always give the complete `CHANGELOG.md`, every version, newest first, so readers see the whole history.
