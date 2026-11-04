#!/usr/bin/env bash
# Live scenarios against a REAL GitHub repository you own (use a throwaway one).
#   bash tests/live.sh owner/brainsync-livetest
# Two clones on this machine act as alice (your account) and bob (simulated:
# same GitHub account, different brain branch and author name).
set -uo pipefail
REPO=${1:?usage: live.sh owner/repo}
HERE=$(cd "$(dirname "$0")" && pwd); BRAIN="$HERE/../skills/brain/scripts/brain.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0
A()  { BRAINSYNC_CONFIG_DIR="$T/acfg" bash "$BRAIN" "$@"; }
Bo() { BRAINSYNC_CONFIG_DIR="$T/bcfg" bash "$BRAIN" "$@"; }
check() { local d=$1; shift; if "$@"; then PASS=$((PASS+1)); echo "  PASS $d"; else FAIL=$((FAIL+1)); echo "  FAIL $d"; fi; }
remote_file() { gh api "repos/$REPO/contents/$(printf '%s' "$1" | sed 's/ /%20/g')" --jq .content 2>/dev/null | base64 -d; }
step() { echo "    \$ $*"; "$@" 2>&1 | sed 's/^/    /'; return "${PIPESTATUS[0]}"; }
RUN=$(date +%H%M%S)   # unique file names so the script can be re-run on the same repo

echo "== setup"
step A setup "$REPO" "$T/alice"; check "alice setup" test $? -eq 0
step Bo setup "$REPO" "$T/bob";  check "bob setup"   test $? -eq 0
git -C "$T/bob" config brainsync.login bob-sim; git -C "$T/bob" config user.name "Bob (simulated)"

echo "== push then pull"
f="ideas/pitch-$RUN.md"; mkdir -p "$T/alice/ideas"; echo "Use the meme in the deck" > "$T/alice/$f"
step A push "Pitch idea"; check "alice push ok" test $? -eq 0
step Bo pull; check "bob got the note" test -f "$T/bob/$f"

echo "== same note edited by both"
echo "Alice's take" > "$T/alice/$f"; step A push "Alice edit"; check "alice push ok" test $? -eq 0
echo "Bob's take"   > "$T/bob/$f";   step Bo push "Bob edit"; check "bob push ok" test $? -eq 0
check "shared copy is alice's" test "$(remote_file "$f")" = "Alice's take"
check "bob's copy kept" test "$(remote_file "ideas/pitch-$RUN (your version).md")" = "Bob's take"

echo "== different lines of the same note"
l="list-$RUN.md"; step A pull >/dev/null; printf 'one\ntwo\nthree\nfour\nfive\n' > "$T/alice/$l"
step A push "list"; step Bo pull >/dev/null
sed -i '' 's/one/ONE/' "$T/alice/$l"; step A push "ONE"
sed -i '' 's/five/FIVE/' "$T/bob/$l"; step Bo push "FIVE"; check "bob push ok" test $? -eq 0
check "both edits combined" test "$(remote_file "$l" | tr '\n' ' ')" = "ONE two three four FIVE "

echo "== deleted by one, edited by the other"
step A pull >/dev/null; rm "$T/alice/$l"; step A push "cleanup"
echo "extra" >> "$T/bob/$l"; step Bo pull
check "deletion respected" test ! -f "$T/bob/$l"
check "bob's edit kept" grep -q extra "$T/bob/list-$RUN (your version).md"
step Bo push "keep my list edits" >/dev/null

echo "== race: alice shares while bob's request is being merged"
step A pull >/dev/null; step Bo pull >/dev/null
r="race-$RUN.md"
cat > "$T/racy-gh" <<EOF
#!/usr/bin/env bash
if [ "\$1 \$2" = "pr merge" ] && [ ! -f "$T/raced" ]; then
  touch "$T/raced"; echo "alice wins" > "$T/alice/$r"
  BRAINSYNC_CONFIG_DIR="$T/acfg" BRAIN_GH=gh bash "$BRAIN" push "race" >/dev/null 2>&1
fi
exec gh "\$@"
EOF
chmod +x "$T/racy-gh"
echo "bob loses" > "$T/bob/$r"
out=$(BRAIN_GH="$T/racy-gh" Bo push "bob race" 2>&1); code=$?; echo "$out" | sed 's/^/    /'
check "bob's push still succeeded" test $code -eq 0
check "alice's racing version on main" test "$(remote_file "$r")" = "alice wins"
check "bob's racing version kept" test "$(remote_file "race-$RUN (your version).md")" = "bob loses"

echo "== squash-only repository"
for i in 1 2 3 4; do gh repo edit "$REPO" --enable-merge-commit=false --enable-squash-merge >/dev/null && break; sleep 5; done
step A pull >/dev/null; echo "squashy" > "$T/alice/squash-$RUN.md"
step A push "squash"; check "squash push ok" test $? -eq 0
check "local lined up with shared" test "$(git -C "$T/alice" rev-parse HEAD)" = "$(git -C "$T/alice" rev-parse origin/HEAD 2>/dev/null || git -C "$T/alice" rev-parse origin/main)"
out=$(A push 2>&1); check "nothing left to share" grep -q "Nothing new" <<<"$out"
for i in 1 2 3 4; do gh repo edit "$REPO" --enable-merge-commit >/dev/null && break; sleep 5; done

echo "== leftovers"
check "no brain/* branches left" test -z "$(gh api "repos/$REPO/branches" --jq '.[].name' | grep '^brain/')"
check "no open PRs left" test "$(gh pr list -R "$REPO" --state open --json number --jq length)" -eq 0
check "bob status clean" grep -q "No unshared edits" <<<"$(Bo status)"

echo; echo "$PASS passed, $FAIL failed"; [ $FAIL -eq 0 ]
