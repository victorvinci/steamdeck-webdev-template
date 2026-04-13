import { z } from 'zod';

const EnvSchema = z.object({
    VITE_API_URL: z.string().url(),
});

const parsed = EnvSchema.safeParse(import.meta.env);

if (!parsed.success) {
    const issues = parsed.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`).join('\n');
    throw new Error(`Invalid frontend env:\n${issues}`);
}

export const env = parsed.data;
