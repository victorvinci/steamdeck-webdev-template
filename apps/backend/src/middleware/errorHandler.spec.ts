import type { Request, Response, NextFunction } from 'express';

// env.ts parses process.env at import time and process.exit(1)s on failure.
// Mock both env and logger so this spec has no env/NODE_ENV dependency.
jest.mock('../config/env', () => ({ isProd: false, env: { NODE_ENV: 'test' } }));
jest.mock('../config/logger', () => ({
    logger: { error: jest.fn(), warn: jest.fn(), info: jest.fn(), debug: jest.fn() },
}));

import { errorHandler } from './errorHandler';
import { AppError, BadRequestError } from '../errors/AppError';

// Handle to the mocked env module so individual tests can toggle `isProd`.
// ts-jest compiles imports to `const env_1 = require('../config/env')` under
// commonjs, so `env_1.isProd` is looked up at call time — mutating this
// reference affects errorHandler's subsequent evaluations.

const envMock = require('../config/env') as { isProd: boolean };

type MockRes = Response & { status: jest.Mock; json: jest.Mock };

function mockReq() {
    return {
        log: { error: jest.fn(), warn: jest.fn(), info: jest.fn(), debug: jest.fn() },
    } as unknown as Request & { log: { warn: jest.Mock; error: jest.Mock } };
}

function mockRes(): MockRes {
    return {
        status: jest.fn().mockReturnThis(),
        json: jest.fn().mockReturnThis(),
    } as unknown as MockRes;
}

const next: NextFunction = jest.fn();

describe('errorHandler', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        envMock.isProd = false;
    });

    it('AppError subclass → surfaces statusCode and message, logs at warn', () => {
        const err = new BadRequestError('email required');
        const req = mockReq();
        const res = mockRes();

        errorHandler(err, req, res, next);

        expect(res.status).toHaveBeenCalledWith(400);
        expect(res.json).toHaveBeenCalledWith({ error: 'email required' });
        expect(req.log.warn).toHaveBeenCalledTimes(1);
        expect(req.log.error).not.toHaveBeenCalled();
    });

    it('respects custom status on a bare AppError', () => {
        const err = new AppError(418, "I'm a teapot");
        const req = mockReq();
        const res = mockRes();

        errorHandler(err, req, res, next);

        expect(res.status).toHaveBeenCalledWith(418);
        expect(res.json).toHaveBeenCalledWith({ error: "I'm a teapot" });
    });

    it('unknown error in non-prod → 500 with the error message and logs at error', () => {
        const err = new Error('boom');
        const req = mockReq();
        const res = mockRes();

        errorHandler(err, req, res, next);

        expect(res.status).toHaveBeenCalledWith(500);
        expect(res.json).toHaveBeenCalledWith({ error: 'boom' });
        expect(req.log.error).toHaveBeenCalledTimes(1);
    });

    it('unknown error in prod → redacts the message to a generic string', () => {
        envMock.isProd = true;
        const err = new Error('internal SQL dump');
        const req = mockReq();
        const res = mockRes();

        errorHandler(err, req, res, next);

        expect(res.status).toHaveBeenCalledWith(500);
        expect(res.json).toHaveBeenCalledWith({ error: 'Internal server error' });
    });

    it('falls back to the module logger when req.log is missing', () => {
        const err = new Error('headless');
        const req = {} as Request;
        const res = mockRes();

        expect(() => errorHandler(err, req, res, next)).not.toThrow();
        expect(res.status).toHaveBeenCalledWith(500);
    });

    it('non-Error thrown values still surface a 500', () => {
        const req = mockReq();
        const res = mockRes();

        errorHandler('just a string', req, res, next);

        expect(res.status).toHaveBeenCalledWith(500);
        expect(res.json).toHaveBeenCalledWith(
            expect.objectContaining({ error: expect.any(String) })
        );
    });
});
