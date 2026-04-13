import { Router } from 'express';
import { db } from '../config/db';
import type { ApiSuccess } from '@mcb/types';

const router = Router();

type HealthPayload = { status: 'ok'; db: 'connected' };

router.get('/health', async (req, res) => {
    try {
        await db.query('SELECT 1');
        const payload: ApiSuccess<HealthPayload> = { data: { status: 'ok', db: 'connected' } };
        res.json(payload);
    } catch (err) {
        req.log?.error({ err }, 'Health check db query failed');
        res.status(503).json({ error: 'Database unavailable' });
    }
});

export default router;
