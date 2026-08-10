"""jac.build — join / sign in. Signup provisions the builder profile."""

import from "@jac/runtime" { useNavigate, jacSignup, jacLogin }
import from "lucide-react" { AlertCircle, Hammer }
import from ..components.ui.card {
    Card, CardHeader, CardTitle, CardDescription, CardContent
}
import from ..components.ui.input { Input }
import from ..components.ui.label { Label }
import from ..components.ui.button { Button }
import from ..services.social { setup_builder, get_me }

def:pub page -> JsxPage {
    has isSignup: bool = True,
        handle: str = "",
        displayName: str = "",
        password: str = "",
        error: str = "",
        loading: bool = False;

    nav = useNavigate();

    def remember(gotHandle: str, gotHue: int) -> None {
        localStorage.setItem("jb_handle", gotHandle);
        localStorage.setItem("jb_hue", str(gotHue));
        # Full reload so the navbar picks up the session everywhere.
        window.location.href = "/";
    }

    async def submit -> None {
        error = "";
        cleaned = handle.strip().lower();
        if not cleaned or not password {
            error = "Handle and password, both.";
            return;
        }
        loading = True;
        if isSignup {
            made: dict[str, any] = await jacSignup(cleaned, password);
            if not made["success"] {
                loading = False;
                error = str(made["error"] or "Signup failed.");
                return;
            }
        }
        okay: bool = await jacLogin(cleaned, password);
        if not okay {
            loading = False;
            error = "Invalid handle or password.";
            return;
        }
        if isSignup {
            w = root spawn setup_builder(
                handle=cleaned, display_name=displayName.strip()
            );
            made_me = w.reports[0] if w.reports else None;
            loading = False;
            if made_me and made_me.ok and made_me.me {
                remember(made_me.me.builder.handle, made_me.me.builder.avatar_hue);
            } elif made_me and made_me.error {
                error = made_me.error;
            } else {
                error = "Could not set up your profile.";
            }
        } else {
            m = root spawn get_me();
            mine = m.reports[0] if m.reports else None;
            loading = False;
            if mine {
                remember(mine.builder.handle, mine.builder.avatar_hue);
            } else {
                remember(cleaned, 21);
            }
        }
    }

    return
        <div
            className="mx-auto flex w-full max-w-6xl flex-col items-center gap-10 px-4 py-16 lg:flex-row lg:items-stretch lg:gap-16"
        >
            <div
                className="flex max-w-xl flex-1 flex-col justify-center gap-4 text-center lg:text-left"
            >
                <div
                    className="mx-auto flex size-14 items-center justify-center rounded-2xl bg-primary/15 text-primary lg:mx-0"
                >
                    <Hammer size={26}/>
                </div>
                <h1 className="text-4xl font-extrabold tracking-tight">
                    {"Where Jac projects "}
                    <span className="text-primary">live</span>
                    {"."}
                </h1>
                <p className="text-balance text-muted-foreground">
                    A cycle every two weeks, forever. Cut a checkpoint, enter the
                    cycle, and come back next cycle to be judged on how far your
                    project moved — not just where it stands.
                </p>
            </div>
            <Card className="w-full max-w-sm self-center border-border/60 shadow-xl">
                <CardHeader>
                    <CardTitle className="text-2xl font-extrabold">
                        {"Claim your handle" if isSignup else "Welcome back"}
                    </CardTitle>
                    <CardDescription>
                        {"One account, one graph node."
                            if isSignup
                            else "Sign in to jac.build."}
                    </CardDescription>
                </CardHeader>
                <CardContent>
                    {if error {
                        <div
                            className="mb-4 flex items-center gap-2 rounded-lg border border-destructive/30 bg-destructive/10 px-3 py-2 text-sm text-destructive"
                        >
                            <AlertCircle size={16}/>
                            <span>{error}</span>
                        </div>
                    }}
                    <form
                        className="flex flex-col gap-4"
                        onSubmit={lambda (e: FormEvent) {
                            e.preventDefault();
                            _ = submit();
                        }}
                    >
                        <div className="flex flex-col gap-1.5">
                            <Label htmlFor="jb-handle">Handle</Label>
                            <Input
                                id="jb-handle"
                                type="text"
                                placeholder="ada"
                                value={handle}
                                onChange={lambda (e: ChangeEvent) {
                                    handle = e.target.value;
                                }}
                            />
                        </div>
                        {if isSignup {
                            <div className="flex flex-col gap-1.5">
                                <Label htmlFor="jb-name">Display name</Label>
                                <Input
                                    id="jb-name"
                                    type="text"
                                    placeholder="Ada Lovelace"
                                    value={displayName}
                                    onChange={lambda (e: ChangeEvent) {
                                        displayName = e.target.value;
                                    }}
                                />
                            </div>
                        }}
                        <div className="flex flex-col gap-1.5">
                            <Label htmlFor="jb-pass">Password</Label>
                            <Input
                                id="jb-pass"
                                type="password"
                                placeholder="••••••••"
                                value={password}
                                onChange={lambda (e: ChangeEvent) {
                                    password = e.target.value;
                                }}
                            />
                        </div>
                        <Button type="submit" disabled={loading} className="mt-1">
                            {"Working…"
                                if loading
                                else ("Join jac.build" if isSignup else "Sign in")}
                        </Button>
                    </form>
                    <button
                        type="button"
                        className="mt-4 w-full text-center text-sm text-muted-foreground hover:text-foreground"
                        onClick={lambda {
                            isSignup = not isSignup;
                            error = "";
                        }}
                    >
                        {"Already have an account? Sign in"
                            if isSignup
                            else "New here? Claim a handle"}
                    </button>
                </CardContent>
            </Card>
        </div>;
}
