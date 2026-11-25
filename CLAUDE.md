# KrakenChat

- Work on `main`, commit to `main` and push to `main`: the author pulls from there. No feature branches.
- Run the tests before pushing: `cd tests && npm install && node run.js` (check the exit code, not only the output).
- Each new version: bump `## Version` in `KrakenChat.toc` and the fallback in `Core.lua`, and add a section at the top of `CHANGELOG.md`.
- When giving the author a changelog (for CurseForge), always give the complete `CHANGELOG.md`, every version, newest first, so readers see the whole history.
- The CurseForge changelog lists only versions uploaded there; changes from versions that were skipped go into the next uploaded one. Uploaded so far: 1.1.0 (the first, including everything from 1.0.0), 1.1.2 (including 1.1.1), 1.1.3, 1.1.4, 1.1.5, 1.1.6. Next: 1.2.0 (including 1.1.7). Keep this list current.
