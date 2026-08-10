"""jac.build — root layout: theme, navbar, page outlet, footer."""

import from "@jac/runtime" { Outlet }
import from ..components.Navbar { Navbar, Footer }

def:pub layout -> JsxLayout {
    has dark: bool = True;

    can with entry {
        dark = (localStorage.getItem("jb_theme") or "dark") != "light";
    }

    can with [dark] entry {
        if dark {
            document.documentElement.classList.add("dark");
        } else {
            document.documentElement.classList.remove("dark");
        }
    }

    return
        <div
            className="flex min-h-screen flex-col overflow-x-clip bg-background text-foreground antialiased"
        >
            <Navbar
                {dark}
                onToggleTheme={lambda {
                    dark = not dark;
                    localStorage.setItem("jb_theme", "dark" if dark else "light");
                }}
            />
            <main className="flex-1">
                <Outlet/>
            </main>
            <Footer/>
        </div>;
}
