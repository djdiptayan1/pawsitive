import pg from 'pg';
import { ENV } from '../config/env.js';

const { Pool } = pg;

// Used ONLY for raw transactions (SELECT FOR UPDATE SKIP LOCKED)
export const pool = new Pool({
    connectionString: ENV.DATABASE_URL,
    ssl: { rejectUnauthorized: false },
    max: 10,
    idleTimeoutMillis: 30000,
});

pool.on('error', (err) => {
    console.error('❌ Postgres pool error:', err.message);
});