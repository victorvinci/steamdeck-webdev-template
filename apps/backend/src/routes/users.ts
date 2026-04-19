import { Router } from 'express';
import {
    ListUsersQuerySchema,
    type ApiSuccess,
    type ListUsersQuery,
    type ListUsersResponse,
} from '@mcb/types';
import { validate } from '../middleware/validate';
import { listUsers } from '../services/users.service';

const router = Router();

/**
 * GET /api/users?limit=20&offset=0
 *
 * Validate query params with a shared Zod schema, call the service layer,
 * wrap the result in the `ApiSuccess` envelope. Express 5 auto-forwards
 * rejected promises to `errorHandler` — no manual try/catch needed.
 */
router.get('/users', validate(ListUsersQuerySchema, 'query'), async (_req, res) => {
    const query = res.locals.validatedQuery as ListUsersQuery;
    const result = await listUsers(query);
    const payload: ApiSuccess<ListUsersResponse> = { data: result };
    res.json(payload);
});

export default router;
