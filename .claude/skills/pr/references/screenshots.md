# Screenshot phase

This is SKILL.md step 10 — read it after the PR exists (steps 1–9) when step 7 classified the diff as frontend. It needs the base branch (step 2) and the PR number (step 6 or 9); substitute both as literals, since shell state doesn't carry between commands.

The flow: decide what to capture → capture the branch → upload → capture the same URLs on the base branch → post one `## Screenshots` PR comment. Screenshots go in a **comment**, never the PR body, so the human-written summary stays first and recaptures don't churn the description.

**Preflight — the Claude Code web sandbox can't finish this phase.** Capture (steps 1, 2 and 4) works there, but the upload can't: the MCP browser rejects the egress proxy's CA, so github.com fails to load with `ERR_CERT_AUTHORITY_INVALID`, and even past that, uploading needs a logged-in GitHub session that can't be established headlessly. Don't start the capture there — tell the user step 10 needs a machine with a browser signed in to GitHub, and hand back the PR URL.

## 1. Decide whether screenshots are needed and which URLs to capture

You're only here because the diff is frontend (SKILL.md step 7 gates on that). Decide scope by PR state:

- New PR → capture every affected page.
- Existing PR → continue only if the captures in the existing screenshots comment are stale: a commit since the last capture touched a page already screenshotted, or a new affected page now appears in the diff. Limit the capture to those pages. If nothing has moved, return the PR URL.

From the changed files, infer the affected routes. Heuristics:
- A view at `app/views/bikes/show.html.erb` → `/bikes/:id` (pick a representative id from the dev db, e.g. `Bike.last.id`)
- A component touched by a specific page → screenshot that page
- A shared component (header, footer, UI::Badge, etc.) → screenshot 1–2 representative pages that exercise it
- A component with a ViewComponent/Lookbook preview → its preview URL (`frontend-screenshots` covers the path format) — a real responsive page, captured like any other URL
- Admin views → `/admin/...`
- If unclear, ask the user which URLs to capture before proceeding. Do not guess blindly — 1–3 well-chosen URLs beats 10 random ones.

## 2. Capture branch screenshots

Invoke the `frontend-screenshots` skill with the `(url-path, page-slug)` pairs from step 1. It handles dev-server check, sign-in, the seeded-user identity gate, viewport sizing, and per-PNG sanity checks, and returns the local PNG paths.

If it returns failures it couldn't diagnose, report them and leave the PR without screenshots — don't post partial results.

## 3. Upload branch screenshots and get inline URLs

Invoke the `github-upload-image-to-pr` skill **for uploading only**: run it through its step 7 (upload each PNG from step 2, read back the `user-attachments/assets/` URLs, clear the textarea) and **stop there — do not run its step 8 posting.** This phase composes and posts one combined before/after comment itself in step 5, so the upload skill must not post its own. GitHub mints persistent URLs that render inline in the browser (release assets would force a download on click).

Collect the returned URLs, keyed by `(page-slug, viewport)`.

## 4. Capture and upload the same URLs on the base branch

Capture the **base-branch** (SKILL.md step 2) version of every screenshot from step 2 so the section becomes a before/after comparison instead of "here's how it looks now." This is the default for every screenshot captured — if you got this far, the diff is frontend, and the comparison is informative (a same-screenshot pair documents visual parity for a refactor; a different pair documents the actual visual change).

Skip per-page only when the URL didn't exist on the base (a brand-new route or page added in this PR) — there's nothing to compare to.

Re-invoke `frontend-screenshots` with the same `(url-path, page-slug)` pairs, passing the base as its `BASE_REF` (`origin/main` unless step 2 chose otherwise) — its "Cross-branch comparison" section does the rest, whether or not the base is `main`. Then re-invoke `github-upload-image-to-pr` for those PNGs (upload-only, exactly as in step 3 — collect URLs, do not post).

## 5. Post the Screenshots section as a PR comment

On a fresh PR, this comment is naturally the first one. On an update, find your existing screenshots comment and edit it in place rather than posting a new one (substitute the PR number for `<number>`):

```bash
ME=$(gh api user --jq .login)
gh api --paginate "repos/{owner}/{repo}/issues/<number>/comments" \
  --jq ".[] | select(.user.login == \"$ME\") | select(.body | startswith(\"## Screenshots\")) | .id" | head -1
```

`{owner}` and `{repo}` are expanded by `gh api`; the PR number is not, so write it in. `--paginate` matters — comments come 30 to a page, and a busy PR's screenshots comment is often not on the first.

- No id found: `gh pr comment <number> --body-file <tmp-comment-file>`.
- Otherwise: `gh api -X PATCH repos/{owner}/{repo}/issues/comments/<comment-id> -F body=@<tmp-comment-file> --jq .html_url`. Use `-F` (which reads a file when the value starts with `@`), not `-f` — `-f` stores the literal string `@<file>` and clobbers the comment with the filename. Re-verify after editing: `gh api repos/{owner}/{repo}/issues/comments/<comment-id> --jq .body | head`.

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

When updating an existing screenshots comment, replace the existing `### <url-path>` block for any page you recaptured; leave other pages' blocks alone.

Return the PR URL.
