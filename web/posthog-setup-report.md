# PostHog setup report

PostHog analytics was installed and initialized for the Next.js storefront, with five anonymous browser events, global error capture, and a starter dashboard configured in project 534303.

## What was installed and initialized

- Added `posthog-js@^1.408.0` and `posthog-node@^5.46.1` using Bun; the lockfile was saved successfully.
- Browser initialization is centralized in `instrumentation-client.ts`. It reads `NEXT_PUBLIC_POSTHOG_PROJECT_TOKEN` and `NEXT_PUBLIC_POSTHOG_HOST`, initializes PostHog once, keeps default capture behavior, enables exception capture, and uses development-only debug logging.
- The real public token and host were configured in `.env.local` through the wizard environment tools. The variable names are documented in `.env.example`.
- No server-side capture was added. The installed Node SDK is available for future server route instrumentation.

## Events instrumented

| Event | What it measures | File |
|---|---|---|
| `contact_form_submitted` | Visitor submits the contact form; this measures submit intent, not confirmed delivery to the external endpoint. | `src/modules/form-module/contact.tsx` |
| `site_search_performed` | Completed on-site search, segmented by scope, query length, and result count. Search text itself is not captured. | `src/modules/search-module/search-form.tsx` |
| `blog_category_filtered` | Visitor changes the blog category filter. | `src/ui/blog/filter.tsx` |
| `blog_sort_changed` | Visitor changes the blog listing sort order. | `src/modules/blog-index/sort-by.tsx` |
| `blog_page_changed` | Visitor navigates between pages of the blog listing. | `src/hooks/usePagination.tsx` |

The capture step verified that calls were placed in the real submit, completed-search, filter, sort, and pagination handlers. The run did **not** browser-test delivery, so no event should be considered observed in PostHog yet.

## Identification and privacy

User identification was skipped. The storefront has no application-owned login, signup, logout, session, authenticated user state, or stable user identifier. Captures therefore remain anonymous/personless and contain no PII. If authentication is added later, wire `identify()` at the stable non-PII identity boundary and `reset()` on logout; server captures should use the authenticated request identity.

## Error tracking

Added `src/app/global-error.tsx`, a client global error boundary that calls `posthog.captureException(error)` once for the boundary error and preserves the retry action through `reset()`. The browser initialization also enables exception capture. The run verified the implementation and build compatibility, but did not trigger an application error and therefore did not observe an exception arrive in PostHog.

## Dashboard

[Analytics basics (wizard)](https://us.posthog.com/project/534303/dashboard/1926565) contains four saved trends insights covering contact submissions, searches by scope, category filters, and combined blog sorting/pagination activity. It is configured to populate as events arrive; the run did not confirm populated event observations.

## Verification and unresolved issues

- `bun install` completed with no changes.
- `bun run build` completed successfully, including compilation, typechecking, and static page generation.
- `bun run typecheck` completed successfully.
- Environment checks confirmed `NEXT_PUBLIC_POSTHOG_PROJECT_TOKEN` and `NEXT_PUBLIC_POSTHOG_HOST` are present.
- Event delivery was not browser-tested, so capture flow and dashboard population remain unconfirmed.
- The existing `bun run lint` script fails because it invokes obsolete `next lint`; Next.js 16 treats `lint` as a directory. This is unrelated to the PostHog changes and remains unresolved. The successful build also emitted pre-existing CSS parser diagnostics for experimental scroll pseudo-elements.

## Before you merge

- [ ] Run a full production build again and fix any lint or type errors introduced by the generated integration; review `instrumentation-client.ts` and `src/app/global-error.tsx`.
- [ ] Run the test suite and update mocks or fixtures for the instrumented handlers in `src/modules/form-module/contact.tsx`, `src/modules/search-module/search-form.tsx`, `src/ui/blog/filter.tsx`, `src/modules/blog-index/sort-by.tsx`, and `src/hooks/usePagination.tsx` if needed.
- [ ] Set `NEXT_PUBLIC_POSTHOG_PROJECT_TOKEN` and `NEXT_PUBLIC_POSTHOG_HOST` in every deploy environment, not only `.env.local`; keep the exact names documented in `.env.example`.
- [ ] Trigger each instrumented browser path and confirm the five event names appear in PostHog; especially verify that `contact_form_submitted` represents intent rather than external form delivery.
- [ ] Decide how the obsolete `next lint` script should be replaced before relying on lint as a release check; this is an existing project conflict, not an integration failure.
