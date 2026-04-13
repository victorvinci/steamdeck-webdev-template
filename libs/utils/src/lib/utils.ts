/**
 * Runtime-safe error serialization. Accepts anything thrown (Error, string,
 * unknown object, null) and returns a human-readable string without leaking
 * sensitive internals.
 */
export function formatError(err: unknown): string {
    if (err instanceof Error) return err.message;
    if (typeof err === 'string') return err;
    if (err && typeof err === 'object' && 'message' in err) {
        const msg = (err as { message: unknown }).message;
        if (typeof msg === 'string') return msg;
    }
    return 'Unknown error';
}

/**
 * Narrow `T | null | undefined` to `T`. Useful in `.filter(isDefined)` calls
 * so downstream code gets a properly typed array.
 */
export function isDefined<T>(value: T | null | undefined): value is T {
    return value !== null && value !== undefined;
}
