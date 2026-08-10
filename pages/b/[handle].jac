"""jac.build — the builder profile: thin by design, an index into
projects and activity. The projects carry the weight."""

import from "@jac/runtime" { Link, useParams, jacIsLoggedIn }
import from "lucide-react" { Github, Globe, Bell, BellOff, ShieldCheck, Pencil }
import from ...components.ui.button { Button }
import from ...components.ui.skeleton { Skeleton }
import from ...components.ui.input { Input }
import from ...components.ui.textarea { Textarea }
import from ...components.FeedBits { PostCard }
import from ...components.bits { time_ago, Avatar, AwardChip, EmptyState }
import from ...services.social { get_builder, toggle_follow, setup_builder }
import from ...services.model { BuilderBundle }

def:pub page -> JsxPage {
    has bundle: BuilderBundle | None = None,
        loading: bool = True,
        loggedIn: bool = False,
        editing: bool = False,
        editName: str = "",
        editBio: str = "",
        editGithub: str = "",
        editWebsite: str = "",
        saving: bool = False;

    params = useParams();
    handle = params["handle"] or "";

    can with entry {
        loggedIn = jacIsLoggedIn();
        _ = load();
    }

    async def load -> None {
        w = root spawn get_builder(handle=str(handle));
        bundle = w.reports[0] if w.reports else None;
        loading = False;
    }

    async def follow -> None {
        if not bundle {
            return;
        }
        root spawn toggle_follow(target_id=jid(bundle.builder));
        _ = load();
    }

    async def save -> None {
        saving = True;
        root spawn setup_builder(
            display_name=editName.strip(),
            bio=editBio.strip(),
            github=editGithub.strip(),
            website=editWebsite.strip()
        );
        saving = False;
        editing = False;
        _ = load();
    }

    if loading {
        return
            <div className="mx-auto w-full max-w-3xl px-4 py-10">
                <div className="flex items-center gap-4">
                    <Skeleton className="size-16 rounded-full"/>
                    <div className="space-y-2">
                        <Skeleton className="h-5 w-48"/>
                        <Skeleton className="h-3 w-64"/>
                    </div>
                </div>
            </div>;
    }

    if not bundle {
        return
            <div className="mx-auto w-full max-w-3xl px-4 py-16">
                <EmptyState title="No builder by that handle."/>
            </div>;
    }

    b = bundle.builder;

    return
        <div className="mx-auto w-full max-w-3xl px-4 py-8">
            <header className="flex flex-col gap-4 sm:flex-row sm:items-start">
                <Avatar handle={b.handle} hue={b.avatar_hue} size="size-16 text-2xl"/>
                <div className="min-w-0 flex-1">
                    <div className="flex flex-wrap items-center gap-2">
                        <h1 className="text-2xl font-extrabold tracking-tight">
                            {b.display_name or b.handle}
                        </h1>
                        {if b.is_core {
                            <span
                                className="inline-flex items-center gap-1 rounded-full bg-primary/15 px-2 py-0.5 text-[11px] font-semibold text-primary"
                            >
                                <ShieldCheck size={11}/>
                                core team
                            </span>
                        }}
                        <div className="flex-1"/>
                        {if loggedIn and not bundle.is_me {
                            <Button
                                size="sm"
                                variant={
                                    "outline" if bundle.is_following else "default"
                                }
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
                        {if bundle.is_me {
                            <Button
                                size="sm"
                                variant="outline"
                                className="rounded-full"
                                onClick={lambda {
                                    editing = not editing;
                                    editName = b.display_name;
                                    editBio = b.bio;
                                    editGithub = b.github;
                                    editWebsite = b.website;
                                }}
                            >
                                <Pencil size={13}/>
                                {"Cancel" if editing else "Edit profile"}
                            </Button>
                        }}
                    </div>
                    <p className="text-sm text-muted-foreground">{"@" + b.handle}</p>
                    {if b.bio and not editing {
                        <p className="mt-2 text-sm leading-relaxed">{b.bio}</p>
                    }}
                    <div
                        className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1 text-sm text-muted-foreground"
                    >
                        <span>{str(bundle.followers) + " followers"}</span>
                        <span>{str(bundle.following) + " following"}</span>
                        <span>{"joined " + time_ago(b.joined_at)}</span>
                        {if b.github {
                            <a
                                href={"https://github.com/" + b.github}
                                target="_blank"
                                rel="noreferrer"
                                className="inline-flex items-center gap-1 hover:text-foreground"
                            >
                                <Github size={13}/>
                                {b.github}
                            </a>
                        }}
                        {if b.website {
                            <a
                                href={b.website}
                                target="_blank"
                                rel="noreferrer"
                                className="inline-flex items-center gap-1 hover:text-foreground"
                            >
                                <Globe size={13}/>
                                site
                            </a>
                        }}
                    </div>
                </div>
            </header>

            {if editing {
                <div
                    className="mt-6 flex flex-col gap-3 rounded-xl border border-border p-4"
                >
                    <Input
                        value={editName}
                        placeholder="Display name"
                        onChange={lambda (e: ChangeEvent) { editName = e.target.value; }}
                    />
                    <Textarea
                        value={editBio}
                        placeholder="Bio — what are you building?"
                        rows={3}
                        onChange={lambda (e: ChangeEvent) { editBio = e.target.value; }}
                    />
                    <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                        <Input
                            value={editGithub}
                            placeholder="GitHub username"
                            onChange={lambda (e: ChangeEvent) {
                                editGithub = e.target.value;
                            }}
                        />
                        <Input
                            value={editWebsite}
                            placeholder="https://your.site"
                            onChange={lambda (e: ChangeEvent) {
                                editWebsite = e.target.value;
                            }}
                        />
                    </div>
                    <Button
                        size="sm"
                        className="self-end rounded-full"
                        disabled={saving}
                        onClick={lambda { _ = save(); }}
                    >
                        {"Saving…" if saving else "Save profile"}
                    </Button>
                </div>
            }}

            {if len(bundle.awards) > 0 {
                <div className="mt-6 flex flex-wrap gap-1.5">
                    {for a in bundle.awards {
                        <AwardChip
                            key={jid(a)}
                            category={a.category}
                            cycle_number={a.cycle_number}
                        />
                    }}
                </div>
            }}

            <section className="mt-8">
                <h2 className="mb-3 text-lg font-bold">Projects</h2>
                {if len(bundle.projects) == 0 {
                    <EmptyState
                        title="No projects yet."
                        hint="Projects appear here once created or joined."
                    />
                } else {
                    <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                        {for r in bundle.projects {
                            <Link
                                key={r.project.slug}
                                to={"/p/" + r.project.slug}
                                className="group rounded-xl border border-border bg-card p-4 transition-colors hover:border-primary/40"
                            >
                                <div className="flex items-center gap-2">
                                    <span
                                        className="font-bold group-hover:text-primary"
                                    >
                                        {r.project.name}
                                    </span>
                                    <span
                                        className="rounded-full bg-secondary px-2 py-0.5 text-[10px] text-muted-foreground"
                                    >
                                        {r.role}
                                    </span>
                                </div>
                                {if r.project.one_liner {
                                    <p
                                        className="mt-1 line-clamp-2 text-sm text-muted-foreground"
                                    >
                                        {r.project.one_liner}
                                    </p>
                                }}
                                <p
                                    className="mt-2 text-xs text-muted-foreground"
                                >
                                    {str(r.checkpoint_count)
                                        + " checkpoints"
                                        + (
                                            " · 🏆 " + str(r.award_count)
                                            if r.award_count > 0
                                            else ""
                                        )}
                                </p>
                            </Link>
                        }}
                    </div>
                }}
            </section>

            <section className="mt-8">
                <h2 className="mb-1 text-lg font-bold">Posts</h2>
                {if len(bundle.posts) == 0 {
                    <EmptyState title="Nothing narrated yet."/>
                } else {
                    <div>
                        {for post in bundle.posts {
                            <PostCard key={jid(post)} {post}/>
                        }}
                    </div>
                }}
            </section>
        </div>;
}
