import type { RowDataPacket } from 'mysql2';
import { db } from '../config/db';
import type { ListUsersQuery, ListUsersResponse, User } from '@mcb/types';

/**
 * Thin data-access layer for the `users` table. Handlers stay dumb; all SQL
 * lives here and uses **named placeholders** (never string concatenation) so
 * input can never escape into a query.
 */

interface UserRow extends RowDataPacket {
    id: number;
    name: string;
    email: string;
    created_at: Date;
}

function toUser(row: UserRow): User {
    return {
        id: row.id,
        name: row.name,
        email: row.email,
        createdAt: row.created_at.toISOString(),
    };
}

export async function listUsers(query: ListUsersQuery): Promise<ListUsersResponse> {
    const [rows] = await db.query<UserRow[]>(
        'SELECT id, name, email, created_at FROM users ORDER BY id ASC LIMIT :limit OFFSET :offset',
        { limit: query.limit, offset: query.offset }
    );

    const [countRows] = await db.query<(RowDataPacket & { total: number })[]>(
        'SELECT COUNT(*) AS total FROM users'
    );

    return {
        users: rows.map(toUser),
        total: Number(countRows[0]?.total ?? 0),
    };
}
