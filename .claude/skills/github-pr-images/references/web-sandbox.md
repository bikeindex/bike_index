# The Claude Code web sandbox: capture, don't post

No route from here puts an image in a PR. `gh` is missing or refused, so nothing can
`--attach`, and the GitHub MCP comment tools rewrite every image and link URL they're
handed: `<img>` escaped to `&lt;img`, `![](url)` losing its `!`, links and bare URLs
wrapped in backticks. It's a filter in the session's tooling, not an escaping slip;
no body form gets past it (#4474, #4792, #4821), and disguising
the URLs to dodge it isn't an option.

So in the sandbox this skill **posts nothing and commits nothing**:

- No `## Screenshots` comment — not a placeholder, not a list of paths or URLs. An
  existing one is left as it is.
- No image commits on the PR branch, which only lengthen its history for links that
  can't render.

Leave the PNGs in `tmp/pr_screenshots/` (the app opens files in the working
directory) and tell the user, listing each file with its full path:

> Screenshots can't be posted from a cloud session — its GitHub tools turn image URLs
> into plain text. They're in `tmp/pr_screenshots/`; drag them into the PR's
> `## Screenshots` comment, or rerun the screenshots step from a local checkout with `gh`.

The container is reclaimed when the session ends, so say the files go with it.
