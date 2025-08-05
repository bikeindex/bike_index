Bike Index is a Rails webapp

[asdf](https://asdf-vm.com/) is used for Ruby and Node version management.

# Development

Start the dev server with `bin/dev`

This will start a dev server at [http://localhost:3042](http://localhost:3042)

## Code style

Ruby is formatted with the standard gem. Run `bin/lint` to automatically format the code.

Code guidelines:

- Code in a functional way. Avoid mutation (side effects) when you can.
- Avoid mutating arguments
- Avoid monkeypatching
- Avoid using view helpers

This project uses Rspec for tests. All business logic should be tested.

- Tests should either: help make the code correct now or prevent bugs in the future. Don't add tests that don't do one of those things.
- Use request specs, not controller specs
- use `context` and `let` to make the differences are between tests clear
- Don't create view specs


### Running Tests

Running the entire spec suite takes too long - only run the specs for specific files. CI will run the whole test suite.

