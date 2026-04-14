import { createFileRoute } from '@tanstack/react-router';
import { formatError } from '@mcb/utils';
import { UsersList } from '../components/UsersList';
import { useUsersQuery } from '../lib/api/users';

/**
 * Home route — worked example of the full frontend data-fetching pattern:
 *
 *   - `useUsersQuery` wraps TanStack Query with a typed key factory.
 *   - Response is validated at the boundary with `ListUsersResponseSchema`.
 *   - Loading and error states are rendered inline.
 *   - The presentational `<UsersList>` component receives already-typed data.
 *
 * Copy this structure for every new feature: one hook per resource, one
 * route component that owns the loading/error UI, one pure component that
 * renders the happy path.
 */
function Home() {
    const { data, isPending, isError, error, refetch, isFetching } = useUsersQuery();

    return (
        <main>
            <h1>Steamdeck Webdev Template</h1>
            <p>A minimal full-stack example. The list below is fetched from `/api/users`.</p>

            {isPending && <p role="status">Loading users…</p>}

            {isError && (
                <div role="alert">
                    <p>Could not load users: {formatError(error)}</p>
                    <button type="button" onClick={() => refetch()} disabled={isFetching}>
                        Retry
                    </button>
                </div>
            )}

            {data && <UsersList users={data.users} total={data.total} />}
            <p>CI trigger changes</p>
        </main>
    );
}

export const Route = createFileRoute('/')({
    component: Home,
});
