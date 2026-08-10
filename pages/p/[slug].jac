"""jac.build — the project profile: header, timeline, checkpoints,
cycle record. Created once, lives forever."""

import from "@jac/runtime" { Link, useParams, useNavigate, jacIsLoggedIn }
import from "lucide-react" {
    ExternalLink, GitCommitHorizontal, Video, Globe, UserPlus, Bell, BellOff
}
import from ...components.ui.button { Button }
import from ...components.ui.tabs { Tabs, TabsList, TabsTrigger, TabsContent }
import from ...components.ui.skeleton { Skeleton }
import from ...components.ui.input { Input }
import from ...components.FeedBits { PostCard }
import from ...components.bits {
    time_ago, short_sha, pad_cycle, Avatar, AwardChip, TrackChip, EmptyState
}
import from ...services.projects { get_project, add_member }
import from ...services.social { toggle_follow }
import from ...services.model { ProjectBundle }

def:pub page -> JsxPage {
    has bundle: ProjectBundle | None = None,
        loading: bool = True,
        missing: bool = False,
        loggedIn: bool = False,
        newMate: str = "",
        inviting: bool = False;

    params = useParams();
    nav = useNavigate();
    slug = params["slug"] or "";

    can with entry {
        loggedIn = jacIsLoggedIn();
        _ = load();
    }

    async def load -> None {
        w = root spawn get_project(slug=str(slug));
        got = w.reports[0] if w.reports else None;
        bundle = got;
        missing = not got;
        loading = False;
    }

    async def follow -> None {
        if not bundle {
            return;
        }
        root spawn toggle_follow(target_id=jid(bundle.project));
        _ = load();
    }

    async def invite -> None {
        if not bundle or not newMate.strip() {
            return;
        }
        inviting = True;
        w = root spawn add_member(slug=bundle.project.slug, handle=newMate.strip());
        got = w.reports[0] if w.reports else None;
        if got {
            bundle = got;
        }
        newMate = "";
        inviting = False;
    }

    if loading {
        return
            <div className="mx-auto w-full max-w-3xl px-4 py-10">
                <Skeleton className="h-8 w-64"/>
                <Skeleton className="mt-3 h-4 w-96"/>
                <Skeleton className="mt-8 h-40 w-full"/>
            </div>;
    }

    if missing or not bundle {
        return
            <div className="mx-auto w-full max-w-3xl px-4 py-16">
                <EmptyState
                    title="No project lives at this address."
                    hint="It may have been renamed — check Discover."
                />
            </div>;
    }

    p = bundle.project;

    return
        <div className="mx-auto w-full max-w-3xl px-4 py-8">
            <header className="flex flex-col gap-3">
                <div className="flex flex-wrap items-center gap-3">
                    <h1 className="text-3xl font-extrabold tracking-tight">
                        {p.name}
                    </h1>
                    {if p.status != "active" {
                        <span
                            className="rounded-full bg-muted px-2.5 py-0.5 text-xs uppercase tracking-wide text-muted-foreground"
                        >
                            {p.status}
                        </span>
                    }}
                    {if bundle.streak >= 2 {
                        <span
                            className="rounded-full bg-primary/15 px-2.5 py-0.5 text-xs font-semibold text-primary"
                            title="Consecutive cycles entered"
                        >
                            {"🔥 " + str(bundle.streak) + "-cycle streak"}
                        </span>
                    }}
                    <div className="flex-1"/>
                    {if loggedIn and not bundle.my_role {
                        <Button
                            size="sm"
                            variant={"outline" if bundle.is_following else "default"}
                            className="rounded-full"
                            onClick={lambda { _ = follow(); }}
                        >
                            {if bundle.is_following {
                                <>
                                    <BellOff size={14}/>
                                    Unfollow
                                </>
                            } else {
                                <>
                                    <Bell size={14}/>
                                    Follow
                                </>
                            }}
                        </Button>
                    }}
                    {if bundle.my_role {
                        <Button
                            size="sm"
                            className="rounded-full"
                            onClick={lambda { nav("/enter?p=" + p.slug); }}
                        >
                            Cut a checkpoint
                        </Button>
                    }}
                </div>
                {if p.one_liner {
                    <p className="text-lg text-muted-foreground">{p.one_liner}</p>
                }}
                <div
                    className="flex flex-wrap items-center gap-x-4 gap-y-2 text-sm text-muted-foreground"
                >
                    {if p.repo_url {
                        <a
                            href={p.repo_url}
                            target="_blank"
                            rel="noreferrer"
                            className="inline-flex items-center gap-1 hover:text-foreground"
                        >
                            <ExternalLink size={13}/>
                            repo
                        </a>
                    }}
                    <span className="inline-flex items-center gap-1">
                        <GitCommitHorizontal size={13}/>
                        {str(len(bundle.checkpoints)) + " checkpoints"}
                    </span>
                    <span>{str(bundle.followers) + " followers"}</span>
                    <span>{"since " + time_ago(p.created_at)}</span>
                </div>
                {if len(p.tags) > 0 {
                    <div className="flex flex-wrap gap-1.5">
                        {for t in p.tags {
                            <span
                                key={t}
                                className="rounded-full bg-secondary px-2 py-0.5 text-xs text-muted-foreground"
                            >
                                {"#" + t}
                            </span>
                        }}
                    </div>
                }}
                {if len(bundle.awards) > 0 {
                    <div className="flex flex-wrap gap-1.5">
                        {for a in bundle.awards {
                            <AwardChip
                                key={jid(a)}
                                category={a.category}
                                cycle_number={a.cycle_number}
                            />
                        }}
                    </div>
                }}
                <div className="flex flex-wrap items-center gap-2 pt-1">
                    {for m in bundle.team {
                        <Link
                            key={m.builder.handle}
                            to={"/b/" + m.builder.handle}
                            className="flex items-center gap-1.5 rounded-full border border-border py-1 pl-1 pr-3 text-xs hover:border-primary/40"
                            title={m.role}
                        >
                            <Avatar
                                handle={m.builder.handle}
                                hue={m.builder.avatar_hue}
                                size="size-5"
                            />
                            {"@" + m.builder.handle}
                            <span className="text-muted-foreground/70">
                                {m.role}
                            </span>
                        </Link>
                    }}
                    {if bundle.my_role in ["owner", "maintainer"] {
                        <span className="flex items-center gap-1">
                            <Input
                                value={newMate}
                                placeholder="add @handle"
                                className="h-7 w-28 rounded-full text-xs"
                                onChange={lambda (e: ChangeEvent) {
                                    newMate = e.target.value;
                                }}
                            />
                            <Button
                                size="icon"
                                variant="ghost"
                                className="size-7 rounded-full"
                                disabled={inviting}
                                title="Add teammate"
                                onClick={lambda { _ = invite(); }}
                            >
                                <UserPlus size={14}/>
                            </Button>
                        </span>
                    }}
                </div>
            </header>

            {if p.description {
                <p
                    className="mt-6 whitespace-pre-wrap text-[15px] leading-relaxed text-foreground/90"
                >
                    {p.description}
                </p>
            }}

            <Tabs defaultValue="timeline" className="mt-8">
                <TabsList>
                    <TabsTrigger value="timeline">Timeline</TabsTrigger>
                    <TabsTrigger value="checkpoints">
                        {"Checkpoints (" + str(len(bundle.checkpoints)) + ")"}
                    </TabsTrigger>
                    <TabsTrigger value="cycles">
                        {"Cycle record (" + str(len(bundle.entries)) + ")"}
                    </TabsTrigger>
                </TabsList>
                <TabsContent value="timeline">
                    {if len(bundle.posts) == 0 {
                        <EmptyState
                            title="Quiet so far."
                            hint="Checkpoints and build logs land here."
                        />
                    } else {
                        <div>
                            {for post in bundle.posts {
                                <PostCard key={jid(post)} {post}/>
                            }}
                        </div>
                    }}
                </TabsContent>
                <TabsContent value="checkpoints">
                    {if len(bundle.checkpoints) == 0 {
                        <EmptyState
                            title="No checkpoints yet."
                            hint="The first one makes this project a Fresh Build."
                        />
                    } else {
                        <div className="timeline-rail flex flex-col gap-4 pl-8">
                            {for point in bundle.checkpoints {
                                <div key={jid(point)} className="relative">
                                    <span
                                        className="absolute -left-8 top-1 flex size-6 items-center justify-center rounded-full border border-primary/40 bg-background font-mono-brand text-[10px] font-bold text-primary"
                                    >
                                        {"v" + str(point.number)}
                                    </span>
                                    <div
                                        className="flex flex-wrap items-center gap-2 text-xs text-muted-foreground"
                                    >
                                        <code
                                            className="rounded bg-secondary px-1.5 py-0.5"
                                        >
                                            {short_sha(point.sha)}
                                        </code>
                                        <span>{time_ago(point.created_at)}</span>
                                        {if point.demo_url {
                                            <a
                                                href={point.demo_url}
                                                target="_blank"
                                                rel="noreferrer"
                                                className="inline-flex items-center gap-1 text-primary hover:underline"
                                            >
                                                <Video size={11}/>
                                                demo
                                            </a>
                                        }}
                                        {if point.deployed_url {
                                            <a
                                                href={point.deployed_url}
                                                target="_blank"
                                                rel="noreferrer"
                                                className="inline-flex items-center gap-1 text-primary hover:underline"
                                            >
                                                <Globe size={11}/>
                                                live
                                            </a>
                                        }}
                                    </div>
                                    <p className="mt-1 text-sm leading-relaxed">
                                        {point.write_up}
                                    </p>
                                </div>
                            }}
                        </div>
                    }}
                </TabsContent>
                <TabsContent value="cycles">
                    {if len(bundle.entries) == 0 {
                        <EmptyState
                            title="Never entered a cycle."
                            hint="Cut a checkpoint during a build window to enter."
                        />
                    } else {
                        <div className="flex flex-col gap-3">
                            {for e in bundle.entries {
                                <div
                                    key={jid(e.entry)}
                                    className="rounded-xl border border-border p-4"
                                >
                                    <div className="flex flex-wrap items-center gap-2">
                                        <Link
                                            to={"/cycle/" + str(e.entry.cycle_number)}
                                            className="font-mono-brand text-sm font-bold text-primary hover:underline"
                                        >
                                            {"Cycle " + pad_cycle(e.entry.cycle_number)}
                                        </Link>
                                        <TrackChip track={e.entry.track}/>
                                        {if e.score_avg > 0.0 {
                                            <span
                                                className="text-xs text-muted-foreground"
                                            >
                                                {"scored " + str(e.score_avg)}
                                            </span>
                                        }}
                                        <div className="flex-1"/>
                                        {for a in e.awards {
                                            <AwardChip
                                                key={jid(a)}
                                                category={a.category}
                                            />
                                        }}
                                    </div>
                                    {if e.entry.track == "glowup" {
                                        <p
                                            className="mt-1 text-xs text-muted-foreground"
                                        >
                                            {short_sha(e.entry.base_sha)
                                                + " → "
                                                + short_sha(e.entry.head_sha)
                                                + (
                                                    (
                                                        " · "
                                                        + str(e.entry.commits_count)
                                                        + " commits, +"
                                                        + str(e.entry.additions)
                                                        + " / -"
                                                        + str(e.entry.deletions)
                                                    )
                                                    if e.entry.commits_count > 0
                                                    else ""
                                                )}
                                        </p>
                                    }}
                                </div>
                            }}
                        </div>
                    }}
                </TabsContent>
            </Tabs>
        </div>;
}
