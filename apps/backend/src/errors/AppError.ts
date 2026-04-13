/**
 * Base class for expected, operational errors that should be converted into
 * a specific HTTP response. Anything extending `AppError` is treated as safe
 * to surface to clients; everything else is logged as a bug and collapsed to
 * a generic 500.
 */
export class AppError extends Error {
    readonly statusCode: number;
    readonly isOperational = true;

    constructor(statusCode: number, message: string) {
        super(message);
        this.name = this.constructor.name;
        this.statusCode = statusCode;
        Error.captureStackTrace?.(this, this.constructor);
    }
}

export class BadRequestError extends AppError {
    constructor(message = 'Bad request') {
        super(400, message);
    }
}

export class NotFoundError extends AppError {
    constructor(message = 'Not found') {
        super(404, message);
    }
}

export class ConflictError extends AppError {
    constructor(message = 'Conflict') {
        super(409, message);
    }
}
