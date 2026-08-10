"""jac.build — discover: a browse surface, not a feed. Discovery is
something you visit, not something pushed at you."""

import from "@jac/runtime" { Link, jacIsLoggedIn }
import from ..components.ui.skeleton { Skeleton }
import from ..components.ui.tabs { Tabs, TabsList, TabsTrigger, TabsContent }
import from ..components.bits { pad_cycle, Avatar, EmptyState }
import from ..components.Cards { EntryCard, ProjectTile }
import from ..services.projects { discover, DiscoverBundle }
import from ..services.social { list_builders, BuilderCard }

def:pub page -> JsxPage {
    has bundle: DiscoverBundle | None = None,
        builders: list[BuilderCard] = [],
        loading: bool = True,
        tag: str = "",
        loggedIn: bool = False;

    can with entry {
        loggedIn = jacIsLoggedIn();
        _ = load();
    }

    async def load -> None {
        w = root spawn discover();
        bundle = w.reports[0] if w.reports else None;
        b = root spawn list_builders();
        builders = b.reports[0] if b.reports else [];
        loading = False;
    }

    def refresh -> None {
        _ = load();
    }

    if loading {
        return
            <div className="mx-auto w-full max-w-5xl px-4 py-10">
                <Skeleton className="h-8 w-48"/>
                <div className="mt-6 grid grid-cols-1 gap-3 sm:grid-cols-3">
                    <Skeleton className="h-36 w-full"/>
                    <Skeleton className="h-36 w-full"/>
                    <Skeleton className="h-36 w-full"/>
                </div>
            </div>;
    }

    all_tags: list[str] = [];
    if bundle {
        for c in bundle.projects {
            for t in c.project.tags {
                if t not in all_tags {
                    all_tags.append(t);
                }
            }
        }
    }
    shown = (
        [
            c
            for c in bundle.projects
            if not tag or tag in c.project.tags
        ]
        if bundle
        else []
    );

    return
        <div className="mx-auto w-full max-w-5xl px-4 py-8">
            <h1 className="mb-1 text-3xl font-extrabold tracking-tight">Discover</h1>
            <p className="mb-6 text-muted-foreground">
                {"Current entries, active projects, and the people building them"
                    + (
                        " — Cycle " + pad_cycle(bundle.cycle_number)
                        if bundle
                        else ""
                    )}
            </p>
            <Tabs defaultValue="cycle">
                <TabsList>
                    <TabsTrigger value="cycle">
                        {"This cycle ("
                            + (str(len(bundle.cycle_entries)) if bundle else "0")
                            + ")"}
                    </TabsTrigger>
                    <TabsTrigger value="projects">Projects</TabsTrigger>
                    <TabsTrigger value="first">First builds</TabsTrigger>
                    <TabsTrigger value="builders">Builders</TabsTrigger>
                </TabsList>
                <TabsContent value="cycle">
                    {if not bundle or len(bundle.cycle_entries) == 0 {
                        <EmptyState
                            title="No entries yet this cycle."
                            hint="The build window is open — be the first."
                        />
                    } else {
                        <div
                            className="grid grid-cols-1 items-start gap-3 md:grid-cols-2"
                        >
                            {for e in bundle.cycle_entries {
                                <EntryCard
                                    key={jid(e.entry)}
                                    bundle={e}
                                    judging={bundle.phase == "judging"}
                                    {loggedIn}
                                    onScored={refresh}
                                />
                            }}
                        </div>
                    }}
                </TabsContent>
                <TabsContent value="projects">
                    {if len(all_tags) > 0 {
                        <div className="mb-4 flex flex-wrap gap-1.5">
                            <button
                                type="button"
                                className={
                                    "rounded-full border px-2.5 py-1 text-xs "
                                    + (
                                        "border-primary bg-primary/10 text-primary"
                                        if not tag
                                        else "border-border text-muted-foreground"
                                    )
                                }
                                onClick={lambda { tag = ""; }}
                            >
                                all
                            </button>
                            {for t in all_tags {
                                <button
                                    type="button"
                                    key={t}
                                    className={
                                        "rounded-full border px-2.5 py-1 text-xs "
                                        + (
                                            "border-primary bg-primary/10 text-primary"
                                            if tag == t
                                            else "border-border text-muted-foreground"
                                        )
                                    }
                                    onClick={lambda { tag = t; }}
                                >
                                    {"#" + t}
                                </button>
                            }}
                        </div>
                    }}
                    {if len(shown) == 0 {
                        <EmptyState
                            title="No projects here yet."
                            hint="Create one and it shows up for everyone."
                        />
                    } else {
                        <div
                            className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3"
                        >
                            {for c in shown {
                                <ProjectTile key={c.project.slug} card={c}/>
                            }}
                        </div>
                    }}
                </TabsContent>
                <TabsContent value="first">
                    {if not bundle or len(bundle.first_builds) == 0 {
                        <EmptyState
                            title="No first builds this cycle."
                            hint="Best First Build protects newcomers — ship yours."
                        />
                    } else {
                        <div
                            className="grid grid-cols-1 items-start gap-3 md:grid-cols-2"
                        >
                            {for e in bundle.first_builds {
                                <EntryCard
                                    key={jid(e.entry)}
                                    bundle={e}
                                    judging={bundle.phase == "judging"}
                                    {loggedIn}
                                    onScored={refresh}
                                />
                            }}
                        </div>
                    }}
                </TabsContent>
                <TabsContent value="builders">
                    {if len(builders) == 0 {
                        <EmptyState title="Nobody here yet. Tell your friends."/>
                    } else {
                        <div
                            className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3"
                        >
                            {for c in builders {
                                <Link
                                    key={c.builder.handle}
                                    to={"/b/" + c.builder.handle}
                                    className="flex items-center gap-3 rounded-xl border border-border bg-card p-4 transition-colors hover:border-primary/40"
                                >
                                    <Avatar
                                        handle={c.builder.handle}
                                        hue={c.builder.avatar_hue}
                                        size="size-10"
                                    />
                                    <div className="min-w-0">
                                        <p className="truncate font-semibold">
                                            {c.builder.display_name or c.builder.handle}
                                        </p>
                                        <p
                                            className="text-xs text-muted-foreground"
                                        >
                                            {"@"
                                                + c.builder.handle
                                                + " · "
                                                + str(c.project_count)
                                                + " projects"
                                                + (
                                                    " · 🏆 " + str(c.award_count)
                                                    if c.award_count > 0
                                                    else ""
                                                )}
                                        </p>
                                    </div>
                                </Link>
                            }}
                        </div>
                    }}
                </TabsContent>
            </Tabs>
        </div>;
}
