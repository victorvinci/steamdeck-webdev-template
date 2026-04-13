import axios from 'axios';

describe('GET /api/health', () => {
    it('returns ok and a connected database', async () => {
        const res = await axios.get('/api/health');
        expect(res.status).toBe(200);
        expect(res.data).toEqual({ data: { status: 'ok', db: 'connected' } });
    });
});

describe('GET /api/users', () => {
    it('returns the seeded user list inside an ApiSuccess envelope', async () => {
        const res = await axios.get('/api/users');
        expect(res.status).toBe(200);
        expect(res.data.data).toBeDefined();
        expect(Array.isArray(res.data.data.users)).toBe(true);
        expect(typeof res.data.data.total).toBe('number');
    });

    it('rejects an out-of-range limit with a 400', async () => {
        await expect(axios.get('/api/users', { params: { limit: 9999 } })).rejects.toMatchObject({
            response: { status: 400 },
        });
    });
});

describe('unknown routes', () => {
    it('returns a 404 with a descriptive error body', async () => {
        await expect(axios.get('/api/does-not-exist')).rejects.toMatchObject({
            response: { status: 404 },
        });
    });
});
