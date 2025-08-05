Bike Index is a Rails webapp

[asdf](https://asdf-vm.com/) is used for Ruby and Node version management.

# Development

Start the dev server with `bin/dev`

This will start a dev server at [http://localhost:3042](http://localhost:3042)

## Code style

Ruby is formatted with the standard gem. Run `bin/lint` to automatically format the code.

Code guidelines:

- Code in a functional way. Avoid mutation (side effects) when you can.
- Avoid defensive programming
- Avoid mutating arguments
- Avoid monkeypatching
- Avoid long methods
- Avoid using view helpers

This project uses Rspec for tests. All business logic should be tested.

- Use request specs, not controller specs
- Approach testing from a pragmatic standpoint. Cover things that are confusing or complicated, but don't waste time with overly verbose tests.
- use context and let to make it clear what the differences are between tests
- Don't create view specs


### Running Tests

Running the entire spec suite takes too long - only run the specs for specific files. CI will run the whole test suite.

