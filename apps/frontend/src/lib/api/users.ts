import { useQuery } from '@tanstack/react-query';
import { ListUsersResponseSchema, type ListUsersResponse, type ApiSuccess } from '@mcb/types';
import { api } from '../api';

/**
 * Feature-scoped API wrappers for the Users resource. Components should call
 * these hooks, never `api` directly — it keeps query keys, response shapes,
 * and runtime validation in one place.
 */

export const usersKeys = {
    all: ['users'] as const,
    list: (limit: number, offset: number) => [...usersKeys.all, 'list', { limit, offset }] as const,
};

async function fetchUsers(limit: number, offset: number): Promise<ListUsersResponse> {
    const res = await api.get<ApiSuccess<ListUsersResponse>>('/api/users', {
        params: { limit, offset },
    });
    return ListUsersResponseSchema.parse(res.data.data);
}

export function useUsersQuery(limit = 20, offset = 0) {
    return useQuery({
        queryKey: usersKeys.list(limit, offset),
        queryFn: () => fetchUsers(limit, offset),
    });
}
