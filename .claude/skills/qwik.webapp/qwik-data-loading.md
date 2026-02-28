# Qwik Data Loading

## routeLoader$ — Load Data for a Route
Runs on server before render. Available to any component on the page.
```typescript
// src/routes/products/index.tsx
import { routeLoader$ } from '@builder.io/qwik-city';

export const useProducts = routeLoader$(async ({ env, status, redirect }) => {
  const db = env.get('DATABASE_URL');
  const products = await fetchProducts(db);
  if (!products) {
    throw redirect(302, '/not-found');
  }
  return products;
});

export default component$(() => {
  const products = useProducts();
  return <ul>{products.value.map(p => <li key={p.id}>{p.name}</li>)}</ul>;
});
```

## routeAction$ — Handle Form Submissions
Runs on server when form is submitted.
```typescript
import { routeAction$, zod$, z, Form } from '@builder.io/qwik-city';

export const useAddProduct = routeAction$(
  async (data, { fail }) => {
    const result = await db.insert(data);
    if (!result) return fail(500, { message: 'Insert failed' });
    return { success: true, id: result.id };
  },
  zod$({ name: z.string().min(1), price: z.number().positive() })
);

export default component$(() => {
  const action = useAddProduct();
  return (
    <Form action={action}>
      <input name="name" />
      <input name="price" type="number" />
      <button type="submit">Add</button>
      {action.value?.failed && <p>{action.value.message}</p>}
      {action.value?.success && <p>Added #{action.value.id}</p>}
    </Form>
  );
});
```

## server$ — Ad-Hoc Server Functions
```typescript
import { server$ } from '@builder.io/qwik-city';

const fetchSecret = server$(async function () {
  // `this` is RequestEvent — access env, cookies, headers
  const key = this.env.get('SECRET_KEY');
  return doSecretThing(key);
});

// Call from component like a normal async function
const result = await fetchSecret();
```

## RequestEvent Properties
Available in routeLoader$, routeAction$, server$, onRequest:
| Property | Description |
|---|---|
| `params` | URL parameters |
| `query` | URLSearchParams |
| `headers` | Request headers |
| `cookie` | Cookie get/set/delete |
| `env` | Environment variables |
| `platform` | Platform-specific (e.g., Cloudflare bindings) |
| `url` | Full URL object |
| `method` | HTTP method |
| `redirect(code, url)` | Redirect (throws) |
| `fail(code, data)` | Return error with data |
| `status(code)` | Set status code |
| `sharedMap` | Share data between loaders/middleware |
| `json(code, data)` | JSON response |
| `send(code, body)` | Raw response |

## Validation with Zod
```typescript
import { zod$, z } from '@builder.io/qwik-city';

export const useLogin = routeAction$(
  async (data) => { /* data is typed & validated */ },
  zod$({
    email: z.string().email(),
    password: z.string().min(8),
  })
);
```

## Preference Order
1. `routeLoader$` — for page data (runs before render, SSR-friendly)
2. `server$` — for ad-hoc server calls from event handlers
3. `useResource$` — for client-driven async data (less preferred)
