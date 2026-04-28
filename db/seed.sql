-- Local development seed data — applied by `npm run db:reset` after
-- migrations run against a freshly-dropped schema.
--
-- Goals:
--   - Make UsersList non-empty in dev so the frontend renders something
--     useful (the `001_initial.sql` migration already seeds 3 names; this
--     adds a few more so pagination and "+N more" copy can be exercised
--     without writing a Storybook fixture).
--   - Stay idempotent (`INSERT IGNORE`) so re-running the seed doesn't
--     trip the unique constraint on `email` if rows already exist.
--   - Use real-but-deterministic email domains (`example.com`) so we can
--     never accidentally email a real address from the dev environment.
--
-- This file is NOT loaded automatically on first boot. `001_initial.sql`
-- (mirrored in `db/schema.sql`) carries the minimal "give the demo UI
-- something to render" set; this file extends that for hands-on testing.
-- Production deployments must NEVER execute this script — `db:reset`
-- refuses to run when `NODE_ENV=production`.

-- ---------- users ----------

INSERT IGNORE INTO users (id, name, email) VALUES
    (1,  'Ada Lovelace',          'ada@example.com'),
    (2,  'Alan Turing',           'alan@example.com'),
    (3,  'Grace Hopper',          'grace@example.com'),
    (4,  'Margaret Hamilton',     'margaret@example.com'),
    (5,  'Donald Knuth',          'don@example.com'),
    (6,  'Barbara Liskov',        'barbara@example.com'),
    (7,  'Edsger Dijkstra',       'edsger@example.com'),
    (8,  'Linus Torvalds',        'linus@example.com'),
    (9,  'Ken Thompson',          'ken@example.com'),
    (10, 'Dennis Ritchie',        'dennis@example.com'),
    (11, 'Brian Kernighan',       'brian@example.com'),
    (12, 'Niklaus Wirth',         'niklaus@example.com'),
    (13, 'Tony Hoare',            'tony@example.com'),
    (14, 'Frances Allen',         'frances@example.com'),
    (15, 'Adele Goldberg',        'adele@example.com'),
    (16, 'Radia Perlman',         'radia@example.com'),
    (17, 'Yukihiro Matsumoto',    'matz@example.com'),
    (18, 'Anders Hejlsberg',      'anders@example.com'),
    (19, 'Bjarne Stroustrup',     'bjarne@example.com'),
    (20, 'Guido van Rossum',      'guido@example.com'),
    (21, 'James Gosling',         'james@example.com'),
    (22, 'Rich Hickey',           'rich@example.com'),
    (23, 'Joe Armstrong',         'joe@example.com'),
    (24, 'Simon Peyton Jones',    'simon@example.com'),
    (25, 'John McCarthy',         'john@example.com');
