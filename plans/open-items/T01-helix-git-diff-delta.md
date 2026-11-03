# T01: helix has no way to see the git diff of the file open in it

From `TODO.md`: "add git diff in helix, `delta` bindings?". Helix shows changed lines in its gutter but cannot show the diff itself, and neither `delta` nor any git pager is installed by `home.nix` or `aedit/module.nix`.

Proposed fix: add `delta` to `aedit/module.nix` packages, set it as git's pager (`programs.git.delta.enable`), and bind a key in `aedit/dotfiles/helix-config.toml` (say `space g d`) that opens `git diff -- %{buffer_name} | delta` in a zellij floating pane. The same key on a clean file shows nothing.

## Your call

<!-- sha256: 3129f4f7e6f06324625d3c2937b756da2fd853edf855effd0b512c35db8a7d46 -->
