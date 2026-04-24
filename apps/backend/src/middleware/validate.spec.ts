import type { Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { validate } from './validate';

type MockRes = Response & {
    status: jest.Mock;
    json: jest.Mock;
    locals: Record<string, unknown>;
};

function mockRes(): MockRes {
    const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn().mockReturnThis(),
        locals: {},
    } as unknown as MockRes;
    return res;
}

const schema = z.object({ name: z.string().min(1) });

describe('validate', () => {
    it('writes parsed body to res.locals.validatedBody and calls next', () => {
        const req = { body: { name: 'ada' } } as Request;
        const res = mockRes();
        const next = jest.fn() as unknown as NextFunction;

        validate(schema)(req, res, next);

        expect(res.locals.validatedBody).toEqual({ name: 'ada' });
        expect(next).toHaveBeenCalledTimes(1);
        expect(res.status).not.toHaveBeenCalled();
    });

    it('writes parsed query to res.locals.validatedQuery', () => {
        const req = { query: { name: 'ada' } } as unknown as Request;
        const res = mockRes();
        const next = jest.fn() as unknown as NextFunction;

        validate(schema, 'query')(req, res, next);

        expect(res.locals.validatedQuery).toEqual({ name: 'ada' });
        expect(next).toHaveBeenCalledTimes(1);
    });

    it('writes parsed params to res.locals.validatedParams', () => {
        const req = { params: { name: 'ada' } } as unknown as Request;
        const res = mockRes();
        const next = jest.fn() as unknown as NextFunction;

        validate(schema, 'params')(req, res, next);

        expect(res.locals.validatedParams).toEqual({ name: 'ada' });
        expect(next).toHaveBeenCalledTimes(1);
    });

    it('returns 400 with structured issues on validation failure and does not call next', () => {
        const req = { body: { name: '' } } as Request;
        const res = mockRes();
        const next = jest.fn() as unknown as NextFunction;

        validate(schema)(req, res, next);

        expect(res.status).toHaveBeenCalledWith(400);
        expect(res.json).toHaveBeenCalledWith(
            expect.objectContaining({
                error: 'Validation failed',
                issues: expect.arrayContaining([expect.objectContaining({ path: 'name' })]),
            })
        );
        expect(next).not.toHaveBeenCalled();
    });

    it('does not mutate req[source] — extra fields stripped by schema stay on req.body, parsed data only on res.locals', () => {
        const body = { name: 'ada', extraField: 'should-stay-on-req' };
        const req = { body } as Request;
        const res = mockRes();
        const next = jest.fn() as unknown as NextFunction;

        validate(schema)(req, res, next);

        expect(req.body).toBe(body);
        expect((req.body as Record<string, unknown>).extraField).toBe('should-stay-on-req');
        expect(res.locals.validatedBody).toEqual({ name: 'ada' });
    });
});
