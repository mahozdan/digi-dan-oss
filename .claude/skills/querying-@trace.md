# @trace Reference: Learning Codebase

## Commands

| Command | Purpose |
|---------|---------|
| `codehound status` | Overview: coverage, stories, critical paths |
| `codehound query "implements X"` | Find code implementing requirement X |
| `codehound query "tests X"` | Find tests for X |
| `codehound query "depends-on X"` | Find what depends on X |
| `codehound query --file path` | Show traces in file |
| `codehound query --untested` | Find code without test traces |
| `codehound diff v1 v2` | Show trace changes between versions |

## Questions → Commands

| Question | Command |
|----------|---------|
| What does this function do? | `codehound query --file path --function name` |
| Where is feature X? | `codehound query "implements STORY-X"` |
| What tests cover this? | `codehound query "tests COMPONENT-X"` |
| What breaks if I change this? | `codehound query "depends-on X"` |
| Why does this code exist? | Check `@trace implements`, `@trace fixes`, `@trace compliance` |
| Is this safe to delete? | `codehound query "depends-on X"` (empty = likely safe) |

## Query Output Examples

Feature query:
```
STORY-DISCOUNT-001
├── implements: src/orders/discount.ts
│   ├── applyDiscountCode() → AC-001.1
│   └── validateCode() → AC-001.2
├── tests: tests/orders/discount.test.ts
└── depends-on: ORDER-SERVICE, DISCOUNT-REPO
```

File query:
```
src/payments/processor.ts
├── @trace implements STORY-PAY-001
├── @trace implements COMPLIANCE-PCI-001
├── Functions:
│   ├── processPayment() → AC-PAY-001.1, AC-PAY-001.2
│   └── handleFailure() → AC-PAY-002.1
├── Tested by: processor.test.ts (14 tests)
└── Depended on by: checkout.ts, billing.ts
```

## Prompting Claude Code

Explain feature:
```
Explain [FEATURE] using @trace annotations in this codebase.
```

Explain function:
```
What does [function]() do? Use its @trace annotations.
```

Find where to change:
```
I need to add [FEATURE]. Where should I make changes based on @trace graph?
```

Explain why:
```
Why does [code] exist? Check @trace annotations.
```

## Reading Traces

```typescript
/**
 * @trace implements PRICING-001      ← Requirement driving this
 * @trace implements AC-PRICE-001.1   ← Specific acceptance criteria
 * @trace depends-on STRIPE-PRICING   ← External dependency
 * @trace fixes BUG-234               ← Historical context
 */
function calculateFee() {}
```

## Onboarding Checklist

- [ ] `codehound status` — see coverage
- [ ] `codehound query --type story` — see all features
- [ ] For task: `codehound query "implements [STORY-ID]"`
- [ ] Before changing: `codehound query --file [path]`
- [ ] Before changing shared code: `codehound query "depends-on [ID]"`
