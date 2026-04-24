import { render, screen, within } from '@testing-library/react';
import type { User } from '@mcb/types';
import { UsersList } from './UsersList';

const user = (id: number, name: string, email: string): User => ({
    id,
    name,
    email,
    createdAt: '2026-04-12T00:00:00.000Z',
});

describe('UsersList', () => {
    it('renders the empty state as a status region when the list is empty', () => {
        render(<UsersList users={[]} total={0} />);
        const status = screen.getByRole('status');
        expect(status.textContent).toBe('No users yet.');
    });

    it('renders a populated list with plural copy and one <li> per user', () => {
        render(
            <UsersList
                users={[
                    user(1, 'Ada Lovelace', 'ada@example.com'),
                    user(2, 'Grace Hopper', 'grace@example.com'),
                ]}
                total={2}
            />
        );

        const region = screen.getByRole('region', { name: 'Users' });
        expect(within(region).getByText(/Showing 2 of 2 users\./)).toBeTruthy();

        const items = within(region).getAllByRole('listitem');
        expect(items).toHaveLength(2);
        expect(items[0].textContent).toContain('Ada Lovelace');
        expect(items[0].textContent).toContain('ada@example.com');
        expect(items[1].textContent).toContain('Grace Hopper');
    });

    it('uses singular copy when total is exactly 1', () => {
        render(<UsersList users={[user(1, 'Ada', 'ada@example.com')]} total={1} />);
        expect(screen.getByText(/Showing 1 of 1 user\./)).toBeTruthy();
    });

    it('reflects total independently from the paginated slice', () => {
        render(<UsersList users={[user(1, 'Ada', 'ada@example.com')]} total={42} />);
        expect(screen.getByText(/Showing 1 of 42 users\./)).toBeTruthy();
    });
});
