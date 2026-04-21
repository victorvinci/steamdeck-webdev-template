import { Router } from 'express';
import { db } from '../config/db';
import type { ApiSuccess } from '@mcb/types';

const router = Router();

type LivePayload = { status: 'ok' };
type ReadyPayload = { status: 'ok'; db: 'connected' };

/**
 * Liveness vs readiness split (Kubernetes-style, but applies to any orchestrator):
 * - `/live` answers "is the process alive?" — no dependencies touched. A failing
 *   `/live` means the process is wedged and should be restarted.
 * - `/ready` answers "should traffic be routed here?" — pings the DB pool. A
 *   failing `/ready` means the instance is running but can't serve requests;
 *   the orchestrator should stop routing traffic without restarting the pod.
 * - `/health` is kept as an alias of `/ready` so existing platform probes
 *   (and this repo's own Playwright webServer wait) keep working. Prefer the
 *   explicit `/live` or `/ready` path in new code.
 */
router.get('/health/live', (_req, res) => {
    const payload: ApiSuccess<LivePayload> = { data: { status: 'ok' } };
    res.json(payload);
});

const handleReady = async (req: import('express').Request, res: import('express').Response) => {
    try {
        await db.query('SELECT 1');
        const payload: ApiSuccess<ReadyPayload> = { data: { status: 'ok', db: 'connected' } };
        res.json(payload);
    } catch (err) {
        req.log?.error({ err }, 'Readiness check db query failed');
        res.status(503).json({ error: 'Database unavailable' });
    }
};

router.get('/health/ready', handleReady);
router.get('/health', handleReady);

export default router;
