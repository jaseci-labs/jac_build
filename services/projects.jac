"""jac.build — project profiles, checkpoints, and the two-track entry flow.

The project is the platform's unit of record: a persistent node with
followers and a timeline, created once, alive forever. A checkpoint is
an immutable snapshot record, and cutting one *is* the submittable —
entering a cycle attaches an Entry to the checkpoint, with the track
(Fresh Build vs Glow-Up) determined by the project's checkpoint
history, never chosen by the entrant.
"""

import json;
import urllib.request;
import from jaclang.byllm.lib { Model }

import from .model {
    Platform, Builder, Project, Checkpoint, Entry, Award, Post,
    Registered, Hosts, MemberOf, Follows, HasCheckpoint, EnteredAs, InCycle,
    Won, Authored, About,
    ProjectBundle, EntryBundle, TeamMember, ProjectRole,
    ensure_platform, ensure_current_cycle, current_cycle_number, my_builder,
    find_builder, find_project, all_projects, slugify, now_iso, parse_iso, pad3,
    bundle_entry, project_streak,
    FRESH_CATEGORIES, GLOWUP_CATEGORIES, CYCLE_DAYS, COMEBACK_GAP_CYCLES
}

glob llm: Model = Model(model_name="gpt-4o-mini");

"""Neutral summary of what actually changed between two checkpoints of a
project, written from the commit log and diff stats — shown to judges
beside the team's own claims."""
def digest_diff(
    project_name: str, write_up: str, commit_log: list[str], stats_line: str
) -> str by llm(temperature=0.2, max_tokens=220);
sem digest_diff = "Summarize, in 2-3 plain sentences, what actually changed in the code based on the commit log and diff stats. Be concrete and neutral; do not repeat the team's claims.";
sem digest_diff.project_name = "The project's name.";
sem digest_diff.write_up = "The team's own improvement write-up (their claims).";
sem digest_diff.commit_log = "First lines of the commits in the range, oldest first.";
sem digest_diff.stats_line = "Diff stats: commits, files changed, additions, deletions.";

obj CheckpointResult {
    has ok: bool = False,
        error: str = "",
        checkpoint: Checkpoint | None = None,
        entry: Entry | None = None,
        track: str = "",
        cycle_number: int = 0,
        project_slug: str = "";
}

obj ProjectCard {
    has project: Project,
        followers: int = 0,
        checkpoint_count: int = 0,
        award_count: int = 0,
        last_checkpoint_at: str = "";
}

obj DiscoverBundle {
    has cycle_entries: list[EntryBundle] = [],
        first_builds: list[EntryBundle] = [],
        recent_checkpoints: list[EntryBundle] = [],
        projects: list[ProjectCard] = [],
        cycle_number: int = 0,
        phase: str = "";
}

obj LandingStats {
    has builders: int = 0,
        projects: int = 0,
        checkpoints: int = 0,
        awards: int = 0,
        cycle_number: int = 0,
        phase: str = "";
}

def my_role_in(me: Builder | None, p: Project) -> str {
    if not me {
        return "";
    }
    ties = [edge me->:MemberOf:->p];
    return ties[0].role if ties else "";
}

def bundle_project(hub: Platform, p: Project, viewer: Builder | None) -> ProjectBundle {
    team: list[TeamMember] = [];
    for b in [p<-:MemberOf:<-[?:Builder]] {
        ties = [edge b->:MemberOf:->p];
        team.append(
            TeamMember(
                builder=b,
                role=ties[0].role if ties else "member",
                since=ties[0].since if ties else ""
            )
        );
    }
    points = p.checkpoints_sorted();
    entries: list[EntryBundle] = [];
    for point in points {
        for ent in [point->:EnteredAs:->[?:Entry]] {
            entries.append(bundle_entry(ent, viewer.handle if viewer else ""));
        }
    }
    entries.sort(key=lambda (e: EntryBundle) { e.entry.submitted_at; }, reverse=True);
    prizes: list[Award] = [];
    for e in entries {
        for a in e.awards {
            prizes.append(a);
        }
    }
    posts = [p<-:About:<-[?:Post]];
    posts.sort(key=lambda (x: Post) { x.created_at; }, reverse=True);
    return ProjectBundle(
        project=p,
        team=team,
        checkpoints=points,
        entries=entries,
        awards=prizes,
        posts=posts[:30],
        followers=len([p<-:Follows:<-[?:Builder]]),
        is_following=bool(viewer and [edge viewer->:Follows:->p]),
        my_role=my_role_in(viewer, p),
        streak=project_streak(p, current_cycle_number(hub))
    );
}

# --- GitHub compare enrichment (best-effort, never blocks a submission) ---

def github_repo_path(repo_url: str) -> str {
    trimmed = repo_url.strip().rstrip("/");
    if "github.com/" not in trimmed {
        return "";
    }
    tail = trimmed.split("github.com/")[-1];
    parts = tail.split("/");
    if len(parts) < 2 {
        return "";
    }
    return parts[0] + "/" + parts[1].removesuffix(".git");
}

def fetch_compare(repo_path: str, base: str, head: str) -> dict {
    api = f"https://api.github.com/repos/{repo_path}/compare/{base}...{head}";
    try {
        req = urllib.request.Request(
            api, headers={"User-Agent": "jac-build", "Accept": "application/vnd.github+json"}
        );
        resp = urllib.request.urlopen(req, timeout=6);
        payload = json.loads(resp.read().decode("utf-8"));
        resp.close();
        commits = payload.get("commits", []);
        files = payload.get("files", []);
        additions = 0;
        deletions = 0;
        for f in files {
            additions += int(f.get("additions", 0));
            deletions += int(f.get("deletions", 0));
        }
        messages = [
            str(c.get("commit", {}).get("message", "")).split("\n")[0]
            for c in commits
        ];
        return {
            "ok": True,
            "commits": len(commits),
            "files": len(files),
            "additions": additions,
            "deletions": deletions,
            "log": messages[:20]
        };
    } except Exception {
        return {"ok": False};
    }
}

def enrich_glowup(ent: Entry, p: Project, write_up: str) {
    repo_path = github_repo_path(p.repo_url);
    if repo_path {
        ent.compare_url = (
            f"https://github.com/{repo_path}/compare/{ent.base_sha}...{ent.head_sha}"
        );
        found = fetch_compare(repo_path, ent.base_sha, ent.head_sha);
        if found.get("ok") {
            ent.commits_count = found["commits"];
            ent.files_changed = found["files"];
            ent.additions = found["additions"];
            ent.deletions = found["deletions"];
            ent.commit_log = found["log"];
        }
    }
    stats_line = (
        f"{ent.commits_count} commits, {ent.files_changed} files, "
        f"+{ent.additions} / -{ent.deletions}"
    );
    try {
        ent.diff_digest = digest_diff(p.name, write_up, ent.commit_log, stats_line);
        ent.digest_source = "llm";
    } except Exception {
        # No model configured (or call failed): fall back to the raw
        # commit log — Phase 1 diffs can be raw commit logs by design.
        if ent.commit_log {
            ent.diff_digest = stats_line + ". " + "; ".join(ent.commit_log[:5]);
            ent.digest_source = "commits";
        } else {
            ent.diff_digest = "";
            ent.digest_source = "none";
        }
    }
}

# --- Project walkers --------------------------------------------------

walker create_project {
    has name: str = "",
        one_liner: str = "",
        description: str = "",
        tags: list[str] = [],
        repo_url: str = "",
        reports: list[ProjectBundle] = [];

    can run with Root entry {
        visit [-->[?:Builder]];
    }

    can make with Builder entry {
        if not self.name.strip() {
            disengage;
        }
        hub = ensure_platform();
        stem = slugify(self.name);
        candidate = stem;
        bump = 2;
        while find_project(hub, candidate) {
            candidate = stem + "-" + str(bump);
            bump += 1;
        }
        fresh = (
            hub +>:Hosts():+> Project(
                name=self.name.strip(),
                slug=candidate,
                one_liner=self.one_liner.strip(),
                description=self.description.strip(),
                tags=[t.strip().lower() for t in self.tags if t.strip()],
                repo_url=self.repo_url.strip(),
                created_at=now_iso()
            )
        ) as Project;
        here +>:MemberOf(role="owner", since=now_iso()):+> fresh;
        here +>:Follows():+> fresh;
        report bundle_project(hub, fresh, here);
    }
}

walker:pub get_project {
    has slug: str = "",
        reports: list[ProjectBundle] = [];

    can run with Root entry {
        hub = ensure_platform();
        found = find_project(hub, self.slug);
        if found {
            report bundle_project(hub, found, my_builder());
        }
    }
}

walker update_project {
    has slug: str = "",
        one_liner: str = "",
        description: str = "",
        tags: list[str] = [],
        repo_url: str = "",
        status: str = "",
        reports: list[ProjectBundle] = [];

    can run with Root entry {
        me = my_builder();
        hub = ensure_platform();
        found = find_project(hub, self.slug);
        if not (me and found and my_role_in(me, found)) {
            disengage;
        }
        if self.one_liner {
            found.one_liner = self.one_liner.strip();
        }
        if self.description {
            found.description = self.description.strip();
        }
        if self.tags {
            found.tags = [t.strip().lower() for t in self.tags if t.strip()];
        }
        if self.repo_url {
            found.repo_url = self.repo_url.strip();
        }
        if self.status in ["active", "dormant", "archived"] {
            found.status = self.status;
        }
        report bundle_project(hub, found, me);
    }
}

walker add_member {
    has slug: str = "",
        handle: str = "",
        role: str = "maintainer",
        reports: list[ProjectBundle] = [];

    can run with Root entry {
        me = my_builder();
        hub = ensure_platform();
        found = find_project(hub, self.slug);
        mate = find_builder(hub, self.handle.strip().lower());
        if not (me and found and mate) {
            disengage;
        }
        if my_role_in(me, found) not in ["owner", "maintainer"] {
            disengage;
        }
        if not [edge mate->:MemberOf:->found] {
            picked = self.role if self.role in ["maintainer", "contributor"] else "maintainer";
            mate +>:MemberOf(role=picked, since=now_iso()):+> found;
            # Joining a team follows the project (severable, per the doc).
            if not [edge mate->:Follows:->found] {
                mate +>:Follows():+> found;
            }
        }
        report bundle_project(hub, found, me);
    }
}

walker my_projects {
    has reports: list[list[ProjectRole]] = [];

    can run with Root entry {
        visit [-->[?:Builder]];
    }

    can give with Builder entry {
        roles: list[ProjectRole] = [];
        for p in [here->:MemberOf:->[?:Project]] {
            ties = [edge here->:MemberOf:->p];
            roles.append(
                ProjectRole(
                    project=p,
                    role=ties[0].role if ties else "member",
                    checkpoint_count=len([p->:HasCheckpoint:->[?:Checkpoint]])
                )
            );
        }
        roles.sort(key=lambda (r: ProjectRole) { r.project.created_at; }, reverse=True);
        report roles;
    }
}

# --- The entry flow: cutting a checkpoint -----------------------------

walker cut_checkpoint {
    has slug: str = "",
        sha: str = "",
        write_up: str = "",
        demo_url: str = "",
        deployed_url: str = "",
        enter_cycle: bool = True,
        categories: list[str] = [],
        reports: list[CheckpointResult] = [];

    can run with Root entry {
        visit [-->[?:Builder]] else {
            report CheckpointResult(error="Set up your builder profile first.");
        }
    }

    can cut with Builder entry {
        hub = ensure_platform();
        found = find_project(hub, self.slug);
        if not found {
            report CheckpointResult(error="No such project.");
            disengage;
        }
        if not my_role_in(here, found) {
            report CheckpointResult(error="Only team members can cut a checkpoint.");
            disengage;
        }
        if not self.sha.strip() or not self.write_up.strip() {
            report CheckpointResult(error="A checkpoint needs a commit SHA and a write-up.");
            disengage;
        }
        prior = found.checkpoints_sorted();
        point = (
            found +>:HasCheckpoint():+> Checkpoint(
                number=len(prior) + 1,
                sha=self.sha.strip(),
                write_up=self.write_up.strip(),
                demo_url=self.demo_url.strip(),
                deployed_url=self.deployed_url.strip(),
                created_at=now_iso()
            )
        ) as Checkpoint;
        found.status = "active";

        # Every checkpoint ships a post to the project's followers.
        ship = (
            here +>:Authored():+> Post(
                kind="ship",
                body=f"Checkpoint v{point.number} of {found.name}: " + self.write_up.strip(),
                author_handle=here.handle,
                project_slug=found.slug,
                project_name=found.name,
                created_at=now_iso()
            )
        ) as Post;
        ship +>:About():+> found;

        if not self.enter_cycle {
            report CheckpointResult(
                ok=True, checkpoint=point, project_slug=found.slug
            );
            disengage;
        }

        cycle = ensure_current_cycle(hub);
        if cycle.phase() != "building" {
            report CheckpointResult(
                ok=True,
                checkpoint=point,
                project_slug=found.slug,
                error="Submissions are closed while judging runs — checkpoint saved, cycle not entered."
            );
            disengage;
        }
        current_n = cycle.number;
        already: list[Entry] = [];
        for old in prior {
            for e in [old->:EnteredAs:->[?:Entry, cycle_number == current_n]] {
                already.append(e);
            }
        }
        if already {
            report CheckpointResult(
                ok=True,
                checkpoint=point,
                project_slug=found.slug,
                error="This project already entered the current cycle — checkpoint saved."
            );
            disengage;
        }

        # The track is the project's history, not a choice.
        track = "fresh" if point.number == 1 else "glowup";
        allowed = FRESH_CATEGORIES if track == "fresh" else GLOWUP_CATEGORIES;
        picked = [c for c in self.categories if c in allowed];

        my_points = 0;
        for mine in [here->:MemberOf:->[?:Project]] {
            my_points += len([mine->:HasCheckpoint:->[?:Checkpoint]]);
        }

        ent = (
            point +>:EnteredAs():+> Entry(
                track=track,
                categories=picked,
                cycle_number=cycle.number,
                submitted_at=now_iso(),
                head_sha=point.sha,
                is_first_build=(track == "fresh" and my_points == 1)
            )
        ) as Entry;
        ent +>:InCycle():+> cycle;

        if track == "glowup" {
            base = prior[-1];
            ent.base_sha = base.sha;
            gap = (
                parse_iso(point.created_at) - parse_iso(base.created_at)
            ).total_seconds();
            ent.is_comeback = gap >= COMEBACK_GAP_CYCLES * CYCLE_DAYS * 86400;
            enrich_glowup(ent, found, self.write_up);
        }

        label = "a Fresh Build" if track == "fresh" else "a Glow-Up";
        entered = (
            here +>:Authored():+> Post(
                kind="cycle",
                body=f"{found.name} entered Cycle {pad3(cycle.number)} as {label}.",
                author_handle=here.handle,
                project_slug=found.slug,
                project_name=found.name,
                cycle_number=cycle.number,
                created_at=now_iso()
            )
        ) as Post;
        entered +>:About():+> found;

        report CheckpointResult(
            ok=True,
            checkpoint=point,
            entry=ent,
            track=track,
            cycle_number=cycle.number,
            project_slug=found.slug
        );
    }
}

# --- Discover ---------------------------------------------------------

walker:pub discover {
    has reports: list[DiscoverBundle] = [];

    can run with Root entry {
        hub = ensure_platform();
        cycle = ensure_current_cycle(hub);
        entries = [
            bundle_entry(e)
            for e in [cycle<-:InCycle:<-[?:Entry]]
        ];
        entries.sort(key=lambda (e: EntryBundle) { e.entry.submitted_at; }, reverse=True);

        cards: list[ProjectCard] = [];
        latest: list[EntryBundle] = [];
        for p in all_projects(hub) {
            points = p.checkpoints_sorted();
            prize_count = 0;
            for point in points {
                for e in [point->:EnteredAs:->[?:Entry]] {
                    prize_count += len([e->:Won:->[?:Award]]);
                }
            }
            cards.append(
                ProjectCard(
                    project=p,
                    followers=len([p<-:Follows:<-[?:Builder]]),
                    checkpoint_count=len(points),
                    award_count=prize_count,
                    last_checkpoint_at=points[-1].created_at if points else p.created_at
                )
            );
        }
        cards.sort(key=lambda (c: ProjectCard) { c.last_checkpoint_at; }, reverse=True);

        report DiscoverBundle(
            cycle_entries=entries,
            first_builds=[e for e in entries if e.entry.is_first_build],
            projects=cards,
            cycle_number=cycle.number,
            phase=cycle.phase()
        );
    }
}

walker:pub landing_stats {
    has reports: list[LandingStats] = [];

    can run with Root entry {
        hub = ensure_platform();
        cycle = ensure_current_cycle(hub);
        projects = all_projects(hub);
        point_count = 0;
        prize_count = 0;
        for p in projects {
            points = [p->:HasCheckpoint:->[?:Checkpoint]];
            point_count += len(points);
            for point in points {
                for e in [point->:EnteredAs:->[?:Entry]] {
                    prize_count += len([e->:Won:->[?:Award]]);
                }
            }
        }
        report LandingStats(
            builders=len([hub->:Registered:->[?:Builder]]),
            projects=len(projects),
            checkpoints=point_count,
            awards=prize_count,
            cycle_number=cycle.number,
            phase=cycle.phase()
        );
    }
}
