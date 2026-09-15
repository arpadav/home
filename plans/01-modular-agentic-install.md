# 01 - modular agentic install: every layer installable on its own

## 0. status

**not sanctioned.** rewritten after a cold architectural review (verdict: BLOCKED) whose
findings were reproduced by execution, not accepted on assertion. §7 open decisions must be
settled before this is buildable. do not execute.

## 1. goal

make each layer of the stack independently clonable and independently installable, and prove
it in containers rather than claim it.

| you want | you clone | you get |
|---|---|---|
| the whole machine | `home` | nix + dotfiles + brain + agents |
| just the brain | `aav-brain` | skills + agents + `brain-find`, **no nix** |
| just the agents | (see D3) | `~/.claude/agents/*`, **no nix, no brain, no key** |

non-goals: an `ai-tools` container repo (nothing to put in it yet); moving `logs/` (he has
said it is intrinsically brain-tied); the 171 third-party agents in `~/.claude/agents` (§7 D6).

## 2. what is actually broken (all reproduced, §6)

the review found the stated problem was the smaller one. in severity order:

1. **the curl installer has never installed the brain. on any machine. ever.** `install.sh`
   is a 35-line shim over `hi.sh`, and `hi.sh` contains **zero occurrences of `git`** - it
   only runs `nix run home-manager -- switch --flake github:arpadav/home#headless`. nothing
   clones. `home.nix:38`'s `hasBrain` probes `~/.config/home-manager/brain/agentic-files/agents`,
   which a curl-install machine does not have, so `brainLinks` is `{}`. the brain only ever
   arrives via the hand-typed `git clone --recurse-submodules` at `README.md:25`.
2. **the failure is silent.** `hasBrain = false` links nothing and prints nothing; the switch
   reports success. that silence, not the missing pull, is what cost the debugging time.
3. **the cause is protocol, not nesting depth.** `.gitmodules:3` uses `git@github.com:` (ssh)
   while `README.md:25` tells you to clone over `https`. a keyless recurse fails, the error
   scrolls past, and `brain/` is left empty. `git clone --recurse-submodules` is already
   recursive into nested submodules, so "3 levels deep" was a misdiagnosis.
4. **the brain depends on the agents harder than the agents depend on the brain**, and the
   original plan modelled only the weak direction. `flow/flow.json` names agent files as state
   owners for **7 of 31 states** (`PHASEGATE`, `REVIEW`, `RELOCATE`, `REORG` -> `brain-review-gate`;
   `VERIFY` -> `brain-verifier`; `DONE` -> `brain-learner`; `STYLE` -> the four `aav-style-*`),
   and `brain-flow.py:549` **exits non-zero** when an owner is unresolvable.
5. **`debug/` cannot test any of this today.** `enter.sh:4` bind-mounts the repo at
   `~/$USER/ahome`, but every out-of-store path resolves through
   `homeCfg = "${config.home.homeDirectory}/.config/home-manager"` (`home.nix:15`). nothing is
   mounted there, so `brainLinks` has never executed in docker. `debug/README.md` documents
   `./debug/load.sh`, which does not exist - not an oversight, a consequence. and
   `debug/Dockerfile:6` installs `curl sudo xz-utils`, **no `git`**.

## 3. worked example - the four scenarios

the artifact to validate the design against. every `OK` below is a **specification of intended
output, not a transcript** - none of these has been observed (§6.3).

### 3a. agents solo - the case that motivated this plan

```console
$ docker run -it --rm ubuntu:24.04 bash        # NO nix, NO ssh key, NO brain
# <D3 fetch: tarball-subpath, or clone aav-agents> && sh install.sh
  => fetching agents...
  => linking 5 categories into ~/.claude/agents...
  OK  agents installed (no nix, no brain, no key)

# ls -l ~/.claude/agents/
style -> ~/.local/share/aav-agents/style          # 4 aav-style-*
rust  -> ~/.local/share/aav-agents/lang/rust      # 7 aav-idiomatic/perf/security/implementer
general -> .../general    custom -> .../custom

# du -sh ~/.local/share/aav-agents
212K
```

note what is absent: no `flow.json`, no `brain-find`, no python, no ssh auth wall - and, after
D1 reverses, **no `brain-*` vocabulary**. that is the property being bought.

### 3b. brain solo - no nix anywhere

```console
$ docker run -it --rm ubuntu:24.04 bash        # git + curl only
# curl -fsSL .../aav-brain/main/install.sh | sh
  => cloning aav-brain -> ~/.local/share/aav-brain-src
  => submodules:
       agentic-files/agents  OK    (https - see D5)
       logs                  SKIP  (ssh, private; memory will be local-only)
  => linking 11 skills -> ~/.claude/skills ~/.agents/skills ~/.codex/skills
  => linking 5 agent categories + brain-agents -> ~/.claude/agents
  => brain-find -> ~/.local/bin/brain-find
  OK  aav-brain installed (no nix)

# eval "$(brain-find --export)"
# python3 $AAV_BRAIN/bin/brain-walk.py --state IDEATION     # the flow runs
# python3 $AAV_BRAIN/bin/brain-flow.py --check              # owners resolve, exit 0  <- the REAL check
```

two load-bearing details:

- **the clone target is `aav-brain-src`, never `aav-brain`.** `find_data()` already owns
  `~/.local/share/aav-brain` as the private memory dir. cloning the repo there would put the
  git checkout and the trace/evidence in one directory, so `brain-extract` would write raw
  prompts inside a git tree - the exact leak the 2026-06-15 decision moved memory out to fix.
- **`brain-walk.py` is NOT a sufficient acceptance check.** it imports no validator and never
  calls `owner_warnings`, so it prints a happy IDEATION node with the agents submodule empty.
  `brain-flow.py --check` is the check that actually fails on §2.4. use it.

### 3c. home, the curl path - honest version

```console
# curl -fsSL .../home/main/install.sh | sh
  => nix... => home-manager switch --flake github:arpadav/home#headless
  warn: no brain checkout at ~/.config/home-manager - skills NOT linked
  warn: agents supplied from flake input aav-agents (pinned, read-only)
  warn: to live-edit: git clone --recurse-submodules ... ~/.config/home-manager
  OK
```

this is the honest outcome, not a failure. the curl path installs nix + dotfiles + **agents
via flake input**, and says plainly that skills need a checkout. making `install.sh` clone is
a **different program** from the one that exists (D2).

### 3d. home, the developer clone - the full install

```console
# git clone --recurse-submodules https://github.com/arpadav/home.git ~/.config/home-manager
       brain                       OK   (https - see D5)
       brain/agentic-files/agents  OK
       brain/logs                  OK   (ssh; you have the key)
# cd ~/.config/home-manager && re
```

### 3e. the self-heal you asked about

`aedit/module.nix:11-18` already generalises this into a named `live`/`store`/`src` triple.
reuse those names rather than inventing a fourth spelling:

```nix
# probe a LEAF: an uninitialised submodule is an EMPTY DIR and pathExists says true (§6 P1)
agentsSrc = if onDisk "${aavBrain}/agentic-files/agents/style"
            then mkOutOfStoreSymlink "${aavBrain}/agentic-files/agents"   # live-edit
            else inputs.aav-agents;                                       # store, pinned
```

**an activation script cannot do this.** `home.nix` enumerates links at *eval* time and
`home.activation` runs after, so a self-healing activation produces a healed tree and zero
links on the first switch. the flake input is the only one-pass mechanism.

three corrections the review forced here:

- **`builtins.readDir` enumerates SKILLS, not agents** (`home.nix:29`); agents are five
  hardcoded lines at `home.nix:56-65`. the original justification described skills and applied
  the remedy to agents. **`skillsRoot` needs the same fallback**, or `re` on an uninitialised
  brain still links zero skills, silently - killing half the bug and declaring victory.
- **`hasBrain` must be redefined too.** it is `onDisk agentsRoot` (`home.nix:38`). once
  `agentsRoot` falls back to a store path it becomes unconditionally true, firing
  `.codex/agents`, `.local/share/aav-brain -> logs` and the `brainCompile` activation against
  a brain that is not there. the leaf probe fixes the measured symptom and re-arms it one
  identifier over.
- `home.nix:1` is `{ pkgs, config, lib, ... }:` - it does not destructure `inputs`. and a flake
  input *is* in the store, so that branch is `.source = inputs.aav-agents`, not
  `mkOutOfStoreSymlink`.

## 4. phases

reordered per the review: **each scenario ships with the phase that creates its fixture.**
the original ordering required the pre-merge gate to read fixtures that only exist post-merge.

### phase 0 - make the docker box able to test anything at all

- fix the mount: `enter.sh` must bind-mount to `~/.config/home-manager`, not `~/ahome`, or
  `home.nix`'s out-of-store paths never resolve. this is why `load.sh` was never written.
- `debug/Dockerfile`: add `git`.
- `debug/load.sh` - the script the README already promises.
- `debug/matrix.sh --source local|main`, defaulting to the bind-mounted tree. only **3c/3d**
  are runnable today; 3a and 3b land with the phases that create them.
- acceptance: `matrix.sh` runs and reports deterministically, and the recorded baseline is
  whatever it actually prints - **not** a predicted "4 FAIL".

files: `debug/{Dockerfile,enter.sh,load.sh,matrix.sh,README.md}`.

### phase 1 - unbreak the brain's own tooling (MUST precede any extraction)

this phase is why "zero code churn" was false. both are reproduced in §6.

- `compile.py:225` does a bare `rglob("*.md")` and `Agent.parse` (`:152`) raises on any file
  without a frontmatter fence. an extracted repo carries a `README.md`; **`compile.py` then
  hard-crashes**, and `home.nix:137-142` swallows it as a one-line warning, so codex agents
  silently freeze. `Compiler` is first in `run_all`, so `Preamble` never runs either and
  `~/.claude/CLAUDE.md`'s generated block freezes too.
- fix: give `Compiler` **explicit include-roots** (the derived category dirs, §6 P2) instead
  of a bare rglob. rejected alternative: skip files lacking a fence - that weakens the
  "a stray non-agent `.md` is a build error, not a silent half-agent" contract `compile.py`
  documents at `:140-145`.
- same fix at `brain-flow.py:320`, which would otherwise admit `README` as a legal owner name.
- acceptance: drop a `README.md` into `agentic-files/agents/`; `compile.py --check` and
  `brain-flow.py --check` both exit 0. (today it raises `ValueError` - reproduced §6 P7.)

files: `brain/bin/compile.py`, `brain/bin/brain-flow.py`.

### phase 2 - move the brain's own agents out of the generic corpus (D1, reversed)

- `agentic-files/agents/brain/{brain-verifier,brain-review-gate,brain-learner}.md`
  -> `agentic-files/brain-agents/`, brain-tracked.
- `agentic-files/agents/` becomes 100% extractable, carrying **zero brain vocabulary**.
- four edits: a `Layout` property beside `agents` (`brainlib.py:1044-1052`); union it into
  `brain-flow.py:319-320`; a second `Compiler` root (`compile.py:317`); retarget
  `home.nix:56-57`'s `.claude/agents/brain`.
- acceptance: `brain-flow.py --check` exits 0 with all 7 owner states resolving; `grep -ril
  "brain-" agentic-files/agents/` is empty.

### phase 3 - extract, per D3

only if D3 chooses a repo. subtree-split, push **public**, re-attach at the same path with an
**https** url (D5). if D3 chooses the tarball, this phase is deleted and 3a is a fetch script.

- acceptance: 3a passes in a keyless container.

### phase 4 - the installers, factored not copy-pasted

- `diff install.sh aedit/install.sh` is **4 changed lines** - already a copy-paste pair. do
  not add installers #3 and #4 to it; parameterise first.
- `hi.sh:31-36`'s `step`/`die`/`need` + colour block become a sourceable `lib.sh`.
- **`brain/install.sh` execs `agentic-files/agents/install.sh`** for the agents half rather
  than re-rolling the category rule. it is a submodule; the script is right there.
- the skills half **derives** from the filesystem (same shape as `home.nix:29`'s `readDir`),
  never enumerates 11 names.
- `git submodule update --init --recursive` goes in whatever **clones** - NOT in `hi.sh`,
  which is the generic bootstrapper shared verbatim with `aedit/install.sh` and has no
  working-tree concept and no `git` dependency.
- acceptance: 3b passes keyless.

### phase 5 - `home.nix` stops owning the wiring; fail loud

- flake input; the `agentsSrc` + `skillsSrc` fallbacks; `hasBrain` redefined (§3e).
- a missing brain **warns by name** instead of silently linking nothing.
- acceptance: 3c and 3d pass; `re` with no brain prints a named warning.

### phase 6 - docs match reality

`brain/README.md:7,21,38` and `ARCHITECTURE.md:11,14,50,156,157` say "ONE repo". use `grep -in`
and include the layout blocks - the original's `grep -rn "ONE repo"` misses the lowercase sites.

## 5. review-gate strategy

per P03: cold, unguided, all N reviewers returning before any fix lands, findings adjudicated
against this plan's contract before becoming work.

- after each phase: `Agent(brain-review-gate)` on the phase diff.
- phases 1-2 additionally `Agent(aav-semantic-architecture-reviewer)` - they move code and a
  directory across a boundary.
- phases 0/4 are shell+nix: `Agent(aav-style-separators)` + `Agent(aav-style-docs)`.
- **`Agent(brain-verifier)` is the gate that matters.** every acceptance check here is a
  container run or a `--check` exit code, not a code read. it runs them and reports real
  output. no phase advances on a claimed PASS (P04) - this review already caught one
  "confirmed" claim that was a broken probe (§6 P5).

## 6. verification - what was executed, not asserted

### 6.1 first pass (plan v1)

| # | claim | result |
|---|---|---|
| P1 | empty submodule dir fools `pathExists` | **CONFIRMED** - dir `true`, leaf `false`, `readDir` `{ }` |
| P2 | "dir directly containing `*.md`" derives exactly the 5 hardcoded categories | **CONFIRMED** - `lang/rust` flattens to `rust` |
| P3 | no basename collision today | **CONFIRMED** |
| P4 | `find_data()` collides with a naive install target | **CONFIRMED** - `~/.local/share/aav-brain` |
| P5 | brain degrades, not fails, without `logs/` | **CONFIRMED** - walk, recall, trace all run on an empty data dir |
| P6 | `subtree split` keeps history | **CONFIRMED** - but only **3 commits** |

### 6.2 second pass (the review's claims, re-run rather than trusted)

| # | claim | result |
|---|---|---|
| P7 | a stray `README.md` crashes `compile.py` | **CONFIRMED by execution.** copied one in; `ValueError: .../README.md: no opening frontmatter fence`. tree restored |
| P8 | `hi.sh` never clones | **CONFIRMED** - `grep -c git hi.sh` = **0** |
| P9 | the 3 brain agents do NOT name flow states | **CONFIRMED** - 0 matches. **plan v1's D1 premise was wrong** |
| P10 | flow.json names agents as owners of 7 states | **CONFIRMED** - RELOCATE, REORG, PHASEGATE, REVIEW, VERIFY, DONE, STYLE |
| P11 | `install.sh` and `aedit/install.sh` are near-identical | **CONFIRMED** - 4 changed lines |

**a process note worth keeping.** P10 first came back "0 of 31 states", which would have
discounted the reviewer wholesale. the probe was wrong, not the claim: `flow.json`'s `states`
is a **list**, and the script iterated it as a dict behind an `isinstance` guard, so the loop
body never ran and it reported a confident zero. re-run correctly, the reviewer was exactly
right. a green check from a probe that never executed is the failure mode P04 exists for.

### 6.3 not covered

every `OK` in §3 is **designed, not observed**. no container has run any of it. that is
phase 0's job, and why it is first.

## 7. open decisions - all blocking

**D1. move the brain's own agents out of the generic corpus?** plan v1 said ship them and
justified it with "they name flow states" - **factually wrong** (P9). the real coupling is
inverted: the brain hard-depends on the agents by name, gate-enforced (P10). shipping
`brain-*` files inside a corpus whose whole purpose is brain-independence is domain-term
leakage into the lower layer.
*rec: REVERSE v1 - move them to `agentic-files/brain-agents/`. four edits (phase 2).*

**D2. does `install.sh` become a clone-based installer, or stay flake-only?** today it cannot
install the brain at all (§2.1). (a) it grows a clone-to-`~/.config/home-manager` path - a
different program from what exists; (b) the curl path is documented as nix+dotfiles+agents-via-
flake-input, and the brain needs the developer clone.
*rec: (b). it is honest, it is one doc change, and it makes 3c a real scenario rather than fiction.*

**D3. does `aav-agents` need to exist at all?** `aav-brain` is already public, so agents-solo
can be a tarball subpath fetch with **zero** new machinery, zero gitlink, zero new provenance:
`curl -L codeload.github.com/arpadav/aav-brain/tar.gz/main | tar xz --strip=3 -C <dst> aav-brain-main/agentic-files/agents`.
against that: a tarball has no git, so no `pull`, no pinning, no contributing back - and you
edit this corpus constantly. the repo buys an editing loop; it costs a third gitlink and (P6)
3 commits of history is the whole thing being preserved.
*rec: no strong lean. if you will `git pull` the agents from another tool -> repo. if consumer
#2 only ever reads them -> tarball, and this plan loses phase 3 entirely.* **your call.**

**D4. provenance: submodule or flake input - pick ONE.** plan v1 had `brain` arriving as a
submodule and `aav-agents` as a submodule *plus* a flake input: two mechanisms, two failure
modes, two init commands, for two layers of one tree. the review's alternative: make **`brain`
a flake input of `home`** too, killing nesting level 1 entirely, with the on-disk checkout as
the live-edit override via the existing `onDisk` probe (`aedit/module.nix:17`'s `src`). private
`logs` still works because the *checkout* supplies it.
*rec: brain as a flake input with an on-disk override. it collapses the nesting question and
is the same idiom you already run for `aedit`.* **your call.**

**D5. gitmodule protocol.** §3b's keyless `agents OK` only holds if the new entry is `https://`
while `logs` stays `ssh`. that mixed-protocol requirement is load-bearing.
*rec: https for everything public; ssh only for `logs`. also fix `.gitmodules:3`'s existing
ssh url for `brain`, which is what breaks the `README.md:25` https clone.*

**D6. the 171 unmanaged agents.** `~/.claude/agents/` holds 171 loose `.md` files installed
ad-hoc by `agent-installer`, tracked by nothing. out of scope, but it is the largest remaining
modularity hole.
*rec: separate plan `02-third-party-agents.md`.*

**D7. `aav-brain/install.sh` on a nix-managed machine.** home-manager owns `~/.claude/skills/*`
and `~/.local/share/aav-brain -> logs` (`home.nix:68`). the sh installer wants those paths.
*rec: detect a home-manager-managed link at the target and hard-refuse: "this machine is
nix-managed, run `re`". the two paths are mutually exclusive per machine.*

## 8. deferred findings (real, logged, not this plan)

- `brainlib.py:1371` `find_repo()` tests `(dir/".git").exists()`, **true for a gitlink file**,
  so a decision logged from inside a submodule records the wrong repo name in the append-only
  ledger. low frequency, permanent record.
- `home.nix:66-67` links `.codex/agents` -> `${aavBrain}/.generated/codex/agents`, which is
  gitignored and absent until `compile.py` runs - a dangling symlink on first switch. the
  matrix will surface it.
