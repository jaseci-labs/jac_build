"""jac.build — create a project: one node, alive forever."""

import from "@jac/runtime" { useNavigate, jacIsLoggedIn, Navigate }
import from ...components.ui.button { Button }
import from ...components.ui.input { Input }
import from ...components.ui.label { Label }
import from ...components.ui.textarea { Textarea }
import from ...components.ui.card { Card, CardContent }
import from ...services.projects { create_project }

def:pub page -> JsxPage {
    has name: str = "",
        oneLiner: str = "",
        description: str = "",
        tags: str = "",
        repoUrl: str = "",
        creating: bool = False,
        error: str = "";

    nav = useNavigate();

    async def submit -> None {
        error = "";
        if not name.strip() {
            error = "Give it a name.";
            return;
        }
        creating = True;
        w = root spawn create_project(
            name=name,
            one_liner=oneLiner,
            description=description,
            tags=[t.strip() for t in tags.split(",") if t.strip()],
            repo_url=repoUrl
        );
        got = w.reports[0] if w.reports else None;
        creating = False;
        if got {
            nav("/p/" + got.project.slug);
        } else {
            error = "Could not create the project.";
        }
    }

    if not jacIsLoggedIn() {
        return <Navigate to="/login" replace={True}/>;
    }

    return
        <div className="mx-auto w-full max-w-xl px-4 py-8">
            <h1 className="mb-1 text-3xl font-extrabold tracking-tight">
                New project
            </h1>
            <p className="mb-6 text-muted-foreground">
                Created once, lives forever. It gets a page, a timeline, and
                followers — hackathons become moments in its life.
            </p>
            <Card className="border-border/60">
                <CardContent className="flex flex-col gap-4 pt-5">
                    <div className="flex flex-col gap-1.5">
                        <Label htmlFor="np-name">Name</Label>
                        <Input
                            id="np-name"
                            placeholder="walker-quest"
                            value={name}
                            onChange={lambda (e: ChangeEvent) { name = e.target.value; }}
                        />
                    </div>
                    <div className="flex flex-col gap-1.5">
                        <Label htmlFor="np-line">One-liner</Label>
                        <Input
                            id="np-line"
                            placeholder="A dungeon crawler where every room is a graph node"
                            value={oneLiner}
                            onChange={lambda (e: ChangeEvent) {
                                oneLiner = e.target.value;
                            }}
                        />
                    </div>
                    <div className="flex flex-col gap-1.5">
                        <Label htmlFor="np-desc">Description</Label>
                        <Textarea
                            id="np-desc"
                            rows={4}
                            placeholder="What is it, who's it for, and where is it going?"
                            value={description}
                            onChange={lambda (e: ChangeEvent) {
                                description = e.target.value;
                            }}
                        />
                    </div>
                    <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                        <div className="flex flex-col gap-1.5">
                            <Label htmlFor="np-tags">Tags (comma-separated)</Label>
                            <Input
                                id="np-tags"
                                placeholder="game, walkers, by-llm"
                                value={tags}
                                onChange={lambda (e: ChangeEvent) {
                                    tags = e.target.value;
                                }}
                            />
                        </div>
                        <div className="flex flex-col gap-1.5">
                            <Label htmlFor="np-repo">Repo URL</Label>
                            <Input
                                id="np-repo"
                                placeholder="https://github.com/you/project"
                                value={repoUrl}
                                onChange={lambda (e: ChangeEvent) {
                                    repoUrl = e.target.value;
                                }}
                            />
                        </div>
                    </div>
                    {if error {
                        <p className="text-sm text-destructive">{error}</p>
                    }}
                    <Button
                        className="self-end rounded-full px-6"
                        disabled={creating}
                        onClick={lambda { _ = submit(); }}
                    >
                        {"Creating…" if creating else "Create project"}
                    </Button>
                </CardContent>
            </Card>
        </div>;
}
