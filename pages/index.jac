"""jac.build — home: the chronological feed for members, the pitch for
everyone else."""

import from "@jac/runtime" { Link, useNavigate, jacIsLoggedIn }
import from "lucide-react" {
    Rocket, RefreshCcw, Users, Flame, GitCommitHorizontal, Trophy
}
import from ..components.ui.button { Button }
import from ..components.ui.card { Card, CardContent }
import from ..components.ui.skeleton { Skeleton }
import from ..components.FeedBits { PostCard, Composer, CycleBanner }
import from ..components.bits { pad_cycle, EmptyState }
import from ..services.social { load_feed, create_post }
import from ..services.projects { my_projects, landing_stats }
import from ..services.cycles { cycle_status }
import from ..services.model { Post, CycleStatus, ProjectRole }
import from ..services.projects { LandingStats }

def:pub page -> JsxPage {
    has loggedIn: bool = False,
        checking: bool = True,
        posts: list[Post] = [],
        loading: bool = True,
        posting: bool = False,
        status: CycleStatus | None = None,
        mine: list[ProjectRole] = [],
        stats: LandingStats | None = None;

    can with entry {
        loggedIn = jacIsLoggedIn();
        checking = False;
        if loggedIn {
            _ = loadFeed();
        } else {
            _ = loadLanding();
        }
    }

    async def loadFeed -> None {
        s = root spawn cycle_status();
        status = s.reports[0] if s.reports else None;
        p = root spawn my_projects();
        mine = p.reports[0] if p.reports else [];
        f = root spawn load_feed();
        posts = f.reports[0] if f.reports else [];
        loading = False;
    }

    async def loadLanding -> None {
        w = root spawn landing_stats();
        stats = w.reports[0] if w.reports else None;
    }

    async def post(body: str, slug: str) -> None {
        posting = True;
        root spawn create_post(body=body, project_slug=slug);
        f = root spawn load_feed();
        posts = f.reports[0] if f.reports else posts;
        posting = False;
    }

    if checking {
        return
            <div className="flex min-h-[60vh] items-center justify-center">
                <div
                    className="size-8 animate-spin rounded-full border-2 border-primary border-t-transparent"
                />
            </div>;
    }

    if not loggedIn {
        return <Landing {stats}/>;
    }

    return
        <div className="mx-auto w-full max-w-2xl px-4 py-6">
            <div className="flex flex-col gap-4">
                {if status {
                    <CycleBanner {status}/>
                }}
                <Composer myProjects={mine} onPost={post} {posting}/>
                {if loading {
                    <div className="flex flex-col gap-4 py-4">
                        {[
                            <div className="flex gap-3" key={i}>
                                <Skeleton className="size-8 rounded-full"/>
                                <div className="flex-1 space-y-2">
                                    <Skeleton className="h-3 w-40"/>
                                    <Skeleton className="h-3 w-full"/>
                                </div>
                            </div> for i in range(5)
                        ]}
                    </div>
                } elif len(posts) == 0 {
                    <EmptyState
                        title="Your feed is quiet."
                        hint="Follow builders and projects from Discover, or post the first build log."
                    />
                } else {
                    <div>
                        {for p in posts {
                            <PostCard key={jid(p)} post={p}/>
                        }}
                    </div>
                }}
            </div>
        </div>;
}

def Landing(stats: LandingStats | None) -> JsxElement {
    nav = useNavigate();
    return
        <div className="mx-auto w-full max-w-6xl px-4">
            <section
                className="flex flex-col items-center gap-6 py-20 text-center"
            >
                <span
                    className="rounded-full border border-primary/30 bg-primary/10 px-4 py-1 text-xs font-semibold uppercase tracking-widest text-primary"
                >
                    JacHacks Forever
                </span>
                <h1
                    className="max-w-3xl text-balance text-5xl font-extrabold leading-tight tracking-tight sm:text-6xl"
                >
                    {"The hackathon that "}
                    <span className="text-primary">never ends</span>
                    {". The projects that "}
                    <span className="text-primary">never die</span>
                    {"."}
                </h1>
                <p className="max-w-2xl text-balance text-lg text-muted-foreground">
                    jac.build is the home of the Jac builders community: a new
                    cycle every two weeks, living project profiles with
                    followers and checkpoints, and a Glow-Up track that judges
                    how far you moved — not just where you stand.
                </p>
                <div className="flex flex-wrap items-center justify-center gap-3">
                    <Button
                        size="lg"
                        className="rounded-full px-7"
                        onClick={lambda { nav("/login"); }}
                    >
                        Claim your handle
                    </Button>
                    <Button
                        size="lg"
                        variant="outline"
                        className="rounded-full px-7"
                        onClick={lambda { nav("/discover"); }}
                    >
                        Browse the builds
                    </Button>
                </div>
                {if stats {
                    <div
                        className="mt-6 grid w-full max-w-2xl grid-cols-2 gap-3 sm:grid-cols-4"
                    >
                        <Stat
                            label="current cycle"
                            value={pad_cycle(stats.cycle_number)}
                        />
                        <Stat label="builders" value={str(stats.builders)}/>
                        <Stat label="projects" value={str(stats.projects)}/>
                        <Stat label="checkpoints" value={str(stats.checkpoints)}/>
                    </div>
                }}
            </section>

            <section className="grid grid-cols-1 gap-4 pb-20 md:grid-cols-3">
                <Pitch
                    icon={<Rocket size={20}/>}
                    title="Build in public"
                    body="Your project gets a profile, a timeline, and followers. Every checkpoint ships to the people rooting for it. The submission is a moment in the project's life — not its container."
                />
                <Pitch
                    icon={<RefreshCcw size={20}/>}
                    title="Glow up, forever"
                    body="Re-enter the same project cycle after cycle. Returning projects are judged on the diff — commits, stats, and an honest write-up — so persistence beats polish and pedigree."
                />
                <Pitch
                    icon={<Users size={20}/>}
                    title="Run your own popup"
                    body="Five people in a dorm lounge is a legitimate JacHacks. Apply in ten minutes, get funded, get the kit — judging routes through the platform."
                />
            </section>

            <section className="pb-24">
                <h2 className="mb-6 text-center text-2xl font-bold">
                    One loop, two tracks
                </h2>
                <div className="mx-auto grid max-w-4xl grid-cols-1 gap-4 md:grid-cols-2">
                    <Card className="border-emerald-500/30">
                        <CardContent className="pt-5">
                            <div className="mb-2 flex items-center gap-2">
                                <Flame size={18} className="text-emerald-500"/>
                                <span className="font-bold">Fresh Build</span>
                            </div>
                            <p className="text-sm text-muted-foreground">
                                Your project's first-ever checkpoint. Judged in
                                absolute terms — Best in Cycle, Deepest Jac,
                                Best First Build, Most Useful, and Wildcard.
                                The on-ramp.
                            </p>
                        </CardContent>
                    </Card>
                    <Card className="border-primary/30">
                        <CardContent className="pt-5">
                            <div className="mb-2 flex items-center gap-2">
                                <GitCommitHorizontal
                                    size={18}
                                    className="text-primary"
                                />
                                <span className="font-bold">Glow-Up</span>
                            </div>
                            <p className="text-sm text-muted-foreground">
                                Any project with history. What's judged is the
                                diff between checkpoints — Best Glow-Up, Deepest
                                Cut, The Long Haul, Best Comeback. The treadmill.
                            </p>
                        </CardContent>
                    </Card>
                </div>
                <p
                    className="mx-auto mt-8 flex max-w-xl items-center justify-center gap-2 text-center text-sm text-muted-foreground"
                >
                    <Trophy size={16} className="shrink-0 text-amber-500"/>
                    The track is decided by your project's checkpoint history —
                    never chosen, never gamed.
                </p>
            </section>
        </div>;
}

def Stat(label: str, value: str) -> JsxElement {
    return
        <div
            className="rounded-xl border border-border bg-card px-4 py-3 text-center"
        >
            <div className="font-mono-brand text-2xl font-bold text-primary">
                {value}
            </div>
            <div
                className="text-[11px] font-medium uppercase tracking-wider text-muted-foreground"
            >
                {label}
            </div>
        </div>;
}

def Pitch(icon: JsxElement, title: str, body: str) -> JsxElement {
    return
        <Card className="border-border/60">
            <CardContent className="pt-5">
                <div
                    className="mb-3 flex size-10 items-center justify-center rounded-lg bg-primary/12 text-primary"
                >
                    {icon}
                </div>
                <h3 className="mb-1.5 font-bold">{title}</h3>
                <p className="text-sm leading-relaxed text-muted-foreground">
                    {body}
                </p>
            </CardContent>
        </Card>;
}
