-- resume rules beyond rex's built-in claude, codex and opencode ones. pi reports
-- from ~/.ai/pi/extensions, nvim from nvim/lua/features/rex-resume.lua, jiru
-- from its own internal/resume package

rex.set("resume.trust.pi", {
    command = { "pi", "--session-id", rex.match.uuid },
})

rex.set("resume.trust.jiru", {
    command = { "jiru" },
    flags = {
        ["--profile"] = { "keep", values = 1 },
        ["-p"] = { "keep", values = 1 },
    },
})

rex.set("resume.trust.nvim", {
    command = { "nvim", "-S", rex.match.under("~/.local/state/nvim/rex-sessions") },
})
