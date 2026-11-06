---
name: home-setup
description: "Set up this machine's two clones of arpadav/home: the install copy at ~/.config/aav/home that everything runs from, and the edit copy he edits. Load this when he says '/home-setup', 'set up home', 'set up the edit copy', or when a brain command or sy says 'run /home-setup' (no edit copy, or a symlinked install copy). It fixes whichever of the four cases holds, then runs sy."
---

# home-setup: the install copy and the edit copy

| clone | where | job |
|---|---|---|
| install copy | `~/.config/aav/home` | every switch, skill, agent and `b-*` command runs from it. never edited, never checks out `brain/logs` |
| edit copy | any path | where home and the brain are edited, logged into (`brain/logs`) and synced from |

the edit copy is the first candidate that holds `brain/bin` and is not an install copy
(`~/.config/aav/home`, `~/.config/home-manager`). candidates: `edit` in `~/.config/aav/repos.toml` when
set, else `<root>/home` for every root in order (`roots` from the same file, `["~/repos/personal"]` when
it sets none).

show every command to him before it runs. never `rm -r` a clone, never `git clean -x` in `brain/logs`:
`brain/logs/local/` holds raw transcripts that cannot be rebuilt once claude's expire.

## 1. look

```bash
ls -ld ~/.config/aav/home ~/.config/home-manager
cat ~/.config/aav/repos.toml
git rev-parse --show-toplevel && git remote get-url origin   # from where you were started
```

resolve the edit copy by the rule above. then every case that holds, in this order.

## 2. cases

**(a) no install copy.** neither `~/.config/aav/home` nor a `~/.config/home-manager` clone, and no
`home-manager` on PATH: run the installer, then come back here.

```bash
curl -fsSL https://raw.githubusercontent.com/arpadav/home/main/install.sh | sh
```

a real `~/.config/home-manager` clone needs nothing: `sy` moves it to `~/.config/aav/home`.

**(b) a symlink at `~/.config/home-manager` or `~/.config/aav/home`**: a link to a checkout, which
is usually the edit copy: offer its target as the edit copy, as in (d). remove only the link, right
before `sy`, which then clones or moves a real install copy without logs to `~/.config/aav/home`:

```bash
readlink -f ~/.config/home-manager     # the checkout it points at
rm ~/.config/home-manager              # the link, never its target; the same for ~/.config/aav/home
bash <edit copy>/bin/sy                # step 4: clones ~/.config/aav/home, switches from it
```

**(c) no edit copy.** ask with AskUserQuestion: "clone the editable copy where?", first option
`<first root>/home`. clone it over https, move origin to ssh as `sy` does, then fetch every
submodule, logs included:

```bash
git clone https://github.com/arpadav/home.git <path>
git -C <path> remote set-url origin git@github.com:arpadav/home
git -C <path> submodule update --init --recursive
```

when `<path>` is not the first `<root>/home` the rule above picks (outside every root, or an earlier
root holds another home), record it as `edit`, creating the file with the default roots when it is
missing. `edit` goes above the first `[table]`, as a literal string; an existing `edit` line is
replaced instead:

```bash
mkdir -p ~/.config/aav
[ -e ~/.config/aav/repos.toml ] || printf 'roots = ["~/repos/personal"]\n' > ~/.config/aav/repos.toml
sed -i "0,/^\[/s||edit = '<path>'\n[|" ~/.config/aav/repos.toml   # a file with a table
printf "edit = '%s'\n" <path> >> ~/.config/aav/repos.toml          # a file without one
```

an old edit copy elsewhere (a symlink target from (b), a stale `edit`): move its per-machine data
across, only when the new copy has none; both present -> ask him.

```bash
[ -e <path>/brain/logs/local ] || mv <old>/brain/logs/local <path>/brain/logs/local
```

**(d) started inside a clone of arpadav/home that is not the install copy** and is not the edit
copy: ask "use <toplevel> as the edit copy?". yes -> record it as `edit` as in (c) when it is not the
first `<root>/home` the rule picks, and move `brain/logs/local/` across from any old edit copy.

## 3. logs left in an old install copy

an install copy that was once edited may have `brain/logs` checked out, holding trace the edit copy
lacks. `sy` refuses to deinit it while it has changes, ignored files or unpushed commits. for
`logs` = `~/.config/home-manager/brain/logs` (or `~/.config/aav/home/brain/logs`), when checked out:

```bash
git -C "$logs" add -A; git -C "$logs" commit -m brain-sync || :; git -C "$logs" push
git -C <edit copy>/brain/logs pull
```

ignored files there (`logs/local/`): move them to `<edit copy>/brain/logs/local/` as in (c).

## 4. finish

```bash
bash <edit copy>/bin/sy    # existing machine, first time: an old shell's `re` builds without the brain
sy                         # every time after
```

`sy` makes or moves the install copy (`mv` of an old `~/.config/home-manager` clone), pulls it
(submodules, logs skipped) and switches. it refuses with every problem listed: relay them, fix the ones
that are plainly his setup, ask about the rest. then, in a new shell: `dirname "$(b-try find)"` and
`dirname "$AVE"` both name the edit copy.
