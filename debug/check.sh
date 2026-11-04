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
#     brain=DIR  brain linked from DIR; b-find, its -e export, AAV_BRAIN and AVB agree
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
# the file sources once per login; unset its guard so it sets the vars here
unset __HM_SESS_VARS_SOURCED
# shellcheck disable=SC1090
. "$vars" 2>/dev/null
export PATH="$HOME/.nix-profile/bin:$HOME/.local/bin:$PATH"

# --------------------------------------------------
# every link home-manager made resolves. checkouts and
# nix's own bookkeeping are not its links, and neither
# is a link pointing anywhere but the store or the
# checkout: apps leave dangling ones on purpose (snap
# themes, browser and mail lock files)
# --------------------------------------------------
d=$(find -L "$HOME" -maxdepth 4 \( -path "$cfg" -o -path "$HOME/src" -o -path "$HOME/aav-brain" \
    -o -path "$HOME/.nix-defexpr" -o -path "$HOME/.cache" -o -path "$HOME/.local/state" \) -prune \
    -o -type l -print 2>/dev/null |
    while read -r l; do
        case $(readlink "$l") in /nix/store/* | "$cfg"/*) echo "$l" ;; esac
    done)
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
            root=$(readlink -f "${e#brain=}")
            t=$(readlink -f ~/.claude/skills/brain-plan 2>/dev/null)
            case $t in "$root"/*) ok "skills link into $root" ;; *) bad "skills resolve to '$t', not $root" ;; esac
            # each script Layout.scripts (bin/brainlib/paths.py) names has its command
            n=0
            while read -r script; do
                c=$HOME/.local/bin/b-$(basename "$script" .py | sed 's/^brain-//')
                [ -x "$c" ] && n=$((n + 1)) || bad "$c missing for $script"
            done < <(find "$root/bin" -maxdepth 2 -type f -name 'brain-?*.py' -not -path '*/brainlib/*' 2>/dev/null)
            [ "$n" -gt 0 ] && ok "$n b-* commands in ~/.local/bin" || bad "no b-* command in ~/.local/bin"
            out=$(b-find 2>&1)
            [ "$out" = "$root" ] && ok "b-find -> $out" || bad "b-find gave '$out', not $root"
            out=$(b-find -e)
            # shellcheck disable=SC2030,SC2031
            (eval "$out" && [ "$(readlink -f "$AAV_BRAIN")" = "$root" ] && [ "$(readlink -f "$AVB")" = "$root" ]) 2>/dev/null &&
                ok "b-find -e exports AAV_BRAIN and AVB" || bad "b-find -e gave '$out'"
            for v in AAV_BRAIN AVB; do
                [ -n "${!v:-}" ] && [ "$(readlink -f "${!v}")" = "$root" ] && ok "$v=${!v}" || bad "$v is '${!v:-}', not $root"
            done
            [ -d ~/.codex/agents ] && ok "codex agents compiled" || bad "codex agents missing"
            ;;
        nobrain)
            # a brain command is a wrapper exec-ing a brain script; any other b-* is not the brain's
            c=$(grep -lE 'python3 -I .*/brain-[^/]*\.py' ~/.local/bin/b-* 2>/dev/null)
            [ -z "$c" ] && ok "no b-* command" || bad "b-* installed without a brain: $(echo "$c" | tr '\n' ' ')"
            [ -z "$(ls -A ~/.claude/skills 2>/dev/null)" ] && ok "no skills linked" || bad "skills linked without a brain"
            for v in AAV_BRAIN AVB; do
                grep -q "\b$v=" "$vars" 2>/dev/null && bad "$v exported without a brain" || ok "no $v"
            done
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
