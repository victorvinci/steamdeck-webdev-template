import { formatError, isDefined } from './utils';

describe('formatError', () => {
    it('returns the message from an Error instance', () => {
        expect(formatError(new Error('boom'))).toBe('boom');
    });

    it('returns the string itself when given a string', () => {
        expect(formatError('plain string')).toBe('plain string');
    });

    it('returns the message from an object with a string message property', () => {
        expect(formatError({ message: 'from object' })).toBe('from object');
    });

    it('falls back to "Unknown error" for null, undefined, and unrelated values', () => {
        expect(formatError(null)).toBe('Unknown error');
        expect(formatError(undefined)).toBe('Unknown error');
        expect(formatError(42)).toBe('Unknown error');
        expect(formatError({ foo: 'bar' })).toBe('Unknown error');
    });
});

describe('isDefined', () => {
    it('returns false for null and undefined', () => {
        expect(isDefined(null)).toBe(false);
        expect(isDefined(undefined)).toBe(false);
    });

    it('returns true for every other value, including 0 and empty string', () => {
        expect(isDefined(0)).toBe(true);
        expect(isDefined('')).toBe(true);
        expect(isDefined(false)).toBe(true);
    });

    it('narrows array element types', () => {
        const mixed: Array<number | null> = [1, null, 2, null, 3];
        const filtered: number[] = mixed.filter(isDefined);
        expect(filtered).toEqual([1, 2, 3]);
    });
});
