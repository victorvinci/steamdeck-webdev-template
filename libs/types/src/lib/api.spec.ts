import { ListUsersQuerySchema, UserSchema, isApiError, type ApiResponse, type User } from './api';

describe('UserSchema', () => {
    it('accepts a valid user', () => {
        const user: User = {
            id: 1,
            name: 'Ada Lovelace',
            email: 'ada@example.com',
            createdAt: '2026-04-12T00:00:00.000Z',
        };
        expect(UserSchema.parse(user)).toEqual(user);
    });

    it('rejects a user with an invalid email', () => {
        expect(() =>
            UserSchema.parse({
                id: 1,
                name: 'Ada',
                email: 'not-an-email',
                createdAt: '2026-04-12T00:00:00.000Z',
            })
        ).toThrow();
    });
});

describe('ListUsersQuerySchema', () => {
    it('applies defaults when fields are missing', () => {
        expect(ListUsersQuerySchema.parse({})).toEqual({ limit: 20, offset: 0 });
    });

    it('coerces string query params to numbers', () => {
        expect(ListUsersQuerySchema.parse({ limit: '5', offset: '10' })).toEqual({
            limit: 5,
            offset: 10,
        });
    });

    it('rejects a limit over 100', () => {
        expect(() => ListUsersQuerySchema.parse({ limit: 500 })).toThrow();
    });
});

describe('isApiError', () => {
    it('narrows success responses', () => {
        const res: ApiResponse<{ ping: string }> = { data: { ping: 'pong' } };
        expect(isApiError(res)).toBe(false);
    });

    it('narrows error responses', () => {
        const res: ApiResponse<{ ping: string }> = { error: 'nope' };
        expect(isApiError(res)).toBe(true);
    });
});
