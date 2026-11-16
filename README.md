# gitizen

A tiny macOS menu bar app that watches GitHub repos for new PRs, issues, and stars.

- The bell shows a count of new things across all watched repos.
- Click it to see each repo's open PRs and any new open issues. New ones have a blue dot. Click an item to open it on GitHub.
- "Mark All Seen" resets the count.
- Checks every 5 minutes (or hit refresh).

## Build

```sh
./build.sh
open build/Gitizen.app
```

Copy `build/Gitizen.app` to `/Applications` and launch it from there, then check "Launch at login" in the panel. Login items remember the app's path, so move it first.

Requires macOS 15+.

## Auth

gitizen borrows your GitHub CLI token (`gh auth token`), so private repos work and you get the 5000/hr rate limit. Without `gh`, it falls back to unauthenticated requests (60/hr, enough for 1 repo at a 5 minute poll).

## How "new" works

When you add a repo, its current state is the baseline. After that, any issue or PR numbered higher than the last one you've seen is new, and stars above the last seen count are new. Open PRs are always listed; issues are listed only while they're new and open.

## License

MIT
