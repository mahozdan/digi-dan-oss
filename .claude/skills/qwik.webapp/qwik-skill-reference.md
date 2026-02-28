# Qwik Skill Reference

## Skill Map

| SDLC Phase | Skill File | Covers |
|---|---|---|
| Init | `qwik/init-new-qwik-project.md` | Project creation, templates, structure, integrations |
| Learn | `qwik/qwik-fundamentals.md` | Resumability, `$` suffix, serialization rules, key imports |
| Routing | `qwik/qwik-routing.md` | File-based routing, params, layouts, navigation, route groups |
| Components | `qwik/qwik-components.md` | Props, slots, DOM refs, lifecycle hooks, inline components |
| State | `qwik/qwik-state-management.md` | useSignal, useStore, useComputed$, useResource$, context |
| Data | `qwik/qwik-data-loading.md` | routeLoader$, routeAction$, server$, zod validation |
| Styling | `qwik/qwik-styling.md` | CSS modules, scoped styles, Tailwind, dynamic classes |
| Middleware | `qwik/qwik-middleware-and-auth.md` | onRequest, plugins, auth patterns, cookies, CORS |
| Integrations | `qwik/qwik-integrations.md` | Qwik React (qwikify$), head/SEO, 3rd-party libs, i18n |
| Testing | `qwik/testing-qwik-apps.md` | Vitest setup, createDOM, Playwright E2E, testing patterns |
| Debugging | `qwik/debugging-qwik-apps.md` | Common errors, serialization issues, SSR vs client |
| Performance | `qwik/qwik-performance.md` | Lazy loading, prefetching, anti-patterns, metrics |
| Deployment | `qwik/qwik-deployment.md` | Adapters, SSG, env vars, Docker, platform notes |
| Migration | `qwik/migrating-react-to-qwik.md` | React→Qwik conversion, API mapping, incremental strategy |

## Task → Skill Lookup

| Task Pattern | Load Skill |
|---|---|
| New Qwik project, scaffold, init | `qwik/init-new-qwik-project.md` |
| Component, props, slot, lifecycle | `qwik/qwik-components.md` |
| Route, page, layout, navigation, link | `qwik/qwik-routing.md` |
| Signal, store, state, context, reactive | `qwik/qwik-state-management.md` |
| Loader, action, form, server$, fetch data | `qwik/qwik-data-loading.md` |
| CSS, style, Tailwind, theme | `qwik/qwik-styling.md` |
| Middleware, auth, cookie, session, plugin | `qwik/qwik-middleware-and-auth.md` |
| React lib, head, SEO, third-party, i18n | `qwik/qwik-integrations.md` |
| Test, spec, vitest, playwright, e2e | `qwik/testing-qwik-apps.md` |
| Bug, error, debug, serialization, QRL | `qwik/debugging-qwik-apps.md` |
| Optimize, lazy, prefetch, bundle, speed | `qwik/qwik-performance.md` |
| Deploy, adapter, SSG, Docker, build | `qwik/qwik-deployment.md` |
| $, resumability, serialization, concepts | `qwik/qwik-fundamentals.md` |
| Migrate, convert, React to Qwik, rewrite | `qwik/migrating-react-to-qwik.md` |

## Multi-Skill Sequences

| Workflow | Load In Order |
|---|---|
| New feature | `qwik-routing` → `qwik-components` → `qwik-data-loading` → `testing-qwik-apps` |
| New page with auth | `qwik-routing` → `qwik-middleware-and-auth` → `qwik-data-loading` |
| Bug fix | `debugging-qwik-apps` → `testing-qwik-apps` |
| Add 3rd-party lib | `qwik-integrations` → `qwik-performance` |
| Ship to production | `qwik-deployment` → `qwik-performance` |
| Migrate React → Qwik | `migrating-react-to-qwik` → `qwik-fundamentals` → `qwik-components` → `qwik-routing` → `qwik-data-loading` |
