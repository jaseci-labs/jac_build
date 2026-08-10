# jac.build

**The home for the Jac builders community** — where the energy of JacHacks
doesn't end when the hackathon does.

jac.build is two things at once, deliberately fused:

1. **A continuous hackathon engine.** *JacHacks Forever* runs always-on,
   low-stakes cycles in rolling two-week windows — numbered continuously,
   archived forever, zero gaps. *JacHacks Popups* let anyone run their own
   funded, in-person mini-hackathon, with judging routed through the platform.
2. **An intimate social network of Jac builders.** Builders have profiles.
   **Projects have profiles too** — living, first-class citizens with
   timelines, followers, and permanent identity. The same project enters
   cycles again and again; a returning project is judged on the **diff**, not
   in absolute terms.

The loop the whole platform serves: **build in public → accrete a history →
re-enter → be judged on growth → repeat.**

## The two tracks

Every cycle accepts entries on two tracks, decided by the project's checkpoint
history — never chosen by the entrant:

- **Fresh Build** — the project's first-ever checkpoint. Judged in absolute
  terms: Best in Cycle, Deepest Jac, Best First Build, Most Useful, Wildcard.
- **Glow-Up** — the project has history. What's judged is the diff between the
  last checkpoint and this one — pinned SHAs, commit stats pulled from the
  repo, a capped improvement write-up, and a neutral diff digest shown beside
  the team's claims. Categories: Best Glow-Up, Deepest Cut, The Long Haul,
  Best Comeback.

Fresh Build is the on-ramp; Glow-Up is the treadmill.

## Written in Jac — on purpose

This platform is the flagship reference application for
[Jac](https://jaclang.org): one language, one program, the whole stack.

- **The graph is the database.** `Builder`, `Project`, `Checkpoint`, `Entry`,
  `Award`, `Post`, `Cycle`, and `Popup` are nodes; membership, follows,
  submissions, and wins are edges. Every feature is a traversal.
- **Walkers are the API.** The feed is a walk over follow edges; standings are
  a walk over award edges; entering a cycle attaches an `Entry` to the
  `Checkpoint` you just cut.
- **Access is declared on the archetypes.** `Project.__jac_access__` reads the
  `MemberOf` edge at access-check time — team membership *is* write
  permission.
- **The cycle clock is arithmetic, not a scheduler.** Cycles materialize
  lazily off the platform epoch; whichever request first arrives after a
  cycle's end finalizes its awards. A rollover can never be missed.
- **`by llm()` where it earns its keep.** The Glow-Up diff digest is
  model-generated when a model is configured and falls back to the raw commit
  log when not.

## Running it

```bash
jac install       # dependencies (once)
jac start         # serve at http://localhost:8000
```

Layout:

```
main.jac            # entry: server walker registry + client app shell
services/
  model.jac         # the graph: nodes, edges, bundles, cycle clock, awards
  social.jac        # builders, follows, posts, the home feed
  projects.jac      # project profiles, checkpoints, two-track entry, discover
  cycles.jac        # cycle pages, community scoring, standings, ops
  popups.jac        # popup application / review / wrap
pages/              # file-based routes (feed, project, builder, cycle, …)
components/         # shadcn primitives + platform components
```

## Status

Phase 1 MVP: builder and project profiles, checkpoints, the two-track entry
flow, the cycle engine (register → checkpoint → judge → award), following,
ship posts, the chronological home feed, the popup flow, and the permanent
archive. Deferred by design: comments, reactions, boosts, DMs, media vault,
roadmap room, club and company surfaces.
