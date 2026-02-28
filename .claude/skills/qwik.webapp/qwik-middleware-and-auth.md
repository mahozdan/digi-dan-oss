# Qwik Middleware & Auth

## Middleware (onRequest)
Define in route layout or page files:
```typescript
// src/routes/layout.tsx
import type { RequestHandler } from '@builder.io/qwik-city';

export const onRequest: RequestHandler = async ({ next, cookie, redirect, sharedMap }) => {
  // Runs before every request under this layout
  const token = cookie.get('session')?.value;
  if (token) {
    const user = await validateToken(token);
    sharedMap.set('user', user); // Share with loaders/components
  }
  await next(); // Continue to route handler
};
```

## HTTP Method Handlers
```typescript
export const onGet: RequestHandler = async ({ json }) => {
  json(200, { message: 'GET response' });
};

export const onPost: RequestHandler = async ({ parseBody, json }) => {
  const body = await parseBody();
  json(201, { created: true });
};
```

## Plugin Files (Global Middleware)
```
src/routes/
├── plugin.ts                  # Runs for ALL routes
├── plugin@auth.ts             # Named plugin (runs for all routes)
├── dashboard/
│   ├── plugin@admin.ts        # Runs for /dashboard/* only
│   └── index.tsx
```

```typescript
// src/routes/plugin@auth.ts
import type { RequestHandler } from '@builder.io/qwik-city';

export const onRequest: RequestHandler = async ({ cookie, redirect, sharedMap, next }) => {
  const session = cookie.get('session');
  if (!session) {
    throw redirect(302, '/login');
  }
  const user = await getUser(session.value);
  sharedMap.set('user', user);
  await next();
};
```

## Auth Pattern: Protected Routes
```
src/routes/
├── plugin.ts              # Set up shared state
├── (public)/              # No auth required
│   ├── login/index.tsx
│   └── signup/index.tsx
├── (protected)/           # Auth required
│   ├── plugin@auth.ts     # Redirect if not logged in
│   ├── dashboard/index.tsx
│   └── settings/index.tsx
```

## Cookie Management
```typescript
export const onRequest: RequestHandler = async ({ cookie }) => {
  // Read
  const token = cookie.get('session')?.value;

  // Set
  cookie.set('session', tokenValue, {
    path: '/',
    httpOnly: true,
    secure: true,
    sameSite: 'strict',
    maxAge: 60 * 60 * 24 * 7, // 1 week
  });

  // Delete
  cookie.delete('session', { path: '/' });
};
```

## Access User in Components
```typescript
// In routeLoader$ — access sharedMap data
export const useUser = routeLoader$(async ({ sharedMap }) => {
  return sharedMap.get('user') as User | null;
});

// In component
const user = useUser();
return user.value ? <p>Hello {user.value.name}</p> : <p>Not logged in</p>;
```

## CORS Middleware
```typescript
export const onRequest: RequestHandler = async ({ headers, next }) => {
  headers.set('Access-Control-Allow-Origin', '*');
  headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  await next();
};
```

## Execution Order
```
plugin.ts → plugin@name.ts → layout onRequest → page onRequest → routeLoader$ → render
```
