import { Router } from 'express';
import { ListUsersQuerySchema, type ApiSuccess, type ListUsersResponse } from '@mcb/types';
import { validate } from '../middleware/validate';
import { listUsers } from '../services/users.service';

const router = Router();

/**
 * GET /api/users?limit=20&offset=0
 *
 * Full pattern: validate query params with a shared Zod schema, call the
 * service layer, wrap the result in the `ApiSuccess` envelope. Errors bubble
 * to `errorHandler` via `next`.
 */
router.get('/users', validate(ListUsersQuerySchema, 'query'), async (req, res, next) => {
    try {
        const result = await listUsers(req.query as unknown as import('@mcb/types').ListUsersQuery);
        const payload: ApiSuccess<ListUsersResponse> = { data: result };
        res.json(payload);
    } catch (err) {
        next(err);
    }
});

export default router;
