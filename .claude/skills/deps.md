# deps

## Don't add dependencies if
1. Another existing dependency already solves the issue 
2. It is a minor effort to do it yourself

## Selection Criteria (weighted)
1. **Maintenance** (30%): commits last 6mo, open issues ratio, bus factor
2. **Security** (25%): known vulns, audit history, CVE response time
3. **Fit** (20%): solves exact need, no bloat
4. **Adoption** (15%): downloads, GitHub stars, SO questions
5. **Size** (10%): bundle impact, tree-shaking support
6. Prefer dependencies which are base, i.e. that don't have many sub-dependencies
7. MIT liscence or compatible open source allowing commercial use is a MUST

## Checklist Before Adding
- [ ] Can stdlib solve this?
- [ ] Is there a lighter alternative?
- [ ] License compatible? (MIT/Apache preferred)
- [ ] TypeScript types available?
- [ ] Check: `npm audit` / `snyk test`
- [ ] Bundle size: bundlephobia.com

## Commands
```bash
# Analyze before install
npm view {pkg} 
npm audit
npx bundlephobia {pkg}

# Install
npm i {pkg}           # prod
npm i -D {pkg}        # dev only
```

## Rules
- Pin major versions: `^x.0.0`
- Document why in code comment if non-obvious
- Prefer deps with zero/few sub-deps
- Review transitive dependencies
- One dep per concern—no overlapping utilities

## Red Flags
- ❌ No updates >1 year
- ❌ Sole maintainer + critical path
- ❌ Excessive transitive deps
- ❌ Minified source only
