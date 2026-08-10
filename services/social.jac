"""jac.build — builders, follows, posts, and the home feed.

The builder profile is deliberately thin: an index into projects and
activity. Following is one mechanism with two targets (builders and
projects), and the feed is a traversal of the follow edges — strictly
reverse-chronological, no ranking.
"""

import from .model {
    Platform, Builder, Project, Post, Award, Popup,
    Registered, Follows, MemberOf, Authored, About, HostsPopup,
    HasCheckpoint, Checkpoint, EnteredAs, Entry, Won, Announced,
    BuilderBundle, ProjectRole,
    ensure_platform, my_builder, find_builder, find_project, now_iso
}

obj SetupResult {
    has ok: bool = False,
        error: str = "",
        me: BuilderBundle | None = None;
}

obj BuilderCard {
    has builder: Builder,
        project_count: int = 0,
        award_count: int = 0,
        follower_count: int = 0;
}

"""Everything won by this builder's projects, plus popup organizer badges."""
def builder_awards(hub: Platform, b: Builder) -> list[Award] {
    prizes: list[Award] = [];
    seen: dict[str, bool] = {};
    for p in [b->:MemberOf:->[?:Project]] {
        for a in [
            p->:HasCheckpoint:->[?:Checkpoint]->:EnteredAs:->[?:Entry]->:Won:->[?:Award]
        ] {
            if jid(a) not in seen {
                seen[jid(a)] = True;
                prizes.append(a);
            }
        }
    }
    for pu in [
        hub->:HostsPopup:->[?:Popup, host_handle == b.handle, status == "completed"]
    ] {
        for a in [pu->:Won:->[?:Award]] {
            if jid(a) not in seen {
                seen[jid(a)] = True;
                prizes.append(a);
            }
        }
    }
    prizes.sort(key=lambda (a: Award) { a.awarded_at; }, reverse=True);
    return prizes;
}

def bundle_builder(hub: Platform, b: Builder, viewer: Builder | None) -> BuilderBundle {
    roles: list[ProjectRole] = [];
    for p in [b->:MemberOf:->[?:Project]] {
        ties = [edge b->:MemberOf:->p];
        prize_count = len([
            p->:HasCheckpoint:->[?:Checkpoint]->:EnteredAs:->[?:Entry]->:Won:->[?:Award]
        ]);
        roles.append(
            ProjectRole(
                project=p,
                role=ties[0].role if ties else "member",
                checkpoint_count=len([p->:HasCheckpoint:->[?:Checkpoint]]),
                award_count=prize_count
            )
        );
    }
    posts = [b->:Authored:->[?:Post]];
    posts.sort(key=lambda (p: Post) { p.created_at; }, reverse=True);
    return BuilderBundle(
        builder=b,
        projects=roles,
        awards=builder_awards(hub, b),
        posts=posts[:50],
        followers=len([b<-:Follows:<-[?:Builder]]),
        following=len([b->:Follows:->]),
        is_following=bool(viewer and [edge viewer->:Follows:->b]),
        is_me=bool(viewer and jid(viewer) == jid(b))
    );
}

# --- Profile walkers --------------------------------------------------

walker setup_builder {
    has handle: str = "",
        display_name: str = "",
        bio: str = "",
        github: str = "",
        website: str = "",
        reports: list[SetupResult] = [];

    can run with Root entry {
        visit [-->[?:Builder]] else {
            hub = ensure_platform();
            wanted = self.handle.strip().lower();
            if not wanted {
                report SetupResult(error="Pick a handle.");
                disengage;
            }
            if find_builder(hub, wanted) {
                report SetupResult(error="That handle is taken.");
                disengage;
            }
            hue = 0;
            for ch in wanted {
                hue += ord(ch);
            }
            fresh = (
                here ++> Builder(
                    handle=wanted,
                    avatar_hue=(hue * 37) % 360,
                    joined_at=now_iso(),
                    is_core=not bool(hub.founder_handle)
                )
            ) as Builder;
            hub +>:Registered():+> fresh;
            if not hub.founder_handle {
                hub.founder_handle = wanted;
            }
            visit [fresh];
        }
    }

    can apply with Builder entry {
        if self.display_name {
            here.display_name = self.display_name;
        }
        if self.bio {
            here.bio = self.bio;
        }
        if self.github {
            here.github = self.github;
        }
        if self.website {
            here.website = self.website;
        }
        report SetupResult(
            ok=True, me=bundle_builder(ensure_platform(), here, here)
        );
    }
}

walker get_me {
    has reports: list[BuilderBundle] = [];

    can run with Root entry {
        visit [-->[?:Builder]];
    }

    can give with Builder entry {
        report bundle_builder(ensure_platform(), here, here);
    }
}

walker:pub get_builder {
    has handle: str = "",
        reports: list[BuilderBundle] = [];

    can run with Root entry {
        hub = ensure_platform();
        found = find_builder(hub, self.handle.strip().lower());
        if found {
            visit [found];
        }
    }

    can give with Builder entry {
        report bundle_builder(ensure_platform(), here, my_builder());
    }
}

walker:pub list_builders {
    has reports: list[list[BuilderCard]] = [];

    can run with Root entry {
        hub = ensure_platform();
        cards = [
            BuilderCard(
                builder=b,
                project_count=len([b->:MemberOf:->[?:Project]]),
                award_count=len(builder_awards(hub, b)),
                follower_count=len([b<-:Follows:<-[?:Builder]])
            )
            for b in [hub->:Registered:->[?:Builder]]
        ];
        cards.sort(key=lambda (c: BuilderCard) { c.builder.joined_at; }, reverse=True);
        report cards;
    }
}

# --- Following --------------------------------------------------------

walker toggle_follow {
    has target_id: str = "",
        reports: list[dict] = [];

    can run with Root entry {
        me = my_builder();
        if not me {
            report {"following": False};
            disengage;
        }
        target = jobj(self.target_id);
        if not (isinstance(target, Builder) or isinstance(target, Project)) {
            report {"following": False};
            disengage;
        }
        ties = [edge me->:Follows:->target];
        if ties {
            for tie in ties {
                del tie;
            }
            report {"following": False};
        } else {
            me +>:Follows():+> target;
            report {"following": True};
        }
    }
}

# --- Posts and the feed -----------------------------------------------

walker create_post {
    has body: str = "",
        project_slug: str = "",
        reports: list[Post] = [];

    can run with Root entry {
        visit [-->[?:Builder]];
    }

    can make with Builder entry {
        if not self.body.strip() {
            disengage;
        }
        hub = ensure_platform();
        target: Project | None = None;
        if self.project_slug {
            target = find_project(hub, self.project_slug);
        }
        fresh = (
            here +>:Authored():+> Post(
                kind="log" if target else "note",
                body=self.body.strip(),
                author_handle=here.handle,
                project_slug=target.slug if target else "",
                project_name=target.name if target else "",
                created_at=now_iso()
            )
        ) as Post;
        if target {
            fresh +>:About():+> target;
        }
        report fresh;
    }
}

walker load_feed {
    has feed: list[Post] = [],
        seen: dict[str, bool] = {},
        reports: list[list[Post]] = [];

    can run with Root entry {
        visit [-->[?:Builder]];
    }

    can gather with Builder entry {
        hub = ensure_platform();
        for p in [here->:Authored:->[?:Post]] {
            self.take(p);
        }
        for whom in [here->:Follows:->[?:Builder]] {
            for p in [whom->:Authored:->[?:Post]] {
                self.take(p);
            }
        }
        for proj in [here->:Follows:->[?:Project]] {
            for p in [proj<-:About:<-[?:Post]] {
                self.take(p);
            }
        }
        for p in [hub->:Announced:->[?:Post]] {
            self.take(p);
        }
        self.feed.sort(key=lambda (p: Post) { p.created_at; }, reverse=True);
        report self.feed[:100];
    }

    def take(p: Post) {
        if jid(p) not in self.seen {
            self.seen[jid(p)] = True;
            self.feed.append(p);
        }
    }
}
