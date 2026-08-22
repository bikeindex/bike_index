# Screenshot phase

This is SKILL.md's **Screenshots** section — read it once the PR exists and **Publish** classified the diff as frontend. It needs the base branch from **Orient** and the PR number from **Publish**; substitute both as literals, since shell state doesn't carry between commands. The numbered steps below are this file's own.

The flow: decide what to capture → capture the branch → upload → capture the same URLs on the base branch → post one `## Screenshots` PR comment. Screenshots go in a **comment**, never the PR body, so the human-written summary stays first and recaptures don't churn the description.

## Preflight: no `gh`, no screenshots

**This phase needs `gh` *and* a browser signed in to GitHub. Missing either, skip the whole thing** — don't capture, don't upload, don't post anything in its place. Say in your summary that screenshots need a machine with both, and hand back the PR URL.

**Check the login before capturing, not after.** The session lives in a storage-state file that expires without warning, so a signed-out browser is the ordinary case on a machine that has `gh` — and discovering it at upload time wastes the whole capture round, base-branch checkout included. One navigate settles it:

```js
browser_navigate({ url: "https://github.com" })
browser_evaluate: () => document.querySelector('meta[name="user-login"]')?.content || 'signed out'
```

Empty or `signed out` → `github-pr-images`' [headless-relogin.md](../../github-pr-images/references/headless-relogin.md), which the user has to run; it can't be driven headlessly.

The Claude Code web sandbox is the case that has neither: no GitHub CLI, and an MCP browser that rejects the egress proxy's CA, so github.com won't even load (`ERR_CERT_AUTHORITY_INVALID`) and a logged-in session can't be established headlessly. Capture alone would work there, which is the trap — PNGs nothing can host, and no way to post them.

**Skipping means posting nothing at all**, not posting something else. Substitute evidence — a rendered-HTML diff, a note about what couldn't be captured — reads as a fine idea in the moment and leaves a comment the next run can't find or replace, because it isn't the `## Screenshots` comment. That's how #4126 ended up with three comments telling one story. If the evidence is worth having, put it in your summary to the user and let them decide where it goes.

## Preflight: a CSS diff needs a fresh tailwind build

When the diff touches `app/assets/tailwind/**`, check that `app/assets/builds/tailwind.css` contains the branch's new rules before capturing — another checkout's watcher can leave it stale for hours, and the capture then documents the bug the PR fixes. `bin/rails tailwindcss:build` is the fix — the same command step 4 runs on each checkout.

**Count occurrences, not lines.** The built file is minified onto very few lines, so `grep -c '<selector>'` reports `0` or `1` for a selector that's present many times, and a fresh build reads as a missing one. Use `grep -o '<selector>' app/assets/builds/tailwind.css | wc -l`, and compare the file's mtime against the source's before concluding anything.

## 1. Decide whether screenshots are needed and which URLs to capture

You're only here because the diff is frontend (SKILL.md's classifier gates on that). Decide scope by PR state:

- New PR → capture every affected page.
- Existing PR → continue only if the captures in the existing screenshots comment are stale: a commit since the last capture touched a page already screenshotted, or a new affected page now appears in the diff. Limit the capture to those pages. If nothing has moved, return the PR URL.

**A page the diff no longer touches loses its block rather than gaining a recapture.** When work lands on the base separately — the branch's own commits merged as another PR, say — `git diff origin/main -- <path>` for those files comes back empty, and their before/after now documents a change this PR doesn't make, with a "main 👆" shot taken before the base moved. Drop the `### <url-path>` block; don't recapture it to show two identical images.

Reading that comment is `github-pr-images`'s job, since it owns it — ask it for the current body before deciding. This costs no browser: it's a `gh api` read.

From the changed files, infer the affected routes. Heuristics:
- A view at `app/views/bikes/show.html.erb` → `/bikes/:id` (pick a representative id from the dev db, e.g. `Bike.last.id`)
- A component touched by a specific page → screenshot that page
- A shared component (header, footer, UI::Badge, etc.) → screenshot 1–2 representative pages that exercise it
- A component with a ViewComponent/Lookbook preview → its preview URL (`frontend-screenshots` covers the path format) — a real responsive page, captured like any other URL
- Admin views → `/admin/...`
- If unclear, ask the user which URLs to capture before proceeding. Do not guess blindly — 1–3 well-chosen URLs beats 10 random ones.

**Confirm the page renders what changed, before capturing it.** A page that looks like the obvious home for a component often isn't — `/admin/organizations/:id/edit` has seven tables and none of them is `UI::Table`, and its address fields aren't `UI::Forms::AddressGroup` either. One `browser_evaluate` counting the component's own marker class settles it; a shot that turns out not to contain the change is a whole capture round wasted, base branch included. A component with a preview is the reliable fallback.

## 2. Capture branch screenshots

Invoke the `frontend-screenshots` skill with the `(url-path, page-slug)` pairs from step 1. It handles dev-server check, sign-in, the seeded-user identity gate, viewport sizing, and per-PNG sanity checks, and returns the local PNG paths.

If it returns failures it couldn't diagnose, report them and leave the PR without screenshots — don't post partial results. Abandoning the phase after a capture is the one path where nothing else closes the browser, so close it yourself.

## 3. Host the branch screenshots and get inline URLs

Invoke `github-pr-images` with the PNGs from step 2 and **no body** — that's its host-only call, and it returns the `user-attachments/assets/` URLs without posting anything. The comment gets composed here in step 5 and posted by that same skill in one go at the end, so nothing lands on the PR until the before/after is complete. GitHub mints persistent URLs that render inline in the browser (release assets would force a download on click).

Collect the returned URLs, keyed by `(page-slug, viewport)`.

## 4. Capture and upload the same URLs on the base branch

Capture the **base-branch** version (the base from SKILL.md's **Orient**) of every screenshot from step 2 so the section becomes a before/after comparison instead of "here's how it looks now." This is the default for every screenshot captured — if you got this far, the diff is frontend, and the comparison is informative (a same-screenshot pair documents visual parity for a refactor; a different pair documents the actual visual change).

Skip per-page only when the URL didn't exist on the base (a brand-new route or page added in this PR) — there's nothing to compare to.

Re-invoke `frontend-screenshots` with the same `(url-path, page-slug)` pairs, passing the base as its `BASE_REF` (`origin/main` unless **Orient** chose otherwise) — its "Cross-branch comparison" section does the rest, whether or not the base is `main`. Then re-invoke `github-pr-images` for those PNGs, host-only exactly as in step 3.

`git rev-list --count HEAD..origin/main` first: **Prepare the branch**'s merge normally leaves it 0, but on a long run the remote moves after that merge, and the "before" then shows base commits the branch never saw.

Two things the checkout itself does, either side of it:

- **`bin/rails tailwindcss:build` after each checkout when the diff touches `app/assets/tailwind/**`.** The watcher doesn't rebuild on a checkout, so the base capture otherwise renders the branch's CSS — a before/after that silently shows the same styling twice. Verify by grepping `app/assets/builds/tailwind.css` for a class the branch adds; build again on the way back.
- **`bin/dev` restarts, so the first navigate after a checkout can hit `ERR_CONNECTION_REFUSED`.** Poll `curl -fs "$BASE_URL/"` until it answers rather than treating it as a failed capture.

## 5. Compose the Screenshots comment and hand it back

Write the body to a temp file and invoke `github-pr-images` with it. That skill owns the comment — finding the existing one, creating or editing it, verifying it rendered — and it posts what you hand it verbatim. Everything below is what goes *in* the body.

Its first line is always `## Screenshots`, because that heading is the handle it's found by next time.

The base-branch shots and branch shots stack as rows in one table, with a small indicator row between them when both are present. The indicator labels the base by its PR when it has one — `#3918 👆` for a stacked base, plain `main 👆` otherwise:

```bash
gh pr list --head <base-branch> --state all --json number --jq '.[0].number // empty'
```

`// empty` is load-bearing — without it a base with no PR yields the literal `#null`.

```markdown
## Screenshots

### <url-path>

| Desktop | Mobile |
| --- | --- |
| <img src="<base-desktop-url>" width="500"> | <img src="<base-mobile-url>" width="250"> |
| <base-label> 👆 | this branch 👇 |
| <img src="<branch-desktop-url>" width="500"> | <img src="<branch-mobile-url>" width="250"> |
```

Brand-new page (URL didn't exist on the base — see step 4), no comparison row:

```markdown
### <url-path>

| Desktop | Mobile |
| --- | --- |
| <img src="<branch-desktop-url>" width="500"> | <img src="<branch-mobile-url>" width="250"> |
```

Rules:
- Each page gets a `### <url-path>` subheading (the literal path, e.g. `/`, `/bikes/42`, `/admin/strava_activities`) followed by its own table.
- **Every** entry uses this table, with **no exceptions** — including component previews. A preview is a responsive page with a real URL, so it gets the same desktop+mobile before/after cells as any page. A width-invariant component (small icon, fixed-size control) just yields matching desktop and mobile shots — that's expected; keep both columns, never collapse to one image or special-case previews.
- **Headers are always `| Desktop | Mobile |`** — never `| main | this branch |` or any per-PR variation. Reviewers should see the same column meaning across every PR.
- Use `<img src=... width=...>` rather than `![]()` so the widths render predictably in GitHub's table cells. ~500 for desktop, ~250 for mobile fits a side-by-side cell layout cleanly.

When updating an existing screenshots comment, ask `github-pr-images` for its current body first, replace the `### <url-path>` block for any page you recaptured, and leave every other page's block alone — you're handing back a whole body, so anything you drop is dropped.

Return the PR URL.
