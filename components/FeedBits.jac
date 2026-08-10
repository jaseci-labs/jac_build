"""jac.build — feed building blocks: post cards, composer, cycle banner."""

import from "@jac/runtime" { Link, useNavigate }
import from "lucide-react" { Rocket, Trophy, Megaphone, Hammer, PenLine }
import from .ui.button { Button }
import from .ui.textarea { Textarea }
import from .ui.card { Card, CardContent }
import from ..services.model { Post, CycleStatus, ProjectRole }
import from .bits { time_ago, pad_cycle, BuilderLink, countdown_label, PhaseChip }

def kind_icon(kind: str) -> JsxElement {
    if kind == "ship" {
        return <Rocket size={14} className="text-primary"/>;
    }
    if kind == "cycle" {
        return <Trophy size={14} className="text-amber-500"/>;
    }
    if kind == "announce" {
        return <Megaphone size={14} className="text-sky-500"/>;
    }
    if kind == "log" {
        return <Hammer size={14} className="text-emerald-500"/>;
    }
    return <PenLine size={14} className="text-muted-foreground"/>;
}

def kind_label(kind: str) -> str {
    if kind == "ship" {
        return "shipped a checkpoint";
    }
    if kind == "cycle" {
        return "cycle news";
    }
    if kind == "announce" {
        return "announcement";
    }
    if kind == "log" {
        return "build log";
    }
    return "note";
}

def:pub PostCard(post: Post) -> JsxElement {
    return
        <article
            className="flex gap-3 border-b border-border/70 px-1 py-4 last:border-b-0"
        >
            <div className="mt-1 shrink-0">{kind_icon(post.kind)}</div>
            <div className="min-w-0 flex-1">
                <p className="flex flex-wrap items-baseline gap-x-2 text-sm">
                    {if post.author_handle == "jac.build" {
                        <span className="font-mono-brand font-semibold text-primary">
                            jac.build
                        </span>
                    } else {
                        <BuilderLink handle={post.author_handle}/>
                    }}
                    <span className="text-xs text-muted-foreground">
                        {kind_label(post.kind)}
                    </span>
                    {if post.project_slug {
                        <Link
                            to={"/p/" + post.project_slug}
                            className="text-xs font-medium text-primary hover:underline"
                        >
                            {post.project_name}
                        </Link>
                    }}
                    <span className="text-xs text-muted-foreground/70">
                        {time_ago(post.created_at)}
                    </span>
                </p>
                <p
                    className="mt-1 whitespace-pre-wrap break-words text-[15px] leading-relaxed"
                >
                    {post.body}
                </p>
            </div>
        </article>;
}

def:pub Composer(
    myProjects: list[ProjectRole],
    onPost: Callable[[str, str], None],
    posting: bool
) -> JsxElement {
    has body: str = "",
        slug: str = "";

    return
        <Card className="border-border/60">
            <CardContent className="pt-4">
                <Textarea
                    placeholder="Narrate your work — what did you build today?"
                    value={body}
                    rows={2}
                    className="min-h-16 resize-none border-0 bg-transparent px-1 text-[15px] shadow-none focus-visible:ring-0"
                    onChange={lambda (e: ChangeEvent) { body = e.target.value; }}
                />
                <div className="mt-2 flex items-center justify-between gap-2">
                    <select
                        className="max-w-[55%] rounded-md border border-border bg-background px-2 py-1 text-xs text-muted-foreground"
                        value={slug}
                        onChange={lambda (e: ChangeEvent) { slug = e.target.value; }}
                    >
                        <option value="">Just a note</option>
                        {for r in myProjects {
                            <option value={r.project.slug} key={r.project.slug}>
                                {"Build log · " + r.project.name}
                            </option>
                        }}
                    </select>
                    <Button
                        size="sm"
                        className="rounded-full"
                        disabled={posting or not body.strip()}
                        onClick={lambda {
                            onPost(body, slug);
                            body = "";
                        }}
                    >
                        Post
                    </Button>
                </div>
            </CardContent>
        </Card>;
}

def:pub CycleBanner(status: CycleStatus) -> JsxElement {
    nav = useNavigate();
    return
        <div
            className="flex flex-wrap items-center gap-3 rounded-xl border border-primary/25 bg-gradient-to-r from-primary/15 via-primary/5 to-transparent px-4 py-3"
        >
            <span className="font-mono-brand text-sm font-bold text-primary">
                {"Cycle " + pad_cycle(status.number)}
            </span>
            <PhaseChip phase={status.phase}/>
            <span className="text-sm text-muted-foreground">
                {countdown_label(status.seconds_left, status.phase)}
                {" · "}
                {str(status.entry_count) + " entries so far"}
            </span>
            {if status.challenge {
                <span className="w-full text-sm text-foreground/80 sm:w-auto">
                    {"Challenge: " + status.challenge}
                </span>
            }}
            <div className="flex-1"/>
            {if status.phase == "building" {
                <Button
                    size="sm"
                    className="rounded-full"
                    onClick={lambda { nav("/enter"); }}
                >
                    Enter this cycle
                </Button>
            } else {
                <Button
                    size="sm"
                    variant="outline"
                    className="rounded-full"
                    onClick={lambda { nav("/cycle/" + str(status.number)); }}
                >
                    Judge entries
                </Button>
            }}
        </div>;
}
