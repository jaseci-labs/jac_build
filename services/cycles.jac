"""jac.build — the JacHacks Forever cycle engine's read and judge side.

Cycles are numbered continuously and roll with zero gap (the clock
lives in model.jac). This module serves cycle pages, the status banner,
community scoring, and the cross-cycle standings table.
"""

import datetime;
import from .model {
    Platform, Builder, Project, Cycle, Entry, Award, Checkpoint,
    RunsCycle, InCycle, Granted, Won, Registered, MemberOf, HasCheckpoint, EnteredAs,
    CycleStatus, CycleBundle, EntryBundle, StandingsRow,
    ensure_platform, ensure_current_cycle, cycle_by_number, cycle_entries,
    bundle_entry, entry_project, my_builder, project_streak,
    current_cycle_number, parse_iso, now_iso
}

obj CycleSummary {
    has cycle: Cycle,
        entry_count: int = 0,
        award_count: int = 0,
        phase: str = "";
}

def status_of(cycle: Cycle) -> CycleStatus {
    moment = datetime.datetime.now(datetime.UTC).replace(tzinfo=None);
    phase = cycle.phase();
    edge_at = (
        parse_iso(cycle.submissions_close_at)
        if phase == "building"
        else parse_iso(cycle.ends_at)
    );
    left = int((edge_at - moment).total_seconds());
    return CycleStatus(
        number=cycle.number,
        phase=phase,
        opens_at=cycle.opens_at,
        submissions_close_at=cycle.submissions_close_at,
        ends_at=cycle.ends_at,
        challenge=cycle.challenge,
        entry_count=len(cycle_entries(cycle)),
        seconds_left=max(left, 0)
    );
}

walker:pub cycle_status {
    has reports: list[CycleStatus] = [];

    can run with Root entry {
        hub = ensure_platform();
        report status_of(ensure_current_cycle(hub));
    }
}

walker:pub get_cycle {
    has number: int = 0,
        reports: list[CycleBundle] = [];

    can run with Root entry {
        hub = ensure_platform();
        maybe = (
            ensure_current_cycle(hub)
            if self.number <= 0
            else cycle_by_number(hub, self.number)
        );
        if not maybe {
            disengage;
        }
        cycle = maybe as Cycle;
        me = my_builder();
        mine = me.handle if me else "";
        entries = [bundle_entry(e, mine) for e in cycle_entries(cycle)];
        entries.sort(key=lambda (e: EntryBundle) { e.score_avg; }, reverse=True);
        prizes = [cycle->:Granted:->[?:Award]];
        prizes.sort(key=lambda (a: Award) { a.category; });
        report CycleBundle(
            cycle=cycle,
            phase=cycle.phase(),
            fresh=[e for e in entries if e.entry.track == "fresh"],
            glowup=[e for e in entries if e.entry.track == "glowup"],
            awards=prizes
        );
    }
}

walker:pub list_cycles {
    has reports: list[list[CycleSummary]] = [];

    can run with Root entry {
        hub = ensure_platform();
        ensure_current_cycle(hub);
        rows = [
            CycleSummary(
                cycle=c,
                entry_count=len(cycle_entries(c)),
                award_count=len([c->:Granted:->[?:Award]]),
                phase=c.phase()
            )
            for c in [hub->:RunsCycle:->[?:Cycle]]
        ];
        rows.sort(key=lambda (r: CycleSummary) { r.cycle.number; }, reverse=True);
        report rows;
    }
}

"""Community scoring: one score per member per entry, judging window
only, never your own project. Standing-weighted judging can layer on
later; the score record keeps who said what."""
walker score_entry {
    has entry_id: str = "",
        substance: int = 3,
        leap: int = 3,
        depth: int = 3,
        narration: int = 3,
        reports: list[dict] = [];

    can run with Root entry {
        maybe_me = my_builder();
        if not maybe_me {
            report {"ok": False, "error": "Log in to judge."};
            disengage;
        }
        found = jobj(self.entry_id);
        if not isinstance(found, Entry) {
            report {"ok": False, "error": "No such entry."};
            disengage;
        }
        me = maybe_me as Builder;
        target = found as Entry;
        hub = ensure_platform();
        cycle = cycle_by_number(hub, target.cycle_number);
        if not cycle or cycle.phase() == "building" {
            report {"ok": False, "error": "Scoring opens when the build window closes."};
            disengage;
        }
        if cycle.finalized {
            report {"ok": False, "error": "This cycle is already finalized."};
            disengage;
        }
        home = entry_project(target);
        if home and [edge me->:MemberOf:->home] {
            report {"ok": False, "error": "You can't score your own project."};
            disengage;
        }
        clamp = lambda (v: int) { min(max(v, 1), 5); };
        fresh_score = {
            "by": me.handle,
            "substance": clamp(self.substance),
            "leap": clamp(self.leap),
            "depth": clamp(self.depth),
            "narration": clamp(self.narration),
            "total": (
                clamp(self.substance) + clamp(self.leap)
                + clamp(self.depth) + clamp(self.narration)
            ) / 4.0,
            "at": now_iso()
        };
        kept = [s for s in target.scores if s.get("by", "") != me.handle];
        kept.append(fresh_score);
        target.scores = kept;
        report {"ok": True, "score_avg": target.score_avg(), "count": len(kept)};
    }
}

walker set_challenge {
    has number: int = 0,
        challenge: str = "",
        reports: list[dict] = [];

    can run with Root entry {
        me = my_builder();
        if not (me and me.is_core) {
            report {"ok": False};
            disengage;
        }
        hub = ensure_platform();
        cycle = (
            ensure_current_cycle(hub)
            if self.number <= 0
            else cycle_by_number(hub, self.number)
        );
        if cycle {
            cycle.challenge = self.challenge.strip();
            report {"ok": True};
        }
    }
}

walker:pub standings {
    has reports: list[list[StandingsRow]] = [];

    can run with Root entry {
        hub = ensure_platform();
        now_n = current_cycle_number(hub);
        rows: list[StandingsRow] = [];
        for b in [hub->:Registered:->[?:Builder]] {
            wins = 0;
            entered = 0;
            best_streak = 0;
            for p in [b->:MemberOf:->[?:Project]] {
                run = project_streak(p, now_n);
                if run > best_streak {
                    best_streak = run;
                }
                for point in [p->:HasCheckpoint:->[?:Checkpoint]] {
                    for e in [point->:EnteredAs:->[?:Entry]] {
                        entered += 1;
                        wins += len([e->:Won:->[?:Award]]);
                    }
                }
            }
            if entered > 0 {
                rows.append(
                    StandingsRow(
                        handle=b.handle,
                        display_name=b.display_name or b.handle,
                        avatar_hue=b.avatar_hue,
                        wins=wins,
                        entries=entered,
                        best_streak=best_streak
                    )
                );
            }
        }
        rows.sort(
            key=lambda (r: StandingsRow) { r.wins * 1000 + r.entries; }, reverse=True
        );
        report rows[:50];
    }
}
