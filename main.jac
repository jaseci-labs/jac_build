"""jac.build — the home for the Jac builders community.

Entry point: registers every server walker (the imports below are what
put them on the API) and hands the client router to the page tree in
pages/. The whole platform — frontend, backend, and the graph between —
is one Jac program.
"""

import from services.social {
    setup_builder, get_me, get_builder, list_builders, toggle_follow,
    create_post, load_feed
}
import from services.projects {
    create_project, get_project, update_project, add_member, my_projects,
    cut_checkpoint, discover, landing_stats
}
import from services.cycles {
    cycle_status, get_cycle, list_cycles, score_entry, set_challenge, standings
}
import from services.popups {
    apply_popup, list_popups, get_popup, review_popup, complete_popup
}

import ".styles.global.css";
import ".styles.site.css";

def:pub app(children: any) -> JsxElement {
    return <>{children}</>;
}
