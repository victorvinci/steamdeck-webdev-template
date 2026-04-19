import { createFileRoute, Link } from '@tanstack/react-router';

function Home() {
    return (
        <main>
            <h1>Steamdeck Webdev Template</h1>
            <p>
                A full-stack Nx monorepo boilerplate with React, Express, and MySQL — ready to fork
                for new projects.
            </p>

            <h2>What's included</h2>
            <ul>
                <li>React + Vite + TanStack Router frontend</li>
                <li>Express 5 API backend</li>
                <li>Shared TypeScript types &amp; Zod schemas</li>
                <li>Storybook component library</li>
                <li>Full CI/CD pipeline with GitHub Actions</li>
            </ul>

            <p>
                <Link to="/users">View users →</Link> (requires the backend to be running)
            </p>
        </main>
    );
}

export const Route = createFileRoute('/')({
    component: Home,
});
