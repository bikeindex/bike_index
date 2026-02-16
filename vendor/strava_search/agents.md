# Agent Guidelines

## Testing Requirements

**Every feature or todo must be accompanied by new or updated tests.**

When implementing a feature or fixing a bug:
1. Write tests before or alongside the implementation
2. Ensure all existing tests still pass
3. Add integration tests for user-facing functionality
4. Add unit tests for utility functions and complex logic

Run tests with:
```bash
npm test
```

Run tests once (CI mode):
```bash
npm run test:run
```
