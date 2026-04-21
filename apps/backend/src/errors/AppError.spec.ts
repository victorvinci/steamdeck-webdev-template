import { AppError, BadRequestError, ConflictError, NotFoundError } from './AppError';

describe('AppError', () => {
    it('stores statusCode and message and sets isOperational', () => {
        const err = new AppError(418, "I'm a teapot");
        expect(err.statusCode).toBe(418);
        expect(err.message).toBe("I'm a teapot");
        expect(err.isOperational).toBe(true);
    });

    it('uses the subclass constructor name', () => {
        expect(new BadRequestError().name).toBe('BadRequestError');
        expect(new NotFoundError().name).toBe('NotFoundError');
        expect(new ConflictError().name).toBe('ConflictError');
    });

    it('defaults subclass messages and status codes', () => {
        expect(new BadRequestError()).toMatchObject({ statusCode: 400, message: 'Bad request' });
        expect(new NotFoundError()).toMatchObject({ statusCode: 404, message: 'Not found' });
        expect(new ConflictError()).toMatchObject({ statusCode: 409, message: 'Conflict' });
    });

    it('accepts custom subclass messages', () => {
        expect(new BadRequestError('email required').message).toBe('email required');
    });

    it('is an Error instance (instanceof checks pass)', () => {
        const err = new BadRequestError();
        expect(err).toBeInstanceOf(Error);
        expect(err).toBeInstanceOf(AppError);
        expect(err).toBeInstanceOf(BadRequestError);
    });
});
