# WSO2 Enterprise — TypeScript / React Coding Standard

> **Scope:** All WSO2 frontend applications and React component libraries across all repositories.
> Project-specific guides layer on top and win on conflict.

---

## 1. Language and Tooling Baseline

| Concern | WSO2 Standard |
|---|---|
| Language | TypeScript (strict mode) |
| UI Framework | React (functional components only) |
| Design System | **Oxygen UI (`@wso2/oxygen-ui` / `@oxygen-ui/react`)** — use this first |
| Component Library | MUI (`@mui/material`) — when Oxygen UI doesn't cover the need |
| Build Tool | Vite (new projects) or Webpack (legacy) |
| Package Manager | pnpm (new projects) or npm (legacy) |
| Monorepo | Rush (WSO2 standard for multi-package frontend repos) |
| Formatter | ESLint with `@typescript-eslint` |

---

## 2. TypeScript Rules

### Strict Mode
`"strict": true` in all `tsconfig.json` files. This enables `noImplicitAny`, `strictNullChecks`, and all related checks. Do not weaken this.

### No `any`
Use `unknown` for genuinely untyped values and narrow before use. If wrapping an untyped third-party boundary, isolate it in an adapter file and add a comment.

### `interface` vs `type`
- `interface` for object shapes — component props, API models, domain entities.
- `type` for unions, intersections, and aliases.

### Exports
Default exports are preferred for React components to maintain a uniform import/export structure and reduce naming conflicts.

```tsx
// Good — default export for components
const AgentList: React.FC<AgentListProps> = (props) => { ... };
export default AgentList;
```

---

## 3. Component Conventions

### Functional Components Only
No class components.

### Props Interface
Named `<ComponentName>Props`, defined in the same file as the component.

### `data-componentid` Attribute
All components must accept and propagate a `data-componentid` attribute (via `IdentifiableComponentInterface` or equivalent). This enables resilient test selection without coupling tests to text content or CSS classes.

```tsx
interface AgentCardProps {
  agent: Agent;
  "data-componentid"?: string;
}

const AgentCard: React.FC<AgentCardProps> = ({ agent, "data-componentid": componentId = "agent-card" }) => (
  <Card data-componentid={componentId}>
    ...
  </Card>
);
```

### Component File Structure
One component per file. File name matches component name in PascalCase.

---

## 4. State Management

WSO2 frontend applications historically use **Redux** for global application state (auth state, config, user session). New WSO2 projects may adopt React Query for server state.

- Redux: `useSelector` to read, `useDispatch` to dispatch — never access the store directly.
- Server state (API data): fetched via custom hooks, not stored in Redux.
- Local UI state: `useState` or `useReducer` within the component.

---

## 5. Design System

**Oxygen UI is the standard WSO2 design system.** Always use Oxygen UI components before reaching for raw MUI.

- Do not build custom button, input, modal, or layout primitives that duplicate Oxygen UI.
- When Oxygen UI lacks a component, use MUI directly.
- All colour values, spacing, and typography come from the MUI/Oxygen UI theme — no hardcoded hex values.
- Styling: Emotion (`@emotion/styled`) for component-level overrides; SCSS modules for legacy codebases.
- Do not introduce Tailwind CSS.

---

## 6. Internationalization (i18n)

WSO2 frontend applications support multiple languages using `i18next` and `react-i18next`.

- All user-visible strings go through the i18n system — no hardcoded English strings in JSX.
- Translation keys follow a hierarchical namespace pattern matching the feature structure.
- TypeScript interfaces enforce type-safe access to translation keys.

---

## 7. API Client Patterns

- API interactions are abstracted into custom hooks or a dedicated API class — never called directly from components.
- All API responses are typed with TypeScript interfaces generated from or consistent with the backend OpenAPI spec.
- The `data-componentid` attribute convention extends to identifying API response sources in error messages.

---

## 8. Testing

### Frameworks
- **Jest** — unit test runner (standard across WSO2 frontend projects).
- **React Testing Library** — component testing.
- **Cypress** — end-to-end integration tests.
- `msw` — API mocking.

### File Structure
- Test files live in a `__tests__/` directory adjacent to the code under test.
- File naming: `<ComponentName>.test.tsx` or `<ComponentName>.test.ts`.

### Conventions
- Prefer `data-componentid` selectors over text content selectors for resilience.
- Use a custom `render` wrapper that provides Redux store, theme, and i18n providers.
- Snapshot tests for UI components that must not change unexpectedly.
- Mock API calls with `msw`.

---

## 9. Code Quality

- ESLint with `@typescript-eslint` is mandatory — no PR with lint errors.
- 4-space indentation (enforced by ESLint across WSO2 products).
- Single quotes for JSX attributes (`jsx-quotes: prefer-single`).
- Destructuring assignment for props is enforced.
- `prop-types` is disabled for TypeScript files — use TypeScript types.

---

*WSO2 TypeScript/React base standard. See project-specific guide for overrides and additions.*
