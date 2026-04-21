import { vi, describe, it, expect, beforeEach } from 'vitest';
import { api } from '../api';
import { fetchUsers, usersKeys } from './users';

// vitest hoists vi.mock calls above imports at transform time, so this still
// intercepts `api` before `./users` captures its `api.get` reference.
// Stand in for the shared axios instance so neither the network nor the real
// env (which requires VITE_API_URL) is touched.
vi.mock('../api', () => ({
    api: { get: vi.fn() },
}));

const mockedGet = api.get as unknown as ReturnType<typeof vi.fn>;

describe('usersKeys', () => {
    it('builds stable, structurally-compared query keys', () => {
        expect(usersKeys.all).toEqual(['users']);
        expect(usersKeys.list(20, 0)).toEqual(['users', 'list', { limit: 20, offset: 0 }]);
        expect(usersKeys.list(10, 5)).toEqual(['users', 'list', { limit: 10, offset: 5 }]);
    });
});

describe('fetchUsers', () => {
    beforeEach(() => {
        mockedGet.mockReset();
    });

    it('forwards limit/offset as query params and returns Zod-parsed data', async () => {
        mockedGet.mockResolvedValueOnce({
            data: {
                data: {
                    users: [
                        {
                            id: 1,
                            name: 'Ada Lovelace',
                            email: 'ada@example.com',
                            createdAt: '2026-04-12T00:00:00.000Z',
                        },
                    ],
                    total: 1,
                },
            },
        });

        const result = await fetchUsers(20, 0);

        expect(mockedGet).toHaveBeenCalledWith('/api/users', { params: { limit: 20, offset: 0 } });
        expect(result.total).toBe(1);
        expect(result.users[0].email).toBe('ada@example.com');
    });

    it('throws when the backend returns a user with a non-numeric id', async () => {
        mockedGet.mockResolvedValueOnce({
            data: {
                data: {
                    users: [{ id: 'not-a-number', name: 'Ada', email: 'ada@example.com' }],
                    total: 1,
                },
            },
        });

        await expect(fetchUsers(20, 0)).rejects.toThrow();
    });

    it('throws when createdAt is not an ISO string', async () => {
        mockedGet.mockResolvedValueOnce({
            data: {
                data: {
                    users: [
                        {
                            id: 1,
                            name: 'Ada',
                            email: 'ada@example.com',
                            createdAt: 'yesterday',
                        },
                    ],
                    total: 1,
                },
            },
        });

        await expect(fetchUsers(20, 0)).rejects.toThrow();
    });

    it('throws when total is missing', async () => {
        mockedGet.mockResolvedValueOnce({
            data: { data: { users: [] } },
        });

        await expect(fetchUsers(20, 0)).rejects.toThrow();
    });
});
