"""jac.build — one cycle: entries by track, judging, and the permanent
award record. Live while running, archived forever after."""

import from "@jac/runtime" { useParams, jacIsLoggedIn }
import from ...components.ui.skeleton { Skeleton }
import from ...components.bits { pad_cycle, PhaseChip, AwardChip, EmptyState }
import from ...components.Cards { EntryCard }
import from ...services.cycles { get_cycle }
import from ...services.model { CycleBundle }

def:pub page -> JsxPage {
    has bundle: CycleBundle | None = None,
        loading: bool = True,
        loggedIn: bool = False;

    params = useParams();
    num = params["num"] or "0";

    can with entry {
        loggedIn = jacIsLoggedIn();
        _ = load();
    }

    async def load -> None {
        w = root spawn get_cycle(number=int(str(num)));
        bundle = w.reports[0] if w.reports else None;
        loading = False;
    }

    def rescore -> None {
        _ = load();
    }

    if loading {
        return
            <div className="mx-auto w-full max-w-4xl px-4 py-10">
                <Skeleton className="h-8 w-52"/>
                <Skeleton className="mt-4 h-32 w-full"/>
            </div>;
    }

    if not bundle {
        return
            <div className="mx-auto w-full max-w-4xl px-4 py-16">
                <EmptyState
                    title="That cycle doesn't exist yet."
                    hint="Cycles materialize on schedule — check the archive."
                />
            </div>;
    }

    judging = bundle.phase == "judging";

    return
        <div className="mx-auto w-full max-w-4xl px-4 py-8">
            <div className="flex flex-wrap items-center gap-3">
                <h1 className="font-mono-brand text-3xl font-extrabold text-primary">
                    {"Cycle " + pad_cycle(bundle.cycle.number)}
                </h1>
                <PhaseChip phase={bundle.phase}/>
                <span className="text-sm text-muted-foreground">
                    {bundle.cycle.opens_at.split("T")[0]
                        + " → "
                        + bundle.cycle.ends_at.split("T")[0]}
                </span>
            </div>
            {if bundle.cycle.challenge {
                <p
                    className="mt-2 rounded-lg border border-primary/25 bg-primary/5 px-3 py-2 text-sm"
                >
                    {"Cycle Challenge: " + bundle.cycle.challenge}
                </p>
            }}
            {if judging {
                <p className="mt-3 text-sm text-muted-foreground">
                    The build window is closed — the community is judging. Score
                    entries on substance, relative leap, Jac depth, and
                    narration. Awards land when the cycle rolls.
                </p>
            }}

            {if len(bundle.awards) > 0 {
                <section className="mt-6">
                    <h2 className="mb-2 text-lg font-bold">Awards</h2>
                    <div className="flex flex-wrap gap-2">
                        {for a in bundle.awards {
                            <span key={jid(a)} className="flex items-center gap-2">
                                <AwardChip category={a.category}/>
                                <span className="text-sm text-muted-foreground">
                                    {a.project_name}
                                </span>
                            </span>
                        }}
                    </div>
                </section>
            }}

            <div className="mt-8 grid grid-cols-1 items-start gap-8 lg:grid-cols-2">
                <section>
                    <h2 className="mb-3 text-lg font-bold">
                        {"Fresh Builds (" + str(len(bundle.fresh)) + ")"}
                    </h2>
                    {if len(bundle.fresh) == 0 {
                        <EmptyState
                            title="No fresh builds yet."
                            hint="A project's first checkpoint lands here."
                        />
                    } else {
                        <div className="flex flex-col gap-3">
                            {for e in bundle.fresh {
                                <EntryCard
                                    key={jid(e.entry)}
                                    bundle={e}
                                    {judging}
                                    {loggedIn}
                                    onScored={rescore}
                                />
                            }}
                        </div>
                    }}
                </section>
                <section>
                    <h2 className="mb-3 text-lg font-bold">
                        {"Glow-Ups (" + str(len(bundle.glowup)) + ")"}
                    </h2>
                    {if len(bundle.glowup) == 0 {
                        <EmptyState
                            title="No glow-ups yet."
                            hint="Returning projects are judged on the diff."
                        />
                    } else {
                        <div className="flex flex-col gap-3">
                            {for e in bundle.glowup {
                                <EntryCard
                                    key={jid(e.entry)}
                                    bundle={e}
                                    {judging}
                                    {loggedIn}
                                    onScored={rescore}
                                />
                            }}
                        </div>
                    }}
                </section>
            </div>
        </div>;
}
