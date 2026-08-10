"""jac.build — JacHacks Popups: apply in ten minutes, run it anywhere."""

import from "@jac/runtime" { Link, jacIsLoggedIn, useNavigate }
import from "lucide-react" { MapPin, Calendar, Users }
import from ..components.ui.button { Button }
import from ..components.ui.input { Input }
import from ..components.ui.label { Label }
import from ..components.ui.textarea { Textarea }
import from ..components.ui.card { Card, CardContent }
import from ..components.bits { time_ago, EmptyState }
import from ..services.popups { apply_popup, list_popups }
import from ..services.model { Popup }

def status_tone(status: str) -> str {
    if status == "approved" {
        return "bg-emerald-500/15 text-emerald-600 dark:text-emerald-400";
    }
    if status == "completed" {
        return "bg-primary/15 text-primary";
    }
    if status == "declined" {
        return "bg-muted text-muted-foreground";
    }
    return "bg-amber-500/15 text-amber-600 dark:text-amber-400";
}

def:pub page -> JsxPage {
    has pops: list[Popup] = [],
        loading: bool = True,
        applying: bool = False,
        showForm: bool = False,
        title: str = "",
        city: str = "",
        dateIso: str = "",
        headcount: str = "10",
        format: str = "4h",
        needs: str = "",
        error: str = "";

    nav = useNavigate();

    can with entry {
        _ = load();
    }

    async def load -> None {
        w = root spawn list_popups();
        pops = w.reports[0] if w.reports else [];
        loading = False;
    }

    async def submit -> None {
        error = "";
        if not title.strip() or not city.strip() {
            error = "Name it and place it, at minimum.";
            return;
        }
        applying = True;
        w = root spawn apply_popup(
            title=title,
            city=city,
            date_iso=dateIso,
            headcount=int(headcount or "5"),
            format=format,
            needs=needs
        );
        applying = False;
        got = w.reports[0] if w.reports else None;
        if got {
            showForm = False;
            title = "";
            city = "";
            needs = "";
            _ = load();
        } else {
            error = "Application failed — are you signed in?";
        }
    }

    return
        <div className="mx-auto w-full max-w-4xl px-4 py-8">
            <div className="flex flex-wrap items-center gap-3">
                <div className="min-w-0 flex-1">
                    <h1 className="text-3xl font-extrabold tracking-tight">
                        JacHacks Popups
                    </h1>
                    <p className="mt-1 text-muted-foreground">
                        Five people in a dorm lounge on a Sunday is a legitimate
                        popup. Apply, get funded, get the kit — judging routes
                        through the platform.
                    </p>
                </div>
                {if jacIsLoggedIn() {
                    <Button
                        className="rounded-full"
                        onClick={lambda { showForm = not showForm; }}
                    >
                        {"Close" if showForm else "Run one"}
                    </Button>
                } else {
                    <Button
                        className="rounded-full"
                        onClick={lambda { nav("/login"); }}
                    >
                        Join to apply
                    </Button>
                }}
            </div>

            <div className="mt-6 grid grid-cols-1 gap-3 sm:grid-cols-3">
                <Step
                    n="1"
                    title="Apply"
                    body="Who, where, when, headcount. Ten minutes, not a grant-writing afternoon."
                />
                <Step
                    n="2"
                    title="Get funded + kitted"
                    body="Food money at minimum, run-of-show templates, the zero-to-Jac workshop deck."
                />
                <Step
                    n="3"
                    title="Run it & wrap"
                    body="Check-ins on jac.build, local winners at your demo day, a permanent archive page."
                />
            </div>

            {if showForm {
                <Card className="mt-6 border-primary/30">
                    <CardContent className="flex flex-col gap-4 pt-5">
                        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                            <div className="flex flex-col gap-1.5">
                                <Label htmlFor="pu-title">Event name</Label>
                                <Input
                                    id="pu-title"
                                    placeholder="JacHacks Popup: Ann Arbor"
                                    value={title}
                                    onChange={lambda (e: ChangeEvent) {
                                        title = e.target.value;
                                    }}
                                />
                            </div>
                            <div className="flex flex-col gap-1.5">
                                <Label htmlFor="pu-city">City / campus</Label>
                                <Input
                                    id="pu-city"
                                    placeholder="Ann Arbor, MI"
                                    value={city}
                                    onChange={lambda (e: ChangeEvent) {
                                        city = e.target.value;
                                    }}
                                />
                            </div>
                        </div>
                        <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
                            <div className="flex flex-col gap-1.5">
                                <Label htmlFor="pu-date">Date</Label>
                                <Input
                                    id="pu-date"
                                    type="date"
                                    value={dateIso}
                                    onChange={lambda (e: ChangeEvent) {
                                        dateIso = e.target.value;
                                    }}
                                />
                            </div>
                            <div className="flex flex-col gap-1.5">
                                <Label htmlFor="pu-head">Expected headcount</Label>
                                <Input
                                    id="pu-head"
                                    type="number"
                                    min="5"
                                    value={headcount}
                                    onChange={lambda (e: ChangeEvent) {
                                        headcount = e.target.value;
                                    }}
                                />
                            </div>
                            <div className="flex flex-col gap-1.5">
                                <Label>Format</Label>
                                <div className="flex gap-1.5">
                                    {for f in ["4h", "12h", "24h"] {
                                        <button
                                            type="button"
                                            key={f}
                                            className={
                                                "flex-1 rounded-md border px-2 py-1.5 text-sm "
                                                + (
                                                    "border-primary bg-primary/10 font-semibold text-primary"
                                                    if format == f
                                                    else "border-border text-muted-foreground"
                                                )
                                            }
                                            onClick={lambda { format = f; }}
                                        >
                                            {f}
                                        </button>
                                    }}
                                </div>
                            </div>
                        </div>
                        <div className="flex flex-col gap-1.5">
                            <Label htmlFor="pu-needs">What do you need?</Label>
                            <Textarea
                                id="pu-needs"
                                rows={2}
                                placeholder="Pizza for 12, a room we already have, two poster prints."
                                value={needs}
                                onChange={lambda (e: ChangeEvent) {
                                    needs = e.target.value;
                                }}
                            />
                        </div>
                        {if error {
                            <p className="text-sm text-destructive">{error}</p>
                        }}
                        <Button
                            className="self-end rounded-full px-6"
                            disabled={applying}
                            onClick={lambda { _ = submit(); }}
                        >
                            {"Applying…" if applying else "Submit application"}
                        </Button>
                    </CardContent>
                </Card>
            }}

            <section className="mt-8">
                <h2 className="mb-3 text-lg font-bold">The popup ledger</h2>
                {if loading {
                    <p className="text-muted-foreground">Loading…</p>
                } elif len(pops) == 0 {
                    <EmptyState
                        title="No popups yet."
                        hint="The first one in your city could be yours."
                    />
                } else {
                    <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                        {for p in pops {
                            <Link
                                key={jid(p)}
                                to={"/popup/" + jid(p)}
                                className="flex flex-col gap-2 rounded-xl border border-border bg-card p-4 transition-colors hover:border-primary/40"
                            >
                                <div className="flex items-center gap-2">
                                    <span className="font-bold">{p.title}</span>
                                    <span
                                        className={
                                            status_tone(p.status)
                                            + " ml-auto rounded-full px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide"
                                        }
                                    >
                                        {p.status}
                                    </span>
                                </div>
                                <div
                                    className="flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted-foreground"
                                >
                                    <span className="inline-flex items-center gap-1">
                                        <MapPin size={12}/>
                                        {p.city}
                                    </span>
                                    {if p.date_iso {
                                        <span
                                            className="inline-flex items-center gap-1"
                                        >
                                            <Calendar size={12}/>
                                            {p.date_iso}
                                        </span>
                                    }}
                                    <span className="inline-flex items-center gap-1">
                                        <Users size={12}/>
                                        {str(p.recap_headcount or p.headcount)}
                                    </span>
                                    <span>{"@" + p.host_handle}</span>
                                    <span className="ml-auto">
                                        {time_ago(p.created_at)}
                                    </span>
                                </div>
                            </Link>
                        }}
                    </div>
                }}
            </section>
        </div>;
}

def Step(n: str, title: str, body: str) -> JsxElement {
    return
        <div className="rounded-xl border border-border bg-card p-4">
            <span
                className="font-mono-brand text-xs font-bold text-primary"
            >
                {n}
            </span>
            <h3 className="mt-1 font-bold">{title}</h3>
            <p className="mt-1 text-sm text-muted-foreground">{body}</p>
        </div>;
}
