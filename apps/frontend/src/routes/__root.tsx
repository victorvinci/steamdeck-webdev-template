import { createRootRouteWithContext, Link, Outlet, useRouter } from '@tanstack/react-router';
import { QueryClient } from '@tanstack/react-query';

interface RouterContext {
    queryClient: QueryClient;
}

function RootErrorComponent({ error }: { error: Error }) {
    const router = useRouter();

    return (
        <main>
            <h1>Something went wrong</h1>
            <p>{error.message}</p>
            <button type="button" onClick={() => router.invalidate()}>
                Try again
            </button>
        </main>
    );
}

function NotFoundComponent() {
    return (
        <main>
            <h1>Page not found</h1>
            <p>The page you were looking for does not exist.</p>
            <Link to="/">Go home</Link>
        </main>
    );
}

export const Route = createRootRouteWithContext<RouterContext>()({
    component: () => <Outlet />,
    errorComponent: RootErrorComponent,
    notFoundComponent: NotFoundComponent,
});
