"""jac.build — the cycle archive and the cross-cycle standings."""

import from "@jac/runtime" { Link }
import from ..components.ui.skeleton { Skeleton }
import from ..components.FeedBits { CycleBanner }
import from ..components.bits { pad_cycle, PhaseChip, Avatar, EmptyState }
import from ..services.cycles { cycle_status, list_cycles, standings, CycleSummary }
import from ..services.model { CycleStatus, StandingsRow }

def:pub page -> JsxPage {
    has status: CycleStatus | None = None,
        rows: list[CycleSummary] = [],
        board: list[StandingsRow] = [],
        loading: bool = True;

    can with entry {
        _ = load();
    }

    async def load -> None {
        s = root spawn cycle_status();
        status = s.reports[0] if s.reports else None;
        c = root spawn list_cycles();
        rows = c.reports[0] if c.reports else [];
        t = root spawn standings();
        board = t.reports[0] if t.reports else [];
        loading = False;
    }

    return
        <div className="mx-auto w-full max-w-4xl px-4 py-8">
            <h1 className="mb-1 text-3xl font-extrabold tracking-tight">
                JacHacks Forever
            </h1>
            <p className="mb-6 text-muted-foreground">
                A cycle every two weeks. Numbered continuously, archived forever,
                zero gaps.
            </p>
            {if status {
                <CycleBanner {status}/>
            }}
            {if loading {
                <div className="mt-6 space-y-3">
                    <Skeleton className="h-16 w-full"/>
                    <Skeleton className="h-16 w-full"/>
                </div>
            } else {
                <div
                    className="mt-6 grid grid-cols-1 items-start gap-8 lg:grid-cols-5"
                >
                    <section className="lg:col-span-3">
                        <h2 className="mb-3 text-lg font-bold">All cycles</h2>
                        <div className="flex flex-col gap-2">
                            {for r in rows {
                                <Link
                                    key={str(r.cycle.number)}
                                    to={"/cycle/" + str(r.cycle.number)}
                                    className="flex flex-wrap items-center gap-3 rounded-xl border border-border bg-card px-4 py-3 transition-colors hover:border-primary/40"
                                >
                                    <span
                                        className="font-mono-brand text-base font-bold text-primary"
                                    >
                                        {"Cycle " + pad_cycle(r.cycle.number)}
                                    </span>
                                    <PhaseChip phase={r.phase}/>
                                    <span
                                        className="text-sm text-muted-foreground"
                                    >
                                        {str(r.entry_count) + " entries"}
                                    </span>
                                    {if r.award_count > 0 {
                                        <span
                                            className="text-sm text-amber-500"
                                        >
                                            {"🏆 " + str(r.award_count)}
                                        </span>
                                    }}
                                    {if r.cycle.challenge {
                                        <span
                                            className="w-full text-xs text-muted-foreground"
                                        >
                                            {"Challenge: " + r.cycle.challenge}
                                        </span>
                                    }}
                                </Link>
                            }}
                        </div>
                    </section>
                    <section className="lg:col-span-2">
                        <h2 className="mb-3 text-lg font-bold">Standings</h2>
                        {if len(board) == 0 {
                            <EmptyState
                                title="No entries scored yet."
                                hint="Standings build as cycles complete."
                            />
                        } else {
                            <div
                                className="overflow-hidden rounded-xl border border-border"
                            >
                                {for row in board {
                                    <Link
                                        key={row.handle}
                                        to={"/b/" + row.handle}
                                        className="flex items-center gap-3 border-b border-border/60 px-3 py-2.5 last:border-b-0 hover:bg-secondary/40"
                                    >
                                        <Avatar
                                            handle={row.handle}
                                            hue={row.avatar_hue}
                                            size="size-7"
                                        />
                                        <div className="min-w-0 flex-1">
                                            <p
                                                className="truncate text-sm font-medium"
                                            >
                                                {row.display_name}
                                            </p>
                                            <p
                                                className="text-xs text-muted-foreground"
                                            >
                                                {str(row.entries)
                                                    + " entries · best streak "
                                                    + str(row.best_streak)}
                                            </p>
                                        </div>
                                        {if row.wins > 0 {
                                            <span
                                                className="text-sm font-semibold text-amber-500"
                                            >
                                                {"🏆 " + str(row.wins)}
                                            </span>
                                        }}
                                    </Link>
                                }}
                            </div>
                        }}
                    </section>
                </div>
            }}
        </div>;
}
