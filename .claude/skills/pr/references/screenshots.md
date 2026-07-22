# Screenshot phase

Read this after the PR exists (SKILL.md steps 0–3) when the diff is frontend and screenshots are warranted. It carries over `FRONTEND`, `$EXISTING_PR`, and `$PR_NUMBER` from those steps.

The flow: decide what to capture → capture the branch → upload → capture the same URLs on the base branch → post one `## Screenshots` PR comment. Screenshots go in a **comment**, never the PR body, so the human-written summary stays first and recaptures don't churn the description.

## 1. Decide whether screenshots are needed and which URLs to capture

You're only here because `FRONTEND=true` (SKILL.md gates on that before sending you here). Decide scope by PR state:

- New PR → capture every affected page.
- Existing PR → continue only if the captures in the existing screenshots comment are stale: a commit since the last capture touched a page already screenshotted, or a new affected page now appears in the diff. Limit the capture to those pages. If nothing has moved, return the PR URL.

From the changed files, infer the affected routes. Heuristics:
- A view at `app/views/bikes/show.html.erb` → `/bikes/:id` (pick a representative id from the dev db, e.g. `Bike.last.id`)
- A component touched by a specific page → screenshot that page
- A shared component (header, footer, UI::Badge, etc.) → screenshot 1–2 representative pages that exercise it
- A component with a Lookbook preview → its preview URL `/lookbook/preview/<component>/<scenario>` — a real responsive page, captured like any other URL
- Admin views → `/admin/...`
- If unclear, ask the user which URLs to capture before proceeding. Do not guess blindly — 1–3 well-chosen URLs beats 10 random ones.

## 2. Capture branch screenshots

Invoke the `frontend-screenshots` skill with the `(url-path, page-slug)` pairs from step 1. It handles dev-server check, sign-in, the seeded-user identity gate, viewport sizing, and per-PNG sanity checks. It returns local paths under `tmp/pr_screenshots/<branch>-<page>-<timestamp>-{desktop,mobile}.png`.

If `frontend-screenshots` returns failures it couldn't diagnose, surface them and stop — don't post partial screenshots.

## 3. Upload branch screenshots and get inline URLs

Invoke the `github-upload-image-to-pr` skill **for uploading only**: run it through its step 7 (upload each PNG from step 2, read back the `user-attachments/assets/` URLs, clear the textarea) and **stop there — do not run its step 8 posting.** This phase composes and posts one combined before/after comment itself in step 5, so the upload skill must not post its own. GitHub mints persistent URLs that render inline in the browser (release assets would force a download on click).

Collect the returned URLs, keyed by `(page-slug, viewport)`.

## 4. Capture and upload the same URLs on the base branch

Capture the **base-branch** (`$BASE` from SKILL.md step 0.5) version of every screenshot from step 2 so the section becomes a before/after comparison instead of "here's how it looks now." This is the default for every screenshot captured — if you got this far, the diff is frontend, and the comparison is informative (a same-screenshot pair documents visual parity for a refactor; a different pair documents the actual visual change).

Skip per-page only when the URL didn't exist on `$BASE` (a brand-new route or page added in this PR) — there's nothing to compare to.

Re-invoke `frontend-screenshots` with the same `(url-path, page-slug)` pairs and tell it to capture against the base — pass `$BASE` (from SKILL.md step 0.5) as its `BASE_REF` so it checks out `origin/$BASE`, whether or not that's `main` (its "Cross-branch comparison" section checks out the base ref, captures into `...-base-...` filenames, returns to the original branch). Then re-invoke `github-upload-image-to-pr` for those PNGs (upload-only, exactly as in step 3 — collect URLs, do not post).

Caveat for preview URLs: `frontend-screenshots` can't capture the base version of a Lookbook/ViewComponent preview (`/rails/view_components/...`, `/lookbook/...`) — the base checkout leaves the preview route 404ing until `bin/dev` restarts. So for preview-based captures, stay branch-only and say so in the comment rather than posting a mislabeled comparison. Real page URLs compare cleanly against any `$BASE`.

## 5. Post the Screenshots section as a PR comment

On a fresh PR, this comment is naturally the first one. On an update, find the existing screenshots comment (the one authored by you whose body starts with `## Screenshots`) and edit it in place rather than posting a new one:

```bash
SCREENSHOT_COMMENT_ID=$(gh api "repos/{owner}/{repo}/issues/$PR_NUMBER/comments" \
  --jq '.[] | select(.body | startswith("## Screenshots")) | .id' | head -1)
```

`{owner}` and `{repo}` are expanded by `gh api`, but `PR_NUMBER` is not — pass it as the shell variable `$PR_NUMBER` (parsed in SKILL.md step 1 / captured from step 3's create output), not a literal `{PR_NUMBER}`.

- If `$SCREENSHOT_COMMENT_ID` is empty: `gh pr comment "$PR_NUMBER" --body-file <tmp-comment-file>`.
- Otherwise: `gh api -X PATCH repos/{owner}/{repo}/issues/comments/$SCREENSHOT_COMMENT_ID -f body="$(cat <tmp-comment-file>)" --jq .html_url`. Don't use `-f body=@<file>` — `gh api`'s `-f` stores the literal string `@<file>` rather than reading it, so the comment gets clobbered with the filename. Re-verify after editing: `gh api repos/{owner}/{repo}/issues/comments/$SCREENSHOT_COMMENT_ID --jq .body | head`.

**Headers are always `| Desktop | Mobile |`** — that stays the same regardless of whether there's a base-branch comparison. The base-branch shots and branch shots stack as additional rows, with a small indicator row between them when both are present.

Default (with base-branch comparison — put the actual base name from `$BASE`, e.g. `main`, in the indicator row):

```markdown
## Screenshots

### <url-path>

| Desktop | Mobile |
| --- | --- |
| <img src="<base-desktop-url>" width="500"> | <img src="<base-mobile-url>" width="250"> |
| $BASE 👆 | this branch 👇 |
| <img src="<branch-desktop-url>" width="500"> | <img src="<branch-mobile-url>" width="250"> |
```

Brand-new page (URL didn't exist on `$BASE` — see step 4), no comparison row:

```markdown
### <url-path>

| Desktop | Mobile |
| --- | --- |
| <img src="<branch-desktop-url>" width="500"> | <img src="<branch-mobile-url>" width="250"> |
```

Rules:
- Each page gets a `### <url-path>` subheading (the literal path, e.g. `/`, `/bikes/42`, `/admin/strava_activities`) followed by its own table.
- **Every** entry uses this table, with **no exceptions** — including `/lookbook/preview/...` component previews. A preview is a responsive page with a real URL, so it gets the same desktop+mobile before/after cells as any page. A width-invariant component (small icon, fixed-size control) just yields matching desktop and mobile shots — that's expected; keep both columns, never collapse to one image or special-case previews.
- **Headers are always `| Desktop | Mobile |`** — never `| main | this branch |` or any per-PR variation. Reviewers should see the same column meaning across every PR.
- Use `<img src=... width=...>` rather than `![]()` so the widths render predictably in GitHub's table cells. ~500 for desktop, ~250 for mobile fits a side-by-side cell layout cleanly.

When updating an existing screenshots comment, replace the existing `### <url-path>` block for any page you recaptured; leave other pages' blocks alone.

Return the PR URL.

## If the tooling fails

If `frontend-screenshots` or `github-upload-image-to-pr` fails, report the failure clearly and leave the PR without screenshots — don't block PR creation on screenshot tooling.
