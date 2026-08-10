"""jac.build — one popup: application detail, core review, organizer
wrap, and the permanent archive page."""

import from "@jac/runtime" { useParams, jacIsLoggedIn }
import from "lucide-react" { MapPin, Calendar, Users, Clock }
import from ...components.ui.button { Button }
import from ...components.ui.textarea { Textarea }
import from ...components.ui.input { Input }
import from ...components.ui.card { Card, CardContent }
import from ...components.bits { time_ago, BuilderLink, EmptyState }
import from ...services.popups { get_popup, review_popup, complete_popup }
import from ...services.social { get_me }
import from ...services.model { Popup, BuilderBundle }

def tone(status: str) -> str {
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
    has pop: Popup | None = None,
        me: BuilderBundle | None = None,
        loading: bool = True,
        recap: str = "",
        finalCount: str = "",
        note: str = "",
        busy: bool = False;

    params = useParams();
    pid = params["id"] or "";

    can with entry {
        _ = load();
    }

    async def load -> None {
        w = root spawn get_popup(popup_id=str(pid));
        pop = w.reports[0] if w.reports else None;
        if jacIsLoggedIn() {
            m = root spawn get_me();
            me = m.reports[0] if m.reports else None;
        }
        loading = False;
    }

    async def decide(decision: str) -> None {
        if not pop {
            return;
        }
        busy = True;
        root spawn review_popup(popup_id=jid(pop), decision=decision, note=note);
        busy = False;
        _ = load();
    }

    async def wrap -> None {
        if not pop or not recap.strip() {
            return;
        }
        busy = True;
        root spawn complete_popup(
            popup_id=jid(pop),
            recap=recap,
            headcount=int(finalCount or "0")
        );
        busy = False;
        _ = load();
    }

    if loading {
        return
            <div className="mx-auto w-full max-w-2xl px-4 py-16 text-center">
                <p className="text-muted-foreground">Loading…</p>
            </div>;
    }

    if not pop {
        return
            <div className="mx-auto w-full max-w-2xl px-4 py-16">
                <EmptyState title="No popup at this address."/>
            </div>;
    }

    isCore = bool(me and me.builder.is_core);
    isHost = bool(me and me.builder.handle == pop.host_handle);

    return
        <div className="mx-auto w-full max-w-2xl px-4 py-8">
            <div className="flex flex-wrap items-center gap-3">
                <h1 className="text-3xl font-extrabold tracking-tight">
                    {pop.title}
                </h1>
                <span
                    className={
                        tone(pop.status)
                        + " rounded-full px-2.5 py-0.5 text-xs font-semibold uppercase tracking-wide"
                    }
                >
                    {pop.status}
                </span>
            </div>
            <div
                className="mt-3 flex flex-wrap gap-x-5 gap-y-2 text-sm text-muted-foreground"
            >
                <span className="inline-flex items-center gap-1.5">
                    <MapPin size={14}/>
                    {pop.city}
                </span>
                {if pop.date_iso {
                    <span className="inline-flex items-center gap-1.5">
                        <Calendar size={14}/>
                        {pop.date_iso}
                    </span>
                }}
                <span className="inline-flex items-center gap-1.5">
                    <Clock size={14}/>
                    {pop.format + " format"}
                </span>
                <span className="inline-flex items-center gap-1.5">
                    <Users size={14}/>
                    {str(pop.recap_headcount or pop.headcount) + " builders"}
                </span>
                <span>
                    {"hosted by "}
                    <BuilderLink handle={pop.host_handle}/>
                </span>
                <span>{"applied " + time_ago(pop.created_at)}</span>
            </div>
            <p className="mt-2 text-xs text-muted-foreground">
                {"Funding tier: " + pop.tier}
            </p>

            {if pop.needs {
                <Card className="mt-6 border-border/60">
                    <CardContent className="pt-4">
                        <p
                            className="mb-1 text-[11px] font-semibold uppercase tracking-wider text-muted-foreground"
                        >
                            The ask
                        </p>
                        <p className="whitespace-pre-wrap text-sm">{pop.needs}</p>
                    </CardContent>
                </Card>
            }}

            {if pop.decided_note {
                <p className="mt-4 text-sm text-muted-foreground">
                    {"Review note: " + pop.decided_note}
                </p>
            }}

            {if pop.status == "completed" and pop.recap {
                <Card className="mt-6 border-primary/30">
                    <CardContent className="pt-4">
                        <p
                            className="mb-1 text-[11px] font-semibold uppercase tracking-wider text-primary"
                        >
                            The wrap
                        </p>
                        <p className="whitespace-pre-wrap text-sm leading-relaxed">
                            {pop.recap}
                        </p>
                    </CardContent>
                </Card>
            }}

            {if isCore and pop.status == "applied" {
                <Card className="mt-6 border-amber-500/30">
                    <CardContent className="flex flex-col gap-3 pt-4">
                        <p className="text-sm font-semibold">Core review</p>
                        <Input
                            placeholder="Note to the organizer (optional)"
                            value={note}
                            onChange={lambda (e: ChangeEvent) { note = e.target.value; }}
                        />
                        <div className="flex gap-2">
                            <Button
                                size="sm"
                                className="rounded-full"
                                disabled={busy}
                                onClick={lambda { _ = decide("approved"); }}
                            >
                                Approve & fund
                            </Button>
                            <Button
                                size="sm"
                                variant="outline"
                                className="rounded-full"
                                disabled={busy}
                                onClick={lambda { _ = decide("declined"); }}
                            >
                                Decline
                            </Button>
                        </div>
                    </CardContent>
                </Card>
            }}

            {if isHost and pop.status == "approved" {
                <Card className="mt-6 border-emerald-500/30">
                    <CardContent className="flex flex-col gap-3 pt-4">
                        <p className="text-sm font-semibold">
                            Wrap it up — photos, links, and headcount make the
                            archive page.
                        </p>
                        <Textarea
                            rows={4}
                            placeholder="How did it go? Projects shipped, links, the story."
                            value={recap}
                            onChange={lambda (e: ChangeEvent) { recap = e.target.value; }}
                        />
                        <Input
                            type="number"
                            placeholder="Final headcount"
                            value={finalCount}
                            onChange={lambda (e: ChangeEvent) {
                                finalCount = e.target.value;
                            }}
                        />
                        <Button
                            size="sm"
                            className="self-end rounded-full"
                            disabled={busy or not recap.strip()}
                            onClick={lambda { _ = wrap(); }}
                        >
                            Publish the wrap
                        </Button>
                    </CardContent>
                </Card>
            }}
        </div>;
}
