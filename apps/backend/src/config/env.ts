if (process.env['NODE_ENV'] !== 'production') {
    require('dotenv/config');
}
import { z } from 'zod';

const schema = z.object({
    NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
    HOST: z.string().min(1).default('localhost'),
    PORT: z.coerce.number().int().positive().default(3000),
    DB_HOST: z.string().min(1),
    DB_PORT: z.coerce.number().int().positive().default(3306),
    DB_NAME: z.string().min(1),
    DB_USER: z.string().min(1),
    DB_PASSWORD: z.string().min(1),
    DB_CONNECTION_LIMIT: z.coerce.number().int().positive().default(10),
    FRONTEND_URL: z.string().url(),
});

const parsed = schema.safeParse(process.env);

if (!parsed.success) {
    console.error('Invalid environment variables:');
    for (const issue of parsed.error.issues) {
        console.error(`  - ${issue.path.join('.')}: ${issue.message}`);
    }
    process.exit(1);
}

export const env = parsed.data;
export const isProd = env.NODE_ENV === 'production';
