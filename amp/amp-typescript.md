# WSO2 Agent Manager — TypeScript / React Coding Standard

> **Applies to:** `console/` (`amp-console`)
> **Stack:** TypeScript, React 19, Vite, Rush monorepo, pnpm, React Query, Oxygen UI / MUI, Emotion

---

## Table of Contents

1. [Monorepo Structure](#1-monorepo-structure)
2. [TypeScript Rules](#2-typescript-rules)
3. [Component Conventions](#3-component-conventions)
4. [State Management](#4-state-management)
5. [API Client Patterns](#5-api-client-patterns)
6. [Routing](#6-routing)
7. [Styling](#7-styling)
8. [Forms](#8-forms)
9. [Testing](#9-testing)
10. [Tooling & Build](#10-tooling--build)
11. [Hard Rules — Never Do This](#11-hard-rules--never-do-this)

---

## 1. Monorepo Structure

The console is a **Rush monorepo** managed with **pnpm**. Respect workspace boundaries strictly.

```
console/workspaces/
├── apps/
│   └── webapp/           # App shell: RootRouter, OxygenLayout, entry point
├── pages/
│   ├── overview/         # Dashboard / landing
│   ├── build/            # Agent build workflow
│   ├── deploy/           # Deployment management
│   ├── eval/             # Evaluation monitors & evaluators
│   └── traces/           # Observability & trace viewer
└── libs/
    ├── api-client/       # React Query hooks + generated API types
    ├── auth/             # Asgardio auth provider and hooks
    ├── types/            # Shared TypeScript types and route maps
    ├── views/            # Shared UI components + theme (PageLayout, DrawerWrapper, …)
    └── shared-component/ # Additional reusable components
```

### Workspace Dependency Rules

```
apps/webapp  →  pages/*  →  libs/*
```

- Code specific to one page **stays in `pages/<page>/`**.
- Code shared by **two or more pages** moves to `libs/`.
- **`libs/` must never import from `pages/`** — this creates a circular dependency and breaks the Rush build.
- **`pages/` must never import from another `pages/`** package.

### Scaffolding New Pages

Always use the Rush generator — never create page packages manually:

```bash
rush create-page
```

---

## 2. TypeScript Rules

### Strictness

`strict: true` is non-negotiable. The compiler must produce zero errors and zero `any` escapes before a PR is opened.

```jsonc
// tsconfig.json — do not weaken these
{
  "compilerOptions": {
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true
  }
}
```

### `any` Policy

- Do not use `any`.
- Use `unknown` for genuinely unknown values; narrow the type before use.
- If wrapping an untyped third-party boundary, isolate it in one adapter file and add a comment with a tracking issue number.

```ts
// Bad
const data: any = response.json();

// Good
const data: unknown = response.json();
if (!isAgentResponse(data)) throw new Error("unexpected response shape");
```

### `interface` vs `type`

- Use `interface` for object shapes (component props, API models, domain entities).
- Use `type` for unions, intersections, and aliases.

```ts
// Good — object shape as interface
interface CreateAgentRequest {
  name: string;
  displayName?: string;
  description?: string;
}

// Good — union as type
type AgentStatus = "active" | "inactive" | "error";
```

### Suppression Comments

Do not use `// @ts-ignore` or `// @ts-expect-error` without a comment referencing a tracking issue:

```ts
// @ts-expect-error — upstream library missing types, tracked in #1234
```

### Exports

- Prefer named exports. Use default exports only for React components (to match the existing pattern).
- Re-export from `index.ts` barrel files in every `libs/` package to keep import paths clean.

---

## 3. Component Conventions

### Functional Components Only

No class components. Hooks are the only mechanism for state and side effects.

```tsx
// Good
const AgentCard: React.FC<AgentCardProps> = ({ agent, onDelete }) => {
  ...
};
export default AgentCard;

// Bad
class AgentCard extends React.Component<AgentCardProps> { ... }
```

### One Component Per File

File name matches the exported component name in PascalCase:

```
AddNewAgent.tsx       → export default AddNewAgent
AgentDetailDrawer.tsx → export default AgentDetailDrawer
```

### Props Interface

Define props in the same file, named `<ComponentName>Props`:

```tsx
interface AddNewAgentProps {
  orgName: string;
  projectName: string;
  onSuccess: () => void;
  onCancel: () => void;
}

const AddNewAgent: React.FC<AddNewAgentProps> = ({ orgName, projectName, onSuccess, onCancel }) => {
  ...
};
```

### Page-Level Layout

Every top-level page component must use `PageLayout` from `@agent-management-platform/views`. Never build custom page chrome.

```tsx
import { PageLayout } from "@agent-management-platform/views";

const AgentsPage: React.FC = () => (
  <PageLayout
    title="Agents"
    breadcrumbs={[{ label: "Projects" }, { label: projectName }, { label: "Agents" }]}
  >
    {/* page content */}
  </PageLayout>
);
```

### Side-Panel / Drawer Forms

Any side-panel form that overlays the page must use `DrawerWrapper` to preserve page context:

```tsx
import { DrawerWrapper } from "@agent-management-platform/views";

<DrawerWrapper open={isOpen} onClose={handleClose} title="Edit Agent">
  <EditAgentForm agentName={agentName} onSuccess={handleClose} />
</DrawerWrapper>
```

---

## 4. State Management

### React Query = Server State

React Query is the **only** mechanism for server state — data fetched from the API. Do not duplicate API data in local `useState`.

```tsx
// Good — server state via React Query
const { data: agents, isLoading } = useListAgents(orgName, projectName);

// Bad — manual fetch + local state
const [agents, setAgents] = useState([]);
useEffect(() => { fetch("/api/agents").then(...).then(setAgents); }, []);
```

### Local UI State

UI-only state (modal open, accordion expanded, selected tab) belongs in `useState` or `useReducer` within the component:

```tsx
const [isDrawerOpen, setIsDrawerOpen] = useState(false);
const [activeTab, setActiveTab] = useState<"config" | "logs">("config");
```

### Forbidden State Libraries

Do not introduce Redux, Zustand, Jotai, Recoil, or any other global state library. The existing pattern of React Query + local state covers all requirements.

---

## 5. API Client Patterns

All API operations are exposed as **React Query hooks** in `libs/api-client/`. This is the only way components may interact with the backend.

### Hook Naming

| Operation | Hook Type | Naming Pattern | Example |
|---|---|---|---|
| Fetch list | `useQuery` | `useList<Resource>` | `useListAgents` |
| Fetch single | `useQuery` | `useGet<Resource>` | `useGetAgent` |
| Create | `useMutation` | `useCreate<Resource>` | `useCreateAgent` |
| Update | `useMutation` | `useUpdate<Resource>` | `useUpdateAgent` |
| Delete | `useMutation` | `useDelete<Resource>` | `useDeleteAgent` |

### Query Key Convention

```ts
// Consistent, hierarchical query keys
queryKey: ['agents', orgName, projectName]
queryKey: ['agents', orgName, projectName, agentName]
queryKey: ['agents', orgName, projectName, agentName, 'model-configs']
```

### Writing a New Hook

1. Add the endpoint to `agent-manager-service/docs/api_v1_openapi.yaml` first.
2. Run the TypeScript model generator script.
3. Add the typed hook following the established pattern:

```ts
// libs/api-client/src/hooks/useAgents.ts

export const useListAgents = (orgName: string, projectName: string) =>
  useQuery({
    queryKey: ['agents', orgName, projectName],
    queryFn: () => agentApi.listAgents(orgName, projectName),
    enabled: Boolean(orgName && projectName),
  });

export const useCreateAgent = (orgName: string, projectName: string) =>
  useMutation({
    mutationFn: (req: CreateAgentRequest) =>
      agentApi.createAgent(orgName, projectName, req),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['agents', orgName, projectName] });
    },
  });
```

**Never** call `fetch`, `axios`, or any HTTP client directly inside a component.

---

## 6. Routing

Routes are defined centrally in `libs/types/` as a route map. Never hardcode path strings in components.

```ts
// libs/types/src/routes.ts
export const Routes = {
  agents: (orgName: string, projectName: string) =>
    `/orgs/${orgName}/projects/${projectName}/agents`,
  agentDetail: (orgName: string, projectName: string, agentName: string) =>
    `/orgs/${orgName}/projects/${projectName}/agents/${agentName}`,
} as const;
```

---

## 7. Styling

### Component Library Priority

1. **`@wso2/oxygen-ui`** — WSO2's design system. Use this first.
2. **`@mui/material`** — MUI base components when Oxygen UI doesn't cover the need.
3. **Emotion** — For custom styling overrides only.

Never create custom button, input, dialog, or layout primitives that duplicate what Oxygen UI or MUI provides.

### Emotion for Overrides

Use `@emotion/styled` for component-level style overrides. Do not use inline `style={{}}` props for anything beyond one-off dynamic values.

```tsx
// Good — styled component
const StyledAgentCard = styled(Card)`
  border-left: 3px solid ${({ theme }) => theme.palette.primary.main};
  padding: ${({ theme }) => theme.spacing(2)};
`;

// Acceptable — single dynamic value
<Box sx={{ opacity: isLoading ? 0.5 : 1 }}>
```

### Theme Values Only

Colours, spacing, and typography must come from the MUI theme. Do not hardcode hex values, pixel sizes, or font weights.

```tsx
// Bad
color: "#1976d2"
padding: "16px"
fontWeight: 700

// Good
color: theme.palette.primary.main
padding: theme.spacing(2)
fontWeight: theme.typography.fontWeightBold
```

### Forbidden

- Tailwind CSS
- CSS Modules (`.module.css`)
- Plain `.css` files
- Global style injections outside the theme

---

## 8. Forms

- Use controlled components for form inputs.
- Validation errors are displayed inline, adjacent to the field — never in a global toast for field-level errors.
- On successful submission, close the drawer/modal and invalidate the relevant React Query cache.
- Use the `DrawerWrapper` pattern for all side-panel forms (see [Component Conventions](#3-component-conventions)).

---

## 9. Testing

### Framework

**Vitest** with `jsdom` environment. Do not introduce Jest.

```ts
// vite.config.ts — existing pattern
test: {
  environment: 'jsdom',
  setupFiles: ['./src/setupTests.tsx'],
}
```

### File Naming

- Component tests: `ComponentName.test.tsx`
- Utility tests: `utilityName.test.ts`
- Co-locate tests with the code they test.

### Structure

```tsx
// Overview.test.tsx
describe('Overview', () => {
  it('renders the page title', () => {
    render(<Overview />, { wrapper: TestProviders });
    expect(screen.getByText('Overview')).toBeInTheDocument();
  });

  it('shows loading state while agents are fetching', () => { ... });

  it('displays empty state when no agents exist', () => { ... });
});
```

### Test Utilities

- Use `@testing-library/react` with `@testing-library/user-event` for interactions.
- Wrap all component renders in `ThemeProvider` from `@mui/material/styles` (already configured in `setupTests.tsx`).
- **Do not test implementation details** — test what the user sees and does.

### Mocking API Calls

Mock React Query hooks at the module level:

```tsx
vi.mock('@agent-management-platform/api-client', () => ({
  useListAgents: vi.fn().mockReturnValue({ data: mockAgents, isLoading: false }),
}));
```

---

## 10. Tooling & Build

| Tool | Purpose |
|---|---|
| `rush build` | Build all workspaces |
| `rush test` | Run all tests |
| `rush lint` | ESLint across all workspaces |
| `rush create-page` | Scaffold a new page workspace |
| `pnpm` | Package manager (never `npm` or `yarn`) |
| `Vite` | Dev server and bundler (never Webpack) |

Do not add new Rush workspaces, Vite plugins, or ESLint rules without discussion. Keep the toolchain surface minimal.

---

## 11. Hard Rules — Never Do This

1. **No class components.** Functional components only.
2. **No direct `fetch` or `axios` calls in components.** All API calls go through `libs/api-client/` hooks.
3. **No importing `pages/*` from `libs/*`.** This is a circular dependency.
4. **No importing one `pages/*` package from another `pages/*` package.**
5. **No new global state libraries.** React Query + `useState` only.
6. **No `any` without a comment referencing a tracking issue.**
7. **No hardcoded colour values, spacing, or font weights.** Use the MUI theme.
8. **No custom primitives that duplicate Oxygen UI / MUI components.**
9. **No manual page package creation.** Use `rush create-page`.
10. **No `npm` or `yarn`.** This repo uses `pnpm` and Rush.
11. **No bypassing the OpenAPI spec.** Generate types from `api_v1_openapi.yaml`.
12. **No `// @ts-ignore` without a tracking issue comment.**

---

*Part of the WSO2 Agent Manager AI coding standards. See also: [`amp-go.md`](./amp-go.md), [`amp-python.md`](./amp-python.md), [`amp-universal.md`](./amp-universal.md)*
