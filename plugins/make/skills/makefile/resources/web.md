# Web Development Best Practices

Guidelines for modern web application projects using a Make-centric workflow.

## Make Targets for Web Projects

Extend the standard Make targets with web-specific ones:

```makefile
dev:            ## Start development server (hot reload)
build:          ## Production build
preview:        ## Preview production build locally
ui.test:        ## Component + unit tests (vitest / jest / bun test)
ui.lint:        ## Framework-specific checks (svelte-check / next lint / tsc)
ui.audit:       ## Design system compliance audit
ui.fmt:         ## Format (biome / prettier)
ui.sync:        ## Install dependencies
```

All standard targets (`check`, `test`, `qa`) still apply. `qa` MUST gate `ui.lint + ui.test` at minimum.

---

## CSS Custom Properties

ALWAYS use CSS custom properties (variables) for colors, spacing, and layout tokens. Never hardcode values.

### Three-Tier Variable Hierarchy

```
Tier 1: Semantic application variables (--app-*)
  ↓ maps to
Tier 2: Design system tokens (from your design library)
  ↓ maps to
Tier 3: Raw values (defined once, never used directly in components)
```

**Example:**

```css
:root {
  --app-bg: var(--ds-background);
  --app-surface: var(--ds-surface);
  --app-text: var(--ds-foreground);
  --app-accent: var(--ds-primary);
  --app-border: color-mix(in srgb, var(--app-surface) 72%, var(--app-text));
  --app-text-muted: color-mix(in srgb, var(--app-text) 68%, var(--app-surface));
}
```

Components reference ONLY tier 1:

```css
.card {
  background: var(--app-surface);
  color: var(--app-text);
  border: 1px solid var(--app-border);
}
```

**Benefits:** theme switching (light/dark), design system migration, consistency.

**FORBIDDEN:** hardcoded `#hex`, `rgb()`, `hsl()` in component styles.

---

## Component Architecture

### Directory Structure

```
src/
├── lib/              # Pure TypeScript — utilities, API clients, stores
├── components/       # Reusable UI components
├── styles/
│   ├── theme.css     # Tier 1 semantic variables
│   └── global.css    # Resets, base typography
└── routes/           # Page components (framework-specific)
```

### Component Placement Rules

| Type | Location | Rule |
|:---|:---|:---|
| Design system wrappers | Shared library / package | Wraps raw elements with design tokens |
| Reusable domain components | `src/components/` | Compose library components |
| Page-level components | `src/routes/` (or `pages/`) | Compose domain components |

### Barrel Exports

Export components from `index.ts` in each directory:

```typescript
export { default as Card } from './Card.svelte';
export { default as Table } from './Table.svelte';
```

---

## Accessibility Baseline

Every component MUST meet WCAG 2.1 AA.

### Mandatory Checks

| Check | Rule |
|:---|:---|
| Keyboard navigation | All interactive elements reachable via Tab; activate via Enter/Space |
| Focus visibility | Focus ring on every interactive element (`outline` or `box-shadow`) |
| Color contrast | 4.5:1 for normal text, 3:1 for large text |
| ARIA labels | All icon-only buttons have `aria-label` |
| Semantic HTML | Use `<nav>`, `<main>`, `<section>`, `<article>`, `<aside>` |
| Form labels | Every input has a visible `<label>` or `aria-label` |
| Alt text | Every `<img>` has descriptive `alt` (empty for decorative) |

### Testing Accessibility

```bash
make ui.audit    # should include axe-core or lighthouse checks
```

---

## Performance Patterns

### Lazy Loading

Load below-the-fold components, large visualizations, and admin panels lazily via dynamic imports.

### Image Optimization

- Use `<picture>` with `srcset` for responsive images
- Prefer modern formats: WebP, AVIF
- Always set `width` and `height` to prevent layout shift
- Use `loading="lazy"` for below-fold images

### Bundle Awareness

```bash
make build       # must produce production-optimized bundle
```

- Tree-shake unused library components
- Code-split routes (framework default in SvelteKit, Next.js)
- Monitor bundle size in CI (budget: <200KB JS initial load)

---

## Framework Configuration

### SvelteKit

Use Svelte 5 runes (`$state`, `$derived`, `$effect`) exclusively. Legacy reactive declarations (`$:`) are prohibited. Enable runes globally:

```javascript
compilerOptions: { runes: true }
```

### Static vs Server

| Adapter | Use When |
|:---|:---|
| `adapter-static` | No server-side logic, deploy to CDN |
| `adapter-node` | API proxy, SSR, server routes |

### TypeScript

- Strict mode always (`"strict": true`)
- All function parameters and return types annotated
- Use `lang="ts"` in every `<script>` block
- Biome is the sole formatter and linter for JS/TS/JSON/CSS — ESLint is not used

---

## Design System Integration Pattern

When using a component library (any vendor):

1. **Alias** the library in framework config for clean imports
2. **Wrap** library components in project-specific wrappers only when adding domain logic
3. **Never style** library components with raw CSS — use the library's theming API
4. **Audit** adoption rate: `make ui.audit` checks what percentage of interactive elements use the library

### Container-Child Consistency

Inputs and dropdowns inside themed containers MUST inherit the container background:

```css
.themed-container input,
.themed-container select {
  background: var(--app-surface);
}
```

Never hardcode `white` or `#fff` on form elements inside themed containers — it breaks dark mode.

---

## Testing Web Components

Extends the `testing` skill's TDD workflow:

| Test Type | Tool | Target |
|:---|:---|:---|
| Component rendering | `@testing-library/svelte` (or React/Vue equivalent) | Every component with logic |
| API client functions | `vitest` with `vi.stubGlobal('fetch', ...)` | Happy path + error path |
| E2E user flows | Playwright | Critical user journeys |

### Component Test Pattern

```typescript
import { render, screen } from '@testing-library/svelte';
import MyComponent from './MyComponent.svelte';

test('renders with default props', () => {
  render(MyComponent, { props: { title: 'Hello' } });
  expect(screen.getByText('Hello')).toBeTruthy();
});
```

### API Test Pattern

```typescript
vi.stubGlobal('fetch', vi.fn().mockResolvedValue(
  new Response(JSON.stringify({ data: 'test' }), { status: 200 })
));

const result = await fetchItems();
expect(result.data).toBe('test');
```
