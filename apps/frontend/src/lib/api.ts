import axios, { AxiosError } from 'axios';
import { env } from './env';

export const api = axios.create({
    baseURL: env.VITE_API_URL,
    withCredentials: true,
    headers: {
        'Content-Type': 'application/json',
    },
});

api.interceptors.request.use((config) => {
    config.headers.set('x-request-id', crypto.randomUUID());
    return config;
});

api.interceptors.response.use(
    (res) => res,
    (error: AxiosError) => {
        const reqId =
            error.response?.headers?.['x-request-id'] ?? error.config?.headers?.['x-request-id'];
        if (reqId) {
            console.error(`[api] request failed (x-request-id=${reqId})`, error.message);
        }
        return Promise.reject(error);
    }
);
