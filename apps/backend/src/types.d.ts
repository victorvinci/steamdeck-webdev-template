// Load pino-http purely for its module augmentation of `http.IncomingMessage`,
// which is what gives `req.log` its type on Express `Request` objects. Without
// this side-effect import, ts-jest compiling spec files in isolation doesn't
// see `pino-http` (only `main.ts` imports it directly) and rejects `req.log`.
import 'pino-http';
