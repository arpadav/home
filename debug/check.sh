#!/usr/bin/env bash
#
# assert what a finished switch left in $HOME. run inside a matrix container
#
# Usage:
#   check.sh <expect>...
#     home       home packages and dotfiles
#     aedit      helix/broot config, hx and ae on PATH
#     live       configs link into the checkout at ~/.config/home-manager
#     store      configs are store copies
#     brain=DIR  brain linked from DIR, brain-find and AAV_BRAIN agree
#     nobrain    nothing of the brain installed
#
# Author: aav
# --------------------------------------------------
set -u
fail=0
ok() { printf '  ok    %s\n' "$1"; }
bad() {
    printf '  FAIL  %s\n' "$1"
    fail=1
}
# --------------------------------------------------
# where the switch left things, and the PATH it set up
# --------------------------------------------------
cfg=$HOME/.config/home-manager
vars=$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh
# shellcheck disable=SC1090
. "$vars" 2>/dev/null
export PATH="$HOME/.nix-profile/bin:$HOME/.local/bin:$PATH"

# --------------------------------------------------
# every link home-manager made resolves. checkouts and
# nix's own bookkeeping are not its links
# --------------------------------------------------
d=$(find -L "$HOME" -maxdepth 4 \( -path "$cfg" -o -path "$HOME/src" -o -path "$HOME/aav-brain" \
    -o -path "$HOME/.nix-defexpr" -o -path "$HOME/.cache" -o -path "$HOME/.local/state" \) -prune \
    -o -type l -print 2>/dev/null)
[ -z "$d" ] && ok "no dangling links" || bad "dangling links: $(echo "$d" | tr '\n' ' ')"

# --------------------------------------------------
# each expectation named on the command line
# --------------------------------------------------
for e in "$@"; do
    case $e in
        home)
            [ -e ~/.tmux.conf ] && ok ".tmux.conf present" || bad ".tmux.conf missing"
            command -v rg >/dev/null && ok "rg on PATH" || bad "rg not on PATH"
            ;;
        aedit)
            for f in .config/helix/config.toml .config/helix/languages.toml .config/broot/broot-conf.hjson .bash_functions; do
                [ -e "$HOME/$f" ] && ok "$f present" || bad "$f missing"
            done
            command -v hx >/dev/null && ok "hx on PATH" || bad "hx not on PATH"
            command -v ae >/dev/null && ok "ae on PATH" || bad "ae not on PATH"
            ;;
        live | store)
            for f in .config/helix/config.toml .bash_functions .tmux.conf; do
                [ -e "$HOME/$f" ] || continue
                t=$(readlink -f "$HOME/$f")
                case $e:$t in
                    live:"$cfg"/* | store:/nix/store/*) ok "$f is $e" ;;
                    *) bad "$f should be $e, resolves to $t" ;;
                esac
            done
            ;;
        brain=*)
            root=${e#brain=}
            t=$(readlink -f ~/.claude/skills/brain-plan 2>/dev/null)
            case $t in "$root"/*) ok "skills link into $root" ;; *) bad "skills resolve to '$t', not $root" ;; esac
            out=$(brain-find 2>&1)
            [ "$out" = "$root" ] && ok "brain-find -> $out" || bad "brain-find gave '$out', not $root"
            [ "${AAV_BRAIN:-}" = "$root" ] && ok "AAV_BRAIN=$AAV_BRAIN" || bad "AAV_BRAIN is '${AAV_BRAIN:-}', not $root"
            [ -d ~/.codex/agents ] && ok "codex agents compiled" || bad "codex agents missing"
            ;;
        nobrain)
            [ ! -e ~/.local/bin/brain-find ] && ok "no brain-find" || bad "brain-find installed without a brain"
            [ -z "$(ls -A ~/.claude/skills 2>/dev/null)" ] && ok "no skills linked" || bad "skills linked without a brain"
            grep -q AAV_BRAIN "$vars" 2>/dev/null && bad "AAV_BRAIN exported without a brain" || ok "no AAV_BRAIN"
            ;;
        *)
            bad "unknown expectation $e"
            ;;
    esac
done
# --------------------------------------------------
# non-zero when any expectation failed
# --------------------------------------------------
exit $fail
