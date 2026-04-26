Bike Index is a Rails webapp

[mise](https://mise.jdx.dev/) is used for Ruby and Node version management.

# Development

Start the dev server with `bin/dev`

This will start a dev server at [http://localhost:3042](http://localhost:3042) (or the configured `DEV_PORT` or `CONDUCTOR_PORT`)

## Code style

Ruby is formatted with the standard gem. Run `bin/lint` to automatically format the code.

### Code guidelines:

- Code in a functional way. Avoid mutation (side effects) when you can.
- Don't mutate arguments
- Don't monkeypatch
- make methods private if possible
- Omit named arguments' values from hashes (ie prefer `{x:, y:}` instead of `{x: x, y: y}`)
- Prefer less code, by character count (excluding whitespace and comments). Use `bin/char_count {FILE OR FOLDER}` to get the non-whitespace character count
- prefer un-abbreviated variable names

## Testing

Uses RSpec. All business logic should be tested. The `rspec-testing` skill covers project-specific style (`context`+`let`, request specs over controller specs, avoiding mocks).

## Frontend Development

Uses Stimulus.js for JavaScript and Tailwind CSS for styling. SCSS and CoffeeScript files exist but are deprecated. The `bin/dev` command handles Tailwind and JS builds. The `frontend-conventions` skill covers project-specific class prefixes (`tw:`, `twinput`, `twlabel`, `twlink`), the `number_display` helper, and ViewComponent rules.

## Pull requests

- When creating a PR, run the `/pr` workflow rather than calling `gh pr create` directly — `/pr` detects frontend diffs, captures desktop+mobile screenshots, and embeds them in the PR body.
- To attach a local image (screenshot, .png/.jpg, CleanShot capture) to an existing GitHub PR, the `gh` CLI **cannot upload images** — use the `github-upload-image-to-pr` skill, which drives a real browser to GitHub's user-attachments uploader.

## Architecture notes

- **Multi-database**: primary (`ApplicationRecord`) + analytics (`AnalyticsRecord`). Use `db:migrate:down:analytics` for analytics migrations
- **Soft delete**: some models use `acts_as_paranoid` with `deleted_at` column; use `unscoped` in admin controllers when needed
- **Admin search**: `sortable_search_params` auto-includes any param starting with `search_`

# Initial setup

```bash
bundle install # install ruby dependencies
bundle exec rails db:create db:migrate # create the databases
```
