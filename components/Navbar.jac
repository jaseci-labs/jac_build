"""jac.build — top navigation: wordmark, sections, cycle pulse, auth."""

import from "@jac/runtime" { Link, useLocation, useNavigate, jacIsLoggedIn, jacLogout }
import from "lucide-react" { Sun, Moon, Plus, LogOut, Menu, X }
import from .ui.button { Button }
import from ..services.cycles { cycle_status }
import from ..services.model { CycleStatus }
import from .bits { pad_cycle, countdown_label, Avatar }

def:pub Navbar(dark: bool, onToggleTheme: Callable[[], None]) -> JsxElement {
    has status: CycleStatus | None = None,
        loggedIn: bool = False,
        handle: str = "",
        hue: int = 21,
        menuOpen: bool = False;

    location = useLocation();
    nav = useNavigate();

    can with entry {
        loggedIn = jacIsLoggedIn();
        handle = localStorage.getItem("jb_handle") or "";
        hue = int(localStorage.getItem("jb_hue") or "21");
        _ = pulse();
    }

    async def pulse -> None {
        w = root spawn cycle_status();
        status = w.reports[0] if w.reports else None;
    }

    def logout -> None {
        jacLogout();
        localStorage.removeItem("jb_handle");
        localStorage.removeItem("jb_hue");
        loggedIn = False;
        handle = "";
        nav("/");
    }

    link_cls = lambda (path: str) { return (
        "rounded-md px-3 py-1.5 text-sm font-medium transition-colors "
        + (
            "bg-secondary text-foreground"
            if location.pathname == path
            else "text-muted-foreground hover:text-foreground"
        )
    ); };

    return
        <header
            className="sticky top-0 z-40 border-b border-border bg-background/85 backdrop-blur-lg"
        >
            <div
                className="mx-auto flex h-14 w-full max-w-6xl items-center gap-2 px-4"
            >
                <Link to="/" className="mr-2 flex items-baseline gap-0.5">
                    <span className="font-mono-brand text-lg font-bold tracking-tight">
                        jac
                    </span>
                    <span
                        className="font-mono-brand text-lg font-bold tracking-tight text-primary"
                    >
                        .build
                    </span>
                </Link>
                <nav className="hidden items-center gap-1 md:flex">
                    <Link to="/" className={link_cls("/")}>Feed</Link>
                    <Link to="/discover" className={link_cls("/discover")}>
                        Discover
                    </Link>
                    <Link to="/cycles" className={link_cls("/cycles")}>Cycles</Link>
                    <Link to="/popups" className={link_cls("/popups")}>Popups</Link>
                </nav>
                <div className="flex-1"/>
                {if status {
                    <Link
                        to="/cycles"
                        className="hidden items-center gap-2 rounded-full border border-primary/30 bg-primary/10 px-3 py-1 text-xs font-medium text-primary hover:bg-primary/15 sm:flex"
                    >
                        <span
                            className="size-1.5 animate-pulse rounded-full bg-primary"
                        />
                        {"Cycle " + pad_cycle(status.number)}
                        <span className="hidden text-primary/70 lg:inline">
                            {countdown_label(status.seconds_left, status.phase)}
                        </span>
                    </Link>
                }}
                <Button
                    variant="ghost"
                    size="icon"
                    className="rounded-full text-muted-foreground"
                    title="Toggle theme"
                    onClick={lambda { onToggleTheme(); }}
                >
                    {if dark { <Sun size={17}/> } else { <Moon size={17}/> }}
                </Button>
                {if loggedIn {
                    <>
                        <Button
                            size="sm"
                            className="hidden rounded-full sm:inline-flex"
                            onClick={lambda { nav("/enter"); }}
                        >
                            <Plus size={15}/>
                            Enter cycle
                        </Button>
                        {if handle {
                            <Link to={"/b/" + handle} title={"@" + handle}>
                                <Avatar {handle} {hue} size="size-8"/>
                            </Link>
                        }}
                        <Button
                            variant="ghost"
                            size="icon"
                            className="rounded-full text-muted-foreground"
                            title="Log out"
                            onClick={lambda { logout(); }}
                        >
                            <LogOut size={16}/>
                        </Button>
                    </>
                } else {
                    <Button
                        size="sm"
                        className="rounded-full"
                        onClick={lambda { nav("/login"); }}
                    >
                        Join
                    </Button>
                }}
                <Button
                    variant="ghost"
                    size="icon"
                    className="rounded-full text-muted-foreground md:hidden"
                    title="Menu"
                    onClick={lambda { menuOpen = not menuOpen; }}
                >
                    {if menuOpen { <X size={18}/> } else { <Menu size={18}/> }}
                </Button>
            </div>
            {if menuOpen {
                <nav
                    className="flex flex-col gap-1 border-t border-border px-4 py-2 md:hidden"
                >
                    <Link
                        to="/"
                        className={link_cls("/")}
                        onClick={lambda { menuOpen = False; }}
                    >
                        Feed
                    </Link>
                    <Link
                        to="/discover"
                        className={link_cls("/discover")}
                        onClick={lambda { menuOpen = False; }}
                    >
                        Discover
                    </Link>
                    <Link
                        to="/cycles"
                        className={link_cls("/cycles")}
                        onClick={lambda { menuOpen = False; }}
                    >
                        Cycles
                    </Link>
                    <Link
                        to="/popups"
                        className={link_cls("/popups")}
                        onClick={lambda { menuOpen = False; }}
                    >
                        Popups
                    </Link>
                    {if loggedIn {
                        <Link
                            to="/enter"
                            className={link_cls("/enter")}
                            onClick={lambda { menuOpen = False; }}
                        >
                            Enter cycle
                        </Link>
                    }}
                </nav>
            }}
        </header>;
}

def:pub Footer -> JsxElement {
    return
        <footer className="mt-16 border-t border-border">
            <div
                className="mx-auto flex w-full max-w-6xl flex-col items-center gap-2 px-4 py-8 text-center text-sm text-muted-foreground sm:flex-row sm:justify-between sm:text-left"
            >
                <p>
                    <span className="font-mono-brand font-semibold text-foreground">
                        jac.build
                    </span>
                    {" — where Jac projects live. Built in Jac, naturally."}
                </p>
                <p className="flex gap-4">
                    <a
                        href="https://jaclang.org"
                        className="hover:text-foreground"
                        target="_blank"
                        rel="noreferrer"
                    >
                        jaclang.org
                    </a>
                    <a
                        href="https://github.com/jaseci-labs/jac_build"
                        className="hover:text-foreground"
                        target="_blank"
                        rel="noreferrer"
                    >
                        source
                    </a>
                </p>
            </div>
        </footer>;
}
