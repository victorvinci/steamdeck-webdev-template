import type { User } from '@mcb/types';

export type UsersListProps = {
    users: User[];
    total: number;
};

/**
 * Pure presentational component. Takes already-fetched users and renders
 * them — no data-fetching, no error handling, no loading state. That logic
 * lives in the route component that owns the query. Keeps this component
 * trivial to test and story.
 */
export function UsersList({ users, total }: UsersListProps) {
    if (users.length === 0) {
        return <p role="status">No users yet.</p>;
    }

    return (
        <section aria-label="Users">
            <header>
                <p>
                    Showing {users.length} of {total} user{total === 1 ? '' : 's'}.
                </p>
            </header>
            <ul>
                {users.map((u) => (
                    <li key={u.id}>
                        <strong>{u.name}</strong> — <span>{u.email}</span>
                    </li>
                ))}
            </ul>
        </section>
    );
}
