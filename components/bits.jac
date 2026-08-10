"""jac.build — small shared client pieces: avatars, chips, formatting."""

import from "@jac/runtime" { Link }

def:pub time_ago(stamp: str) -> str {
    if not stamp {
        return "";
    }
    then = new(Date, stamp).getTime();  # jac:ignore[E1053]
    delta = (new(Date).getTime() - then) / 1000.0;  # jac:ignore[E1053]
    if delta < 60.0 {
        return "just now";
    }
    if delta < 3600.0 {
        return str(int(delta / 60.0)) + "m ago";
    }
    if delta < 86400.0 {
        return str(int(delta / 3600.0)) + "h ago";
    }
    if delta < 2592000.0 {
        return str(int(delta / 86400.0)) + "d ago";
    }
    return stamp.split("T")[0];
}

def:pub pad_cycle(n: int) -> str {
    raw = str(n);
    if len(raw) >= 3 {
        return raw;
    }
    return ("000" + raw)[-3:];
}

def:pub short_sha(sha: str) -> str {
    return sha[:7] if len(sha) > 7 else sha;
}

def:pub Avatar(handle: str, hue: int, size: str = "size-9") -> JsxElement {
    letter = handle[0].upper() if handle else "?";
    return
        <span
            className={
                size
                + " inline-flex shrink-0 select-none items-center justify-center rounded-full font-semibold text-white"
            }
            style={{
                "background": f"linear-gradient(135deg, hsl({hue} 70% 45%), hsl({(hue + 40) % 360} 80% 35%))"
            }}
        >
            {letter}
        </span>;
}

def:pub TrackChip(track: str, subtle: bool = False) -> JsxElement {
    if track == "fresh" {
        return
            <span
                className="chip-fresh rounded-full px-2 py-0.5 text-[11px] font-semibold uppercase tracking-wide"
            >
                Fresh Build
            </span>;
    }
    return
        <span
            className="chip-glowup rounded-full px-2 py-0.5 text-[11px] font-semibold uppercase tracking-wide"
        >
            Glow-Up
        </span>;
}

def:pub AwardChip(category: str, cycle_number: int = 0) -> JsxElement {
    return
        <span
            className="award-chip inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[11px] font-medium"
            title={
                ("Cycle " + pad_cycle(cycle_number)) if cycle_number > 0 else "Badge"
            }
        >
            <span aria-hidden="true">🏆</span>
            {category}
            {if cycle_number > 0 {
                <span className="text-muted-foreground">
                    {"· C" + pad_cycle(cycle_number)}
                </span>
            }}
        </span>;
}

def:pub PhaseChip(phase: str) -> JsxElement {
    label = (
        "Build window open"
        if phase == "building"
        else ("Judging" if phase == "judging" else "Complete")
    );
    tone = (
        "bg-emerald-500/15 text-emerald-600 dark:text-emerald-400"
        if phase == "building"
        else (
            "bg-amber-500/15 text-amber-600 dark:text-amber-400"
            if phase == "judging"
            else "bg-muted text-muted-foreground"
        )
    );
    return
        <span
            className={
                tone + " rounded-full px-2 py-0.5 text-[11px] font-semibold uppercase tracking-wide"
            }
        >
            {label}
        </span>;
}

def:pub BuilderLink(handle: str, className: str = "") -> JsxElement {
    return
        <Link
            to={"/b/" + handle}
            className={className or "font-medium text-foreground hover:text-primary"}
        >
            {"@" + handle}
        </Link>;
}

def:pub EmptyState(title: str, hint: str = "") -> JsxElement {
    return
        <div
            className="rounded-xl border border-dashed border-border px-6 py-10 text-center"
        >
            <p className="font-medium text-muted-foreground">{title}</p>
            {if hint {
                <p className="mt-1 text-sm text-muted-foreground/70">{hint}</p>
            }}
        </div>;
}

def:pub countdown_label(seconds_left: int, phase: str) -> str {
    d = seconds_left // 86400;
    h = (seconds_left % 86400) // 3600;
    tail = "to enter" if phase == "building" else "of judging left";
    if d > 0 {
        return f"{d}d {h}h {tail}";
    }
    m = (seconds_left % 3600) // 60;
    return f"{h}h {m}m {tail}";
}
