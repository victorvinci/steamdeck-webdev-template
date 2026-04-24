import type { Request, Response } from 'express';
import { notFound } from './notFound';

describe('notFound', () => {
    it('returns 404 with a body naming method and path', () => {
        const req = { method: 'GET', path: '/api/nope' } as Request;
        const status = jest.fn().mockReturnThis();
        const json = jest.fn().mockReturnThis();
        const res = { status, json } as unknown as Response;

        notFound(req, res);

        expect(status).toHaveBeenCalledWith(404);
        expect(json).toHaveBeenCalledWith({ error: 'Route GET /api/nope not found' });
    });
});
