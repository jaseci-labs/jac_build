"""jac.build — 404."""

import from "@jac/runtime" { Link }

def:pub page -> JsxPage {
    return
        <div
            className="mx-auto flex w-full max-w-xl flex-col items-center gap-4 px-4 py-24 text-center"
        >
            <p className="font-mono-brand text-6xl font-bold text-primary">404</p>
            <p className="text-muted-foreground">
                Nothing lives at this address — yet. Everything on jac.build is a
                node in one graph, and this path isn't.
            </p>
            <Link to="/" className="font-medium text-primary hover:underline">
                Back to the feed
            </Link>
        </div>;
}
