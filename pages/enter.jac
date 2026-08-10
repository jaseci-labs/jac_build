"""jac.build — the entry flow: pick project → cut checkpoint → track
auto-detected → categories confirmed → done. Target: under ten minutes
for a Glow-Up re-entry."""

import from "@jac/runtime" { Link, useNavigate, useLocation, jacIsLoggedIn, Navigate }
import from "lucide-react" { GitCommitHorizontal, CheckCircle2 }
import from ..components.ui.button { Button }
import from ..components.ui.input { Input }
import from ..components.ui.label { Label }
import from ..components.ui.textarea { Textarea }
import from ..components.ui.card { Card, CardContent }
import from ..components.bits { pad_cycle, TrackChip, countdown_label, EmptyState }
import from ..components.FeedBits { CycleBanner }
import from ..services.projects { my_projects, cut_checkpoint, CheckpointResult }
import from ..services.cycles { cycle_status }
import from ..services.model { ProjectRole, CycleStatus }

# Duplicated from services/model.jac on purpose: client-module globs are
# not importable across the compiled JS boundary.
glob FRESH_CATS: list[str] = [
         "Best in Cycle",
         "Deepest Jac",
         "Best First Build",
         "Most Useful",
         "Wildcard / Weird",
     ];
glob GLOWUP_CATS: list[str] = [
         "Best Glow-Up",
         "Deepest Cut",
         "The Long Haul",
         "Best Comeback",
     ];

def:pub page -> JsxPage {
    has mine: list[ProjectRole] = [],
        status: CycleStatus | None = None,
        loading: bool = True,
        slug: str = "",
        sha: str = "",
        writeUp: str = "",
        demoUrl: str = "",
        deployedUrl: str = "",
        enterCycle: bool = True,
        picked: list[str] = [],
        submitting: bool = False,
        done: CheckpointResult | None = None,
        error: str = "";

    nav = useNavigate();
    location = useLocation();

    can with entry {
        search = new(URLSearchParams, location.search);  # jac:ignore[E1053]
        wanted = str(search.get("p") or "");  # jac:ignore[E1031]
        slug = wanted;
        _ = load(wanted);
    }

    async def load(wanted: str) -> None {
        s = root spawn cycle_status();
        status = s.reports[0] if s.reports else None;
        w = root spawn my_projects();
        got = w.reports[0] if w.reports else [];
        mine = got;
        if not wanted and len(got) > 0 {
            slug = got[0].project.slug;
        }
        loading = False;
    }

    def chosen -> ProjectRole | None {
        for r in mine {
            if r.project.slug == slug {
                return r;
            }
        }
        return None;
    }

    async def submit -> None {
        error = "";
        if not slug {
            error = "Pick a project.";
            return;
        }
        if not sha.strip() or not writeUp.strip() {
            error = "A checkpoint needs a commit SHA and a write-up.";
            return;
        }
        submitting = True;
        w = root spawn cut_checkpoint(
            slug=slug,
            sha=sha,
            write_up=writeUp,
            demo_url=demoUrl,
            deployed_url=deployedUrl,
            enter_cycle=enterCycle,
            categories=picked
        );
        got = w.reports[0] if w.reports else None;
        submitting = False;
        if got and got.ok {
            done = got;
        } else {
            error = got.error if got else "Something went wrong.";
        }
    }

    if not jacIsLoggedIn() {
        return <Navigate to="/login" replace={True}/>;
    }

    if done {
        return
            <div className="mx-auto w-full max-w-xl px-4 py-16 text-center">
                <CheckCircle2 size={44} className="mx-auto text-emerald-500"/>
                <h1 className="mt-4 text-2xl font-extrabold">
                    {"Checkpoint v"
                        + (str(done.checkpoint.number) if done.checkpoint else "?")
                        + " is cut."}
                </h1>
                {if done.entry {
                    <p className="mt-2 text-muted-foreground">
                        {"You're in Cycle "
                            + pad_cycle(done.cycle_number)
                            + " on the "
                            + ("Fresh Build" if done.track == "fresh" else "Glow-Up")
                            + " track. Awards land when the cycle rolls."}
                    </p>
                } else {
                    <p className="mt-2 text-muted-foreground">
                        {done.error
                            or "Voluntary checkpoint — posted to your followers, no cycle entry."}
                    </p>
                }}
                <div className="mt-6 flex justify-center gap-3">
                    <Button
                        className="rounded-full"
                        onClick={lambda { nav("/p/" + done.project_slug); }}
                    >
                        View project
                    </Button>
                    {if done.entry {
                        <Button
                            variant="outline"
                            className="rounded-full"
                            onClick={lambda {
                                nav("/cycle/" + str(done.cycle_number));
                            }}
                        >
                            See the cycle
                        </Button>
                    }}
                </div>
            </div>;
    }

    active = chosen();
    track = (
        ""
        if not active
        else ("fresh" if active.checkpoint_count == 0 else "glowup")
    );
    cats = FRESH_CATS if track == "fresh" else GLOWUP_CATS;

    return
        <div className="mx-auto w-full max-w-2xl px-4 py-8">
            <h1 className="mb-1 text-3xl font-extrabold tracking-tight">
                Cut a checkpoint
            </h1>
            <p className="mb-6 text-muted-foreground">
                A checkpoint is an immutable snapshot: repo SHA, write-up,
                optional demo. Entering the cycle is the same act.
            </p>
            {if status {
                <CycleBanner {status}/>
            }}

            {if loading {
                <p className="mt-6 text-muted-foreground">Loading your projects…</p>
            } elif len(mine) == 0 {
                <div className="mt-6">
                    <EmptyState
                        title="You don't have a project yet."
                        hint="A project outlives any single hackathon — create yours once, grow it forever."
                    />
                    <div className="mt-4 text-center">
                        <Button
                            className="rounded-full"
                            onClick={lambda { nav("/projects/new"); }}
                        >
                            Create your project
                        </Button>
                    </div>
                </div>
            } else {
                <Card className="mt-6 border-border/60">
                    <CardContent className="flex flex-col gap-5 pt-5">
                        <div className="flex flex-col gap-1.5">
                            <Label>Project</Label>
                            <div className="flex flex-wrap gap-2">
                                {for r in mine {
                                    <button
                                        type="button"
                                        key={r.project.slug}
                                        className={
                                            "rounded-full border px-3 py-1.5 text-sm transition-colors "
                                            + (
                                                "border-primary bg-primary/10 font-semibold text-primary"
                                                if r.project.slug == slug
                                                else "border-border text-muted-foreground hover:border-primary/40"
                                            )
                                        }
                                        onClick={lambda { slug = r.project.slug; }}
                                    >
                                        {r.project.name}
                                    </button>
                                }}
                                <Link
                                    to="/projects/new"
                                    className="rounded-full border border-dashed border-border px-3 py-1.5 text-sm text-muted-foreground hover:border-primary/40 hover:text-primary"
                                >
                                    + new project
                                </Link>
                            </div>
                            {if active {
                                <p
                                    className="mt-1 flex items-center gap-2 text-xs text-muted-foreground"
                                >
                                    <TrackChip {track}/>
                                    <span>
                                        {"First-ever checkpoint — judged in absolute terms."
                                            if track == "fresh"
                                            else (
                                                "Checkpoint "
                                                + str(active.checkpoint_count + 1)
                                                + " — the diff from your last checkpoint is what gets judged."
                                            )}
                                    </span>
                                </p>
                            }}
                        </div>
                        <div className="flex flex-col gap-1.5">
                            <Label htmlFor="jb-sha">Commit SHA</Label>
                            <div className="relative">
                                <GitCommitHorizontal
                                    size={15}
                                    className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground"
                                />
                                <Input
                                    id="jb-sha"
                                    className="pl-9 font-mono-brand"
                                    placeholder="e.g. 4f2a91c"
                                    value={sha}
                                    onChange={lambda (e: ChangeEvent) {
                                        sha = e.target.value;
                                    }}
                                />
                            </div>
                        </div>
                        <div className="flex flex-col gap-1.5">
                            <Label htmlFor="jb-writeup">
                                {"Improvement write-up (what changed, why, what was hard)"
                                    if track == "glowup"
                                    else "Write-up (what it is, what it does)"}
                            </Label>
                            <Textarea
                                id="jb-writeup"
                                rows={4}
                                placeholder={
                                    "Honest and concrete beats polished. ~400 words max."
                                }
                                value={writeUp}
                                onChange={lambda (e: ChangeEvent) {
                                    writeUp = e.target.value;
                                }}
                            />
                        </div>
                        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                            <div className="flex flex-col gap-1.5">
                                <Label htmlFor="jb-demo">Demo video (optional)</Label>
                                <Input
                                    id="jb-demo"
                                    placeholder="https://…"
                                    value={demoUrl}
                                    onChange={lambda (e: ChangeEvent) {
                                        demoUrl = e.target.value;
                                    }}
                                />
                            </div>
                            <div className="flex flex-col gap-1.5">
                                <Label htmlFor="jb-live">Deployed link (optional)</Label>
                                <Input
                                    id="jb-live"
                                    placeholder="https://…"
                                    value={deployedUrl}
                                    onChange={lambda (e: ChangeEvent) {
                                        deployedUrl = e.target.value;
                                    }}
                                />
                            </div>
                        </div>
                        <label
                            className="flex cursor-pointer items-center gap-2 text-sm"
                        >
                            <input
                                type="checkbox"
                                checked={enterCycle}
                                onChange={lambda (e: ChangeEvent) {
                                    enterCycle = e.target.checked;
                                }}
                            />
                            {"Enter Cycle "
                                + (pad_cycle(status.number) if status else "—")
                                + " with this checkpoint"}
                        </label>
                        {if enterCycle {
                            <div className="flex flex-col gap-1.5">
                                <Label>
                                    {"Categories to contend for ("
                                        + ("Fresh Build" if track == "fresh" else "Glow-Up")
                                        + " track)"}
                                </Label>
                                <div className="flex flex-wrap gap-2">
                                    {for c in cats {
                                        <button
                                            type="button"
                                            key={c}
                                            className={
                                                "rounded-full border px-3 py-1 text-xs transition-colors "
                                                + (
                                                    "border-primary bg-primary/10 font-semibold text-primary"
                                                    if c in picked
                                                    else "border-border text-muted-foreground hover:border-primary/40"
                                                )
                                            }
                                            onClick={lambda {
                                                if c in picked {
                                                    picked = [
                                                        x for x in picked if x != c
                                                    ];
                                                } else {
                                                    picked = picked + [c];
                                                }
                                            }}
                                        >
                                            {c}
                                        </button>
                                    }}
                                </div>
                                <p className="text-xs text-muted-foreground/70">
                                    Streak and comeback categories are detected
                                    automatically — picking is just a signal to
                                    judges.
                                </p>
                            </div>
                        }}
                        {if error {
                            <p className="text-sm text-destructive">{error}</p>
                        }}
                        <Button
                            className="self-end rounded-full px-6"
                            disabled={submitting}
                            onClick={lambda { _ = submit(); }}
                        >
                            {"Cutting…"
                                if submitting
                                else (
                                    "Cut checkpoint & enter"
                                    if enterCycle
                                    else "Cut checkpoint"
                                )}
                        </Button>
                    </CardContent>
                </Card>
            }}
        </div>;
}
