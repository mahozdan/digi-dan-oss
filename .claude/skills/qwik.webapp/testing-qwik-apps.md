# Testing Qwik Apps

## Setup (Vitest)
```bash
npm install -D vitest @builder.io/qwik/testing
```

```typescript
// vite.config.ts
import { defineConfig } from 'vite';
import { qwikVite } from '@builder.io/qwik/optimizer';

export default defineConfig({
  plugins: [qwikVite()],
  test: {
    environment: 'node',
    globals: true,
    include: ['src/**/*.test.{ts,tsx}'],
  },
});
```

## Unit Test — Component
```typescript
import { createDOM } from '@builder.io/qwik/testing';
import { test, expect } from 'vitest';
import { Counter } from './counter';

test('Counter increments', async () => {
  const { screen, render, userEvent } = await createDOM();
  await render(<Counter />);

  expect(screen.querySelector('p')?.textContent).toBe('Count: 0');

  await userEvent('button', 'click');
  expect(screen.querySelector('p')?.textContent).toBe('Count: 1');
});
```

## Unit Test — routeLoader$ / routeAction$
Server functions can't be directly unit tested via createDOM. Test the logic separately:
```typescript
// Extract business logic into pure functions
export async function getProducts(db: DbClient) {
  return db.query('SELECT * FROM products');
}

// Test the function directly
test('getProducts returns products', async () => {
  const mockDb = { query: vi.fn().mockResolvedValue([{ id: 1 }]) };
  const result = await getProducts(mockDb);
  expect(result).toHaveLength(1);
});
```

## E2E Testing (Playwright)
```bash
npm run qwik add playwright
```

```typescript
// tests/e2e/home.spec.ts
import { test, expect } from '@playwright/test';

test('home page loads', async ({ page }) => {
  await page.goto('/');
  await expect(page.locator('h1')).toHaveText('Welcome');
});

test('form submission works', async ({ page }) => {
  await page.goto('/contact');
  await page.fill('input[name="email"]', 'test@test.com');
  await page.click('button[type="submit"]');
  await expect(page.locator('.success')).toBeVisible();
});
```

## Test Scripts
```json
{
  "scripts": {
    "test:unit": "vitest run",
    "test:unit:watch": "vitest",
    "test:e2e": "playwright test",
    "test:e2e:ui": "playwright test --ui"
  }
}
```

## Rules
- Co-locate tests: `component.test.tsx` next to `component.tsx`
- Extract server logic into testable pure functions
- Use createDOM for component behavior tests
- Use Playwright for full flow / SSR verification
- Mock fetch/DB at the function boundary, not inside Qwik internals
