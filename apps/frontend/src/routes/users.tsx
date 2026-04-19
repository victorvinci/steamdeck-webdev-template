import { createFileRoute } from '@tanstack/react-router';
import { formatError } from '@mcb/utils';
import { UsersList } from '../components/UsersList';
import { useUsersQuery } from '../lib/api/users';

/**
 * Users route — worked example of the full frontend data-fetching pattern:
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
function UsersPage() {
    const { data, isPending, isError, error, refetch, isFetching } = useUsersQuery();

    return (
        <main>
            <h1>Users</h1>
            <p>
                Fetched from the backend API at <code>/api/users</code>.
            </p>

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
        </main>
    );
}

export const Route = createFileRoute('/users')({
    component: UsersPage,
});
