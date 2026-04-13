/**
 * API contracts shared between `apps/frontend` and `apps/backend`.
 *
 * Pattern: Zod schemas are the single source of truth. TypeScript types are
 * inferred from them, so runtime validation and compile-time types can never
 * drift. The backend parses incoming requests with these schemas; the frontend
 * uses the inferred types for fetch responses and forms.
 */
import { z } from 'zod';

export const UserSchema = z.object({
    id: z.number().int().positive(),
    name: z.string().min(1).max(100),
    email: z.string().email(),
    createdAt: z.string().datetime(),
});

export type User = z.infer<typeof UserSchema>;

export const ListUsersQuerySchema = z.object({
    limit: z.coerce.number().int().min(1).max(100).default(20),
    offset: z.coerce.number().int().min(0).default(0),
});

export type ListUsersQuery = z.infer<typeof ListUsersQuerySchema>;

export const ListUsersResponseSchema = z.object({
    users: z.array(UserSchema),
    total: z.number().int().min(0),
});

export type ListUsersResponse = z.infer<typeof ListUsersResponseSchema>;

/**
 * Envelope for every successful API response. Keeps the shape predictable so
 * clients can destructure `.data` without guessing.
 */
export type ApiSuccess<T> = {
    data: T;
};

/**
 * Envelope for every error API response. The backend error handler guarantees
 * this shape; clients can branch on `error` to show user-facing messages.
 */
export type ApiError = {
    error: string;
    issues?: Array<{ path: string; message: string }>;
};

export type ApiResponse<T> = ApiSuccess<T> | ApiError;

export function isApiError<T>(res: ApiResponse<T>): res is ApiError {
    return 'error' in res;
}
