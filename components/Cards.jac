"""jac.build — entry and project cards, plus the community judge panel."""

import from "@jac/runtime" { Link }
import from "lucide-react" {
    GitCommitHorizontal, ExternalLink, Users, Flag, Sparkles
}
import from .ui.button { Button }
import from .ui.card { Card, CardContent }
import from ..services.model { EntryBundle, Project }
import from ..services.projects { ProjectCard as ProjectCardData }
import from ..services.cycles { score_entry }
import from .bits { time_ago, short_sha, TrackChip, AwardChip }

def:pub ScorePanel(
    entryId: str, alreadyScored: bool, onScored: Callable[[], None]
) -> JsxElement {
    has substance: int = 3,
        leap: int = 3,
        depth: int = 3,
        narration: int = 3,
        sending: bool = False,
        sent: bool = False,
        note: str = "";

    async def send -> None {
        sending = True;
        w = root spawn score_entry(
            entry_id=entryId,
            substance=substance,
            leap=leap,
            depth=depth,
            narration=narration
        );
        got = w.reports[0] if w.reports else None;
        sending = False;
        if got and got["ok"] {
            sent = True;
            note = "";
            onScored();
        } else {
            note = str(got["error"]) if got else "Scoring failed.";
        }
    }

    if sent {
        return
            <p className="text-xs font-medium text-emerald-500">
                Score recorded — thank you for judging.
            </p>;
    }

    return
        <div className="mt-3 rounded-lg border border-border/70 bg-secondary/40 p-3">
            <p
                className="mb-2 text-[11px] font-semibold uppercase tracking-wider text-muted-foreground"
            >
                {"Rescore this entry" if alreadyScored else "Community judging"}
            </p>
            <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
                <Criterion
                    label="Substance"
                    value={substance}
                    onPick={lambda (v: int) { substance = v; }}
                />
                <Criterion
                    label="Relative leap"
                    value={leap}
                    onPick={lambda (v: int) { leap = v; }}
                />
                <Criterion
                    label="Jac depth"
                    value={depth}
                    onPick={lambda (v: int) { depth = v; }}
                />
                <Criterion
                    label="Narration"
                    value={narration}
                    onPick={lambda (v: int) { narration = v; }}
                />
            </div>
            {if note {
                <p className="mt-2 text-xs text-destructive">{note}</p>
            }}
            <Button
                size="sm"
                className="mt-2 rounded-full"
                disabled={sending}
                onClick={lambda { _ = send(); }}
            >
                {"Scoring…" if sending else "Submit score"}
            </Button>
        </div>;
}

def Criterion(label: str, value: int, onPick: Callable[[int], None]) -> JsxElement {
    return
        <div>
            <p className="mb-1 text-[11px] text-muted-foreground">{label}</p>
            <div className="flex gap-1">
                {[
                    <button
                        type="button"
                        key={n}
                        className={
                            "size-5 rounded-full border text-[10px] font-semibold transition-colors "
                            + (
                                "border-primary bg-primary text-primary-foreground"
                                if n <= value
                                else "border-border bg-background text-muted-foreground hover:border-primary/50"
                            )
                        }
                        onClick={lambda { onPick(n); }}
                    >
                        {n}
                    </button> for n in range(1, 6)
                ]}
            </div>
        </div>;
}

def:pub EntryCard(
    bundle: EntryBundle, judging: bool, loggedIn: bool, onScored: Callable[[], None]
) -> JsxElement {
    ent = bundle.entry;
    proj = bundle.project;
    point = bundle.checkpoint;
    return
        <Card className="border-border/60">
            <CardContent className="pt-4">
                <div className="flex flex-wrap items-center gap-2">
                    {if proj {
                        <Link
                            to={"/p/" + proj.slug}
                            className="font-bold hover:text-primary"
                        >
                            {proj.name}
                        </Link>
                    }}
                    <TrackChip track={ent.track}/>
                    {if ent.is_first_build {
                        <span
                            className="rounded-full bg-sky-500/15 px-2 py-0.5 text-[11px] font-semibold text-sky-500"
                        >
                            First build
                        </span>
                    }}
                    {if ent.is_comeback {
                        <span
                            className="rounded-full bg-violet-500/15 px-2 py-0.5 text-[11px] font-semibold text-violet-500"
                        >
                            Comeback
                        </span>
                    }}
                    <span className="text-xs text-muted-foreground">
                        {time_ago(ent.submitted_at)}
                    </span>
                    <div className="flex-1"/>
                    {if bundle.score_avg > 0.0 {
                        <span
                            className="font-mono-brand text-sm font-bold text-primary"
                            title={str(len(ent.scores)) + " community scores"}
                        >
                            {str(bundle.score_avg)}
                        </span>
                    }}
                </div>
                {if proj and proj.one_liner {
                    <p className="mt-1 text-sm text-muted-foreground">
                        {proj.one_liner}
                    </p>
                }}
                {if point {
                    <p className="mt-2 whitespace-pre-wrap text-sm leading-relaxed">
                        {point.write_up}
                    </p>
                }}
                {if ent.track == "glowup" {
                    <div
                        className="mt-3 rounded-lg border border-primary/20 bg-primary/5 p-3"
                    >
                        <div
                            className="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-muted-foreground"
                        >
                            <span className="inline-flex items-center gap-1">
                                <GitCommitHorizontal size={13}/>
                                {short_sha(ent.base_sha) + " → " + short_sha(ent.head_sha)}
                            </span>
                            {if ent.commits_count > 0 {
                                <>
                                    <span>{str(ent.commits_count) + " commits"}</span>
                                    <span>{str(ent.files_changed) + " files"}</span>
                                    <span className="text-emerald-500">
                                        {"+" + str(ent.additions)}
                                    </span>
                                    <span className="text-red-500">
                                        {"-" + str(ent.deletions)}
                                    </span>
                                </>
                            }}
                            {if ent.compare_url {
                                <a
                                    href={ent.compare_url}
                                    target="_blank"
                                    rel="noreferrer"
                                    className="inline-flex items-center gap-1 text-primary hover:underline"
                                >
                                    diff
                                    <ExternalLink size={11}/>
                                </a>
                            }}
                        </div>
                        {if ent.diff_digest {
                            <p
                                className="mt-2 text-xs leading-relaxed text-muted-foreground"
                            >
                                <span
                                    className="mr-1 inline-flex items-center gap-1 font-semibold text-foreground/70"
                                >
                                    <Sparkles size={11}/>
                                    {"Diff digest"
                                        + (
                                            " (model-generated)"
                                            if ent.digest_source == "llm"
                                            else " (commit log)"
                                        )
                                        + ":"}
                                </span>
                                {ent.diff_digest}
                            </p>
                        }}
                    </div>
                }}
                {if len(ent.categories) > 0 {
                    <div className="mt-2 flex flex-wrap gap-1.5">
                        {for c in ent.categories {
                            <span
                                key={c}
                                className="rounded-full border border-border px-2 py-0.5 text-[11px] text-muted-foreground"
                            >
                                <Flag size={10} className="mr-1 inline"/>
                                {c}
                            </span>
                        }}
                    </div>
                }}
                {if len(bundle.awards) > 0 {
                    <div className="mt-2 flex flex-wrap gap-1.5">
                        {for a in bundle.awards {
                            <AwardChip
                                key={jid(a)}
                                category={a.category}
                                cycle_number={a.cycle_number}
                            />
                        }}
                    </div>
                }}
                {if judging and loggedIn {
                    <ScorePanel
                        entryId={jid(ent)}
                        alreadyScored={bundle.scored_by_me}
                        {onScored}
                    />
                }}
            </CardContent>
        </Card>;
}

def:pub ProjectTile(card: ProjectCardData) -> JsxElement {
    p = card.project;
    return
        <Link
            to={"/p/" + p.slug}
            className="group flex flex-col gap-2 rounded-xl border border-border bg-card p-4 transition-colors hover:border-primary/40"
        >
            <div className="flex items-center gap-2">
                <span className="font-bold group-hover:text-primary">
                    {p.name}
                </span>
                {if p.status != "active" {
                    <span
                        className="rounded-full bg-muted px-2 py-0.5 text-[10px] uppercase tracking-wide text-muted-foreground"
                    >
                        {p.status}
                    </span>
                }}
            </div>
            {if p.one_liner {
                <p className="line-clamp-2 text-sm text-muted-foreground">
                    {p.one_liner}
                </p>
            }}
            {if len(p.tags) > 0 {
                <div className="flex flex-wrap gap-1">
                    {for t in p.tags {
                        <span
                            key={t}
                            className="rounded-full bg-secondary px-2 py-0.5 text-[10px] text-muted-foreground"
                        >
                            {"#" + t}
                        </span>
                    }}
                </div>
            }}
            <div
                className="mt-auto flex items-center gap-3 pt-1 text-xs text-muted-foreground"
            >
                <span className="inline-flex items-center gap-1">
                    <GitCommitHorizontal size={12}/>
                    {str(card.checkpoint_count)}
                </span>
                <span className="inline-flex items-center gap-1">
                    <Users size={12}/>
                    {str(card.followers)}
                </span>
                {if card.award_count > 0 {
                    <span className="inline-flex items-center gap-1 text-amber-500">
                        {"🏆 " + str(card.award_count)}
                    </span>
                }}
                <span className="ml-auto">
                    {time_ago(card.last_checkpoint_at)}
                </span>
            </div>
        </Link>;
}
