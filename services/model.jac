"""jac.build — the graph.

One graph, per the design doc: builders, projects, checkpoints, posts,
cycles, entries, awards, and popups are nodes; every feature is a
traversal. Shared, discoverable structure (the platform hub, cycles,
projects) hangs off `root.shared`; builder-owned records (profiles,
posts, checkpoints) hang off each builder's root and link into the
commons by edge.

Access is declared on the archetypes themselves: jac.build is "public
by default, attributable always", so openness is an invariant of each
TYPE, not a per-creation-site grant. `__jac_access__` encodes it —
including Project's rule that WRITE access *is* team membership, read
straight off the MemberOf edge.
"""

import datetime;

glob CYCLE_DAYS: int = 14;
glob BUILD_DAYS: int = 12;
glob LONG_HAUL_STREAK: int = 3;
glob COMEBACK_GAP_CYCLES: int = 3;

glob FRESH_CATEGORIES: list[str] = [
         "Best in Cycle",
         "Deepest Jac",
         "Best First Build",
         "Most Useful",
         "Wildcard / Weird",
     ];

glob GLOWUP_CATEGORIES: list[str] = [
         "Best Glow-Up",
         "Deepest Cut",
         "The Long Haul",
         "Best Comeback",
     ];

def now_iso -> str {
    return datetime.datetime.now(datetime.UTC).replace(tzinfo=None).isoformat() + "Z";
}

def parse_iso(stamp: str) -> datetime.datetime {
    return datetime.datetime.fromisoformat(stamp.rstrip("Z"));
}

def iso_of(moment: datetime.datetime) -> str {
    return moment.isoformat() + "Z";
}

# --- Edges ------------------------------------------------------------

edge Registered {}      # Platform -> Builder      (the member directory)
edge Hosts {}           # Platform -> Project      (the project registry)
edge RunsCycle {}       # Platform -> Cycle
edge HostsPopup {}      # Platform -> Popup
edge Announced {}       # Platform -> Post         (platform-voice posts: awards, cycle news)
edge Follows {}         # Builder -> Builder | Project
edge MemberOf { has role: str = "owner", since: str = ""; }   # Builder -> Project
edge Authored {}        # Builder -> Post
edge About {}           # Post -> Project
edge HasCheckpoint {}   # Project -> Checkpoint
edge EnteredAs {}       # Checkpoint -> Entry
edge InCycle {}         # Entry -> Cycle
edge Won {}             # Entry -> Award
edge Granted {}         # Cycle -> Award

# --- Nodes ------------------------------------------------------------

node Platform {
    has epoch_iso: str = "",
        founder_handle: str = "",
        created_at: str = "";

    # Anyone (including anonymous readers) may traverse the hub and
    # attach registry edges; only the owner mutates its fields.
    def __jac_access__ -> AccessLevel {
        return AccessLevel.CONNECT;
    }
}

node Cycle {
    has number: int = 0,
        opens_at: str = "",
        submissions_close_at: str = "",
        ends_at: str = "",
        finalized: bool = False,
        challenge: str = "";

    # WRITE: rollover is lazy — whichever request first touches a cycle
    # past its end finalizes it (mutating `finalized`), and that request
    # can come from any user.
    def __jac_access__ -> AccessLevel {
        return AccessLevel.WRITE;
    }

    def phase -> str {
        moment = datetime.datetime.now(datetime.UTC).replace(tzinfo=None);
        if moment < parse_iso(self.submissions_close_at) {
            return "building";
        }
        if moment < parse_iso(self.ends_at) {
            return "judging";
        }
        return "complete";
    }
}

node Builder {
    has handle: str = "",
        display_name: str = "",
        bio: str = "",
        github: str = "",
        website: str = "",
        avatar_hue: int = 21,
        is_core: bool = False,
        joined_at: str = "";

    # CONNECT: others follow you (edge-attach); only you edit your profile.
    def __jac_access__ -> AccessLevel {
        return AccessLevel.CONNECT;
    }
}

node Project {
    has name: str = "",
        slug: str = "",
        one_liner: str = "",
        description: str = "",
        tags: list[str] = [],
        repo_url: str = "",
        status: str = "active",
        created_at: str = "";

    # Team membership IS write access: the MemberOf edge is the
    # permission record, read at access-check time. Everyone else gets
    # CONNECT (follow it, post about it) — the public-by-default floor.
    def __jac_access__ -> AccessLevel {
        mine = [root-->[?:Builder]];
        if mine and [edge mine[0] ->:MemberOf:-> self] {
            return AccessLevel.WRITE;
        }
        return AccessLevel.CONNECT;
    }

    def members -> list {
        return [self<-:MemberOf:<-[?:Builder]];
    }

    def checkpoints_sorted -> list {
        points = [self->:HasCheckpoint:->[?:Checkpoint]];
        points.sort(key=lambda (c: Checkpoint) { c.number; });
        return points;
    }
}

node Checkpoint {
    has number: int = 0,
        sha: str = "",
        write_up: str = "",
        demo_url: str = "",
        deployed_url: str = "",
        created_at: str = "";

    # An immutable public snapshot record — the archive's atom.
    def __jac_access__ -> AccessLevel {
        return AccessLevel.READ;
    }
}

node Entry {
    has track: str = "fresh",
        categories: list[str] = [],
        cycle_number: int = 0,
        submitted_at: str = "",
        base_sha: str = "",
        head_sha: str = "",
        compare_url: str = "",
        commits_count: int = 0,
        additions: int = 0,
        deletions: int = 0,
        files_changed: int = 0,
        commit_log: list[str] = [],
        diff_digest: str = "",
        digest_source: str = "",
        is_first_build: bool = False,
        is_comeback: bool = False,
        scores: list[dict] = [];

    # WRITE: community scoring appends to `scores`; finalize attaches Won.
    def __jac_access__ -> AccessLevel {
        return AccessLevel.WRITE;
    }

    def score_avg -> float {
        if not self.scores {
            return 0.0;
        }
        total = 0.0;
        for s in self.scores {
            total += float(s.get("total", 0));
        }
        return round(total / len(self.scores), 2);
    }

    def depth_avg -> float {
        if not self.scores {
            return 0.0;
        }
        total = 0.0;
        for s in self.scores {
            total += float(s.get("depth", 0));
        }
        return round(total / len(self.scores), 2);
    }
}

node Award {
    has category: str = "",
        track: str = "",
        cycle_number: int = 0,
        project_name: str = "",
        project_slug: str = "",
        builder_handles: list[str] = [],
        awarded_at: str = "";

    def __jac_access__ -> AccessLevel {
        return AccessLevel.READ;
    }
}

node Post {
    has kind: str = "note",   # note | log | ship | cycle | announce
        body: str = "",
        author_handle: str = "",
        project_slug: str = "",
        project_name: str = "",
        cycle_number: int = 0,
        created_at: str = "";

    def __jac_access__ -> AccessLevel {
        return AccessLevel.READ;
    }
}

node Popup {
    has title: str = "",
        city: str = "",
        host_handle: str = "",
        date_iso: str = "",
        headcount: int = 0,
        format: str = "4h",
        needs: str = "",
        tier: str = "",
        status: str = "applied",   # applied | approved | completed | declined
        recap: str = "",
        recap_headcount: int = 0,
        decided_note: str = "",
        created_at: str = "";

    # WRITE: core review and the organizer's wrap both mutate status.
    def __jac_access__ -> AccessLevel {
        return AccessLevel.WRITE;
    }
}

# --- Report bundles: a node plus the edge-derived context the client
#     needs beside it. Nodes travel whole — identity included. --------

obj TeamMember {
    has builder: Builder,
        role: str = "",
        since: str = "";
}

obj EntryBundle {
    has entry: Entry,
        project: Project | None = None,
        checkpoint: Checkpoint | None = None,
        awards: list[Award] = [],
        score_avg: float = 0.0,
        scored_by_me: bool = False;
}

obj ProjectBundle {
    has project: Project,
        team: list[TeamMember] = [],
        checkpoints: list[Checkpoint] = [],
        entries: list[EntryBundle] = [],
        awards: list[Award] = [],
        posts: list[Post] = [],
        followers: int = 0,
        is_following: bool = False,
        my_role: str = "",
        streak: int = 0;
}

obj ProjectRole {
    has project: Project,
        role: str = "",
        checkpoint_count: int = 0,
        award_count: int = 0;
}

obj BuilderBundle {
    has builder: Builder,
        projects: list[ProjectRole] = [],
        awards: list[Award] = [],
        posts: list[Post] = [],
        followers: int = 0,
        following: int = 0,
        is_following: bool = False,
        is_me: bool = False;
}

obj CycleStatus {
    has number: int = 0,
        phase: str = "building",
        opens_at: str = "",
        submissions_close_at: str = "",
        ends_at: str = "",
        challenge: str = "",
        entry_count: int = 0,
        seconds_left: int = 0;
}

obj CycleBundle {
    has cycle: Cycle,
        phase: str = "building",
        fresh: list[EntryBundle] = [],
        glowup: list[EntryBundle] = [],
        awards: list[Award] = [];
}

obj StandingsRow {
    has handle: str = "",
        display_name: str = "",
        avatar_hue: int = 21,
        wins: int = 0,
        entries: int = 0,
        best_streak: int = 0;
}

# --- The commons hub --------------------------------------------------

def ensure_platform -> Platform {
    hubs = [root.shared-->[?:Platform]];
    if hubs {
        return hubs[0];
    }
    stamp = now_iso();
    return (
        root.shared ++> Platform(epoch_iso=stamp, created_at=stamp)
    ) as Platform;
}

def my_builder -> Builder | None {
    mine = [root-->[?:Builder]];
    return mine[0] if mine else None;
}

def find_builder(hub: Platform, want: str) -> Builder | None {
    hits = [hub->:Registered:->[?:Builder, handle == want]];
    return hits[0] if hits else None;
}

def find_project(hub: Platform, want: str) -> Project | None {
    hits = [hub->:Hosts:->[?:Project, slug == want]];
    return hits[0] if hits else None;
}

def pad3(value: int) -> str {
    return str(value).rjust(3, "0");
}

def all_projects(hub: Platform) -> list[Project] {
    return [hub->:Hosts:->[?:Project]];
}

def slugify(name: str) -> str {
    out = "";
    for ch in name.lower() {
        if ch.isalnum() {
            out += ch;
        } elif ch in " -_." and out and not out.endswith("-") {
            out += "-";
        }
    }
    return out.strip("-") or "project";
}

# --- The cycle clock --------------------------------------------------
#
# Cycles are pure arithmetic off the platform epoch: cycle N spans
# [epoch + (N-1)*CYCLE_DAYS, epoch + N*CYCLE_DAYS), submissions close
# BUILD_DAYS in. Nodes are materialized lazily and past cycles are
# finalized by whichever request first arrives after their end — no
# scheduler, no gap, rollover can never be missed.

def current_cycle_number(hub: Platform) -> int {
    epoch = parse_iso(hub.epoch_iso);
    moment = datetime.datetime.now(datetime.UTC).replace(tzinfo=None);
    elapsed = (moment - epoch).total_seconds();
    return int(elapsed // (CYCLE_DAYS * 86400)) + 1;
}

def cycle_by_number(hub: Platform, want: int) -> Cycle | None {
    hits = [hub->:RunsCycle:->[?:Cycle, number == want]];
    return hits[0] if hits else None;
}

def materialize_cycle(hub: Platform, want: int) -> Cycle {
    found = cycle_by_number(hub, want);
    if found {
        return found;
    }
    epoch = parse_iso(hub.epoch_iso);
    opens = epoch + datetime.timedelta(days=CYCLE_DAYS * (want - 1));
    return (
        hub +>:RunsCycle():+> Cycle(
            number=want,
            opens_at=iso_of(opens),
            submissions_close_at=iso_of(opens + datetime.timedelta(days=BUILD_DAYS)),
            ends_at=iso_of(opens + datetime.timedelta(days=CYCLE_DAYS))
        )
    ) as Cycle;
}

def ensure_current_cycle(hub: Platform) -> Cycle {
    now_n = current_cycle_number(hub);
    current = materialize_cycle(hub, now_n);
    # Settle any unfinalized past cycle (usually just now_n - 1).
    for done in [hub->:RunsCycle:->[?:Cycle, number < now_n]] {
        if not done.finalized and done.phase() == "complete" {
            finalize_cycle(hub, done);
        }
    }
    return current;
}

def cycle_entries(cycle: Cycle) -> list[Entry] {
    return [cycle<-:InCycle:<-[?:Entry]];
}

def entry_project(ent: Entry) -> Project | None {
    hits = [ent<-:EnteredAs:<-[?:Checkpoint]<-:HasCheckpoint:<-[?:Project]];
    return hits[0] if hits else None;
}

def entry_checkpoint(ent: Entry) -> Checkpoint | None {
    hits = [ent<-:EnteredAs:<-[?:Checkpoint]];
    return hits[0] if hits else None;
}

"""Consecutive cycles (ending at upto_cycle) with an entry from this project."""
def project_streak(project: Project, upto_cycle: int) -> int {
    entered: dict[int, bool] = {};
    for point in [project->:HasCheckpoint:->[?:Checkpoint]] {
        for ent in [point->:EnteredAs:->[?:Entry]] {
            entered[ent.cycle_number] = True;
        }
    }
    run = 0;
    probe = upto_cycle;
    while probe >= 1 and probe in entered {
        run += 1;
        probe -= 1;
    }
    return run;
}

def bundle_entry(ent: Entry, me_handle: str = "") -> EntryBundle {
    return EntryBundle(
        entry=ent,
        project=entry_project(ent),
        checkpoint=entry_checkpoint(ent),
        awards=[ent->:Won:->[?:Award]],
        score_avg=ent.score_avg(),
        scored_by_me=bool(
            me_handle
            and [s for s in ent.scores if s.get("by", "") == me_handle]
        )
    );
}

def platform_post(
    hub: Platform,
    body: str,
    kind: str = "announce",
    project: Project | None = None,
    cycle_number: int = 0
) -> Post {
    fresh = (
        hub +>:Announced():+> Post(
            kind=kind,
            body=body,
            author_handle="jac.build",
            project_slug=project.slug if project else "",
            project_name=project.name if project else "",
            cycle_number=cycle_number,
            created_at=now_iso()
        )
    ) as Post;
    return fresh;
}

# --- Awards -----------------------------------------------------------

def give_award(
    hub: Platform,
    cycle: Cycle,
    winner: EntryBundle,
    category: str
) {
    handles = [b.handle for b in winner.project.members()] if winner.project else [];
    prize = (
        winner.entry +>:Won():+> Award(
            category=category,
            track=winner.entry.track,
            cycle_number=cycle.number,
            project_name=winner.project.name if winner.project else "",
            project_slug=winner.project.slug if winner.project else "",
            builder_handles=handles,
            awarded_at=now_iso()
        )
    ) as Award;
    cycle +>:Granted():+> prize;
    platform_post(
        hub,
        f"{prize.project_name} won {category} in Cycle {pad3(cycle.number)}.",
        kind="cycle",
        project=winner.project,
        cycle_number=cycle.number
    );
}

def top_by(pool: list[EntryBundle], keyer: any) -> EntryBundle | None {
    if not pool {
        return None;
    }
    best = pool[0];
    for candidate in pool {
        if keyer(candidate) > keyer(best) {
            best = candidate;
        }
    }
    return best;
}

"""Turn two weeks of entries into the permanent award record."""
def finalize_cycle(hub: Platform, cycle: Cycle) {
    cycle.finalized = True;
    entries = [bundle_entry(e) for e in cycle_entries(cycle)];
    fresh = [b for b in entries if b.entry.track == "fresh"];
    glowup = [b for b in entries if b.entry.track == "glowup"];

    by_score = lambda (b: EntryBundle) { b.score_avg + (0.001 * b.entry.commits_count); };
    by_depth = lambda (b: EntryBundle) { b.entry.depth_avg(); };

    if fresh {
        champion = top_by(fresh, by_score);
        if champion {
            give_award(hub, cycle, champion, "Best in Cycle");
        }
        deepest = top_by(fresh, by_depth);
        if deepest and deepest.entry.depth_avg() > 0 {
            give_award(hub, cycle, deepest, "Deepest Jac");
        }
        first_timers = [b for b in fresh if b.entry.is_first_build];
        debut = top_by(first_timers, by_score);
        if debut {
            give_award(hub, cycle, debut, "Best First Build");
        }
    }
    if glowup {
        champion = top_by(glowup, by_score);
        if champion {
            give_award(hub, cycle, champion, "Best Glow-Up");
        }
        cut = top_by(glowup, by_depth);
        if cut and cut.entry.depth_avg() > 0 {
            give_award(hub, cycle, cut, "Deepest Cut");
        }
        comebacks = [b for b in glowup if b.entry.is_comeback];
        returned = top_by(comebacks, by_score);
        if returned {
            give_award(hub, cycle, returned, "Best Comeback");
        }
        for b in glowup {
            if b.project and project_streak(b.project, cycle.number) == LONG_HAUL_STREAK {
                give_award(hub, cycle, b, "The Long Haul");
            }
        }
    }
    if entries {
        platform_post(
            hub,
            f"Cycle {pad3(cycle.number)} is a wrap — {len(entries)} entries, "
            f"{len(fresh)} fresh builds, {len(glowup)} glow-ups. "
            f"Cycle {pad3(cycle.number + 1)} is already open.",
            kind="cycle",
            cycle_number=cycle.number
        );
    }
}
