# test

## Structure
```
{module}.test.{ext}  // co-located
__tests__/{module}.{ext}  // or grouped
```

## Test Format
```
describe('{Module}', () => {
  describe('{method}', () => {
    it('should {expected behavior} when {condition}', () => {
      // Arrange
      // Act  
      // Assert
    });
  });
});
```

## Coverage Requirements
- Happy path: required
- Edge cases: null, empty, boundary values
- Error cases: invalid input, failures
- Min 80% line coverage target

## Rules
- One assertion focus per test
- No test interdependence
- Mock external deps (db, api, fs)
- Descriptive names: `should{Expected}When{Condition}`
- Test behavior, not implementation
- Run tests before commit: `npm test` / `pytest` / etc

## Anti-patterns
- ❌ Testing private methods directly
- ❌ Hardcoded test data paths
- ❌ Sleep/delay in tests
- ❌ Tests that require network
