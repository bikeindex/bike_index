Bike Index is a Rails webapp

[asdf](https://asdf-vm.com/) is used for Ruby and Node version management.

# Development

Start the dev server with `bin/dev`

This will start a dev server at [http://localhost:3042](http://localhost:3042)

## Code style

Ruby is formatted with the standard gem. Run `bin/lint` to automatically format the code.

### Code guidelines:

- Code in a functional way. Avoid mutation (side effects) when you can.
- Don't mutate arguments
- Don't monkeypatch
- make methods private if possible
- Omit named arguments' values from hashes (ie prefer `{x:, y:}` instead of `{x: x, y: y}`)
- Prefer less code, by character count (excluding whitespace and comments). Use `bin/char_count {FILE OR FOLDER}` to get the non-whitespace character count

## Testing

This project uses Rspec for tests. All business logic should be tested.

- Tests should either: help make the code correct now or prevent bugs in the future. Don't add tests that don't do one of those things.
- Use `context` and `let` to make the differences between tests clear
- Use request specs, not controller specs. Everything making the same request should be in a single test
- Avoid testing private methods
- Avoid mocking objects

### Running Tests

Run tests with turbo_tests:

```bash
bundle exec turbo_tests
# Or, to run just specific tests
bundle exec turbo_tests {FILE OR FOLDER}
```

## Frontend Development

This project uses Stimulus.js for JavaScript interactivity and Tailwind CSS for styling. There are scss styles and coffeescript files, but that is all deprecated.

The `bin/dev` command handles building and updating tailwind and JS.

- Tailwind classes have the prefix `tw:` (e.g. `tw:text-blue`)
- Form fields should use the `twinput` class
- labels should use the `twlabel` class
- basic links should use the `twlink` class

This project also uses the ViewComponent gem to render components.

- Prefer view components to partials
- Generate a new view component with `rails generate component ComponentName argument1 argument2`
- View components must initialize with keyword arguments

# Initial setup

```bash
bundle install # install ruby dependencies
bundle exec rails db:create db:migrate # create the databases
```
