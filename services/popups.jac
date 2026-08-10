"""jac.build — JacHacks Popups: community-run events, platform-backed.

Anyone can apply to run one (five people in a dorm lounge is
legitimate); funding tiers scale with size, review is light, and a
completed popup earns the organizer a permanent badge and an archive
page. Judging routes through the same cycle machinery — a popup
project checkpoints like any other and can enter the next Forever
cycle as a Glow-Up.
"""

import from .model {
    Platform, Builder, Popup, Award, Post,
    HostsPopup, Won,
    ensure_platform, my_builder, now_iso, platform_post
}

def tier_for(headcount: int) -> str {
    if headcount <= 15 {
        return "starter";        # food money, near-automatic
    }
    if headcount <= 40 {
        return "club";           # food + venue/printing
    }
    return "big";                # gets a real review
}

walker apply_popup {
    has title: str = "",
        city: str = "",
        date_iso: str = "",
        headcount: int = 5,
        format: str = "4h",
        needs: str = "",
        reports: list[Popup] = [];

    can run with Root entry {
        me = my_builder();
        if not me {
            disengage;
        }
        if not self.title.strip() or not self.city.strip() {
            disengage;
        }
        hub = ensure_platform();
        fresh = (
            hub +>:HostsPopup():+> Popup(
                title=self.title.strip(),
                city=self.city.strip(),
                host_handle=me.handle,
                date_iso=self.date_iso,
                headcount=max(self.headcount, 5),
                format=self.format if self.format in ["4h", "12h", "24h"] else "4h",
                needs=self.needs.strip(),
                tier=tier_for(self.headcount),
                created_at=now_iso()
            )
        ) as Popup;
        report fresh;
    }
}

walker:pub list_popups {
    has reports: list[list[Popup]] = [];

    can run with Root entry {
        hub = ensure_platform();
        pops = [hub->:HostsPopup:->[?:Popup]];
        pops.sort(key=lambda (p: Popup) { p.created_at; }, reverse=True);
        report pops;
    }
}

walker:pub get_popup {
    has popup_id: str = "",
        reports: list[Popup] = [];

    can run with Root entry {
        target = jobj(self.popup_id);
        if isinstance(target, Popup) {
            report target;
        }
    }
}

walker review_popup {
    has popup_id: str = "",
        decision: str = "approved",
        note: str = "",
        reports: list[Popup] = [];

    can run with Root entry {
        me = my_builder();
        if not (me and me.is_core) {
            disengage;
        }
        target = jobj(self.popup_id);
        if not isinstance(target, Popup) or target.status != "applied" {
            disengage;
        }
        target.status = "approved" if self.decision == "approved" else "declined";
        target.decided_note = self.note.strip();
        if target.status == "approved" {
            platform_post(
                ensure_platform(),
                f"JacHacks Popup: {target.city} is on — {target.title}, "
                f"hosted by @{target.host_handle}. {target.headcount} builders expected."
            );
        }
        report target;
    }
}

walker complete_popup {
    has popup_id: str = "",
        recap: str = "",
        headcount: int = 0,
        reports: list[Popup] = [];

    can run with Root entry {
        me = my_builder();
        target = jobj(self.popup_id);
        if not (me and isinstance(target, Popup)) {
            disengage;
        }
        if target.host_handle != me.handle or target.status != "approved" {
            disengage;
        }
        target.status = "completed";
        target.recap = self.recap.strip();
        target.recap_headcount = self.headcount or target.headcount;
        target +>:Won():+> Award(
            category="Organizer",
            track="popup",
            project_name=target.title,
            builder_handles=[me.handle],
            awarded_at=now_iso()
        );
        platform_post(
            ensure_platform(),
            f"Popup wrap: {target.title} in {target.city} brought out "
            f"{target.recap_headcount} builders. Archive is live."
        );
        report target;
    }
}
