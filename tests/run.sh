#!/usr/bin/env bash
# End-to-end scenarios for brain.sh with two simulated users (alice, bob)
# sharing a local bare repo through a fake GitHub CLI.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
BRAIN="$HERE/../skills/brain/scripts/brain.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export BRAIN_GH="$HERE/fake-gh" FAKE_GH_REMOTE="$T/remote.git" FAKE_GH_STATE="$T/gh"
export GIT_CONFIG_GLOBAL="$T/gitconfig" GIT_CONFIG_NOSYSTEM=1
chmod +x "$BRAIN_GH" "$BRAIN"
PASS=0; FAIL=0

as() {  # as <user> <brain args...>
  local u=$1; shift
  FAKE_GH_LOGIN=$u BRAINSYNC_CONFIG_DIR="$T/$u-config" bash "$BRAIN" "$@"
}
check() {  # check <description> <command...>
  local d=$1; shift
  if "$@"; then PASS=$((PASS+1)); echo "  PASS $d"; else FAIL=$((FAIL+1)); echo "  FAIL $d"; fi
}
remote_file() { git --git-dir="$FAKE_GH_REMOTE" show "main:$1" 2>/dev/null; }
remote_has()  { git --git-dir="$FAKE_GH_REMOTE" cat-file -e "main:$1" 2>/dev/null; }

git init -q --bare -b main "$FAKE_GH_REMOTE"

echo "== setup on an empty repository"
as alice setup fake/brain "$T/alice" | sed 's/^/    /'
as bob   setup fake/brain "$T/bob"   | sed 's/^/    /'
check "README created in remote" remote_has README.md
check "identity set from GitHub" test "$(git -C "$T/alice" config user.name)" = alice

echo "== alice pushes a new note, bob pulls it"
mkdir -p "$T/alice/ideas"; echo "Use the meme in the deck" > "$T/alice/ideas/pitch.md"
as alice push "Pitch idea" | sed 's/^/    /'
check "note is on shared main" remote_has ideas/pitch.md
check "PR branch cleaned up" test -z "$(git --git-dir="$FAKE_GH_REMOTE" branch --list 'brain/*')"
as bob pull | sed 's/^/    /'
check "bob has the note" test -f "$T/bob/ideas/pitch.md"

echo "== both edit the same line: shared wins, bob's copy kept"
echo "Alice's take" > "$T/alice/ideas/pitch.md"; as alice push "Alice edit" >/dev/null
echo "Bob's take"   > "$T/bob/ideas/pitch.md";   out=$(as bob push "Bob edit"); echo "$out" | sed 's/^/    /'
check "shared file keeps alice's text" test "$(remote_file ideas/pitch.md)" = "Alice's take"
check "bob's version shared as backup" test "$(remote_file 'ideas/pitch (your version).md')" = "Bob's take"
check "user was told about the overlap" grep -q "your version" <<<"$out"
check "no conflict markers anywhere" bash -c "! grep -rq '^<<<<<<<' '$T/bob' --exclude-dir=.git"

echo "== non-overlapping edits to the same file merge silently"
printf 'one\ntwo\nthree\nfour\nfive\n' > "$T/alice/list.md"; as alice push >/dev/null; as bob pull >/dev/null
sed -i '' 's/one/ONE/' "$T/alice/list.md"; as alice push >/dev/null
sed -i '' 's/five/FIVE/' "$T/bob/list.md"; as bob push >/dev/null
check "both edits present" test "$(remote_file list.md | tr '\n' ' ')" = "ONE two three four FIVE "
check "no backup for clean merge" bash -c "! git --git-dir='$FAKE_GH_REMOTE' cat-file -e 'main:list (your version).md' 2>/dev/null"

echo "== teammate deletes a note the other edited"
as alice pull >/dev/null
rm "$T/alice/list.md"; as alice push "cleanup" >/dev/null
echo "my extra line" >> "$T/bob/list.md"; out=$(as bob pull); echo "$out" | sed 's/^/    /'
check "deleted file stays deleted for bob" test ! -f "$T/bob/list.md"
check "bob's edit kept as backup" grep -q "my extra line" "$T/bob/list (your version).md"

echo "== race: someone shares while the PR is being merged"
as alice pull >/dev/null; as bob push >/dev/null; as alice pull >/dev/null
cat > "$T/race.sh" <<EOF
echo "sneaky" > "$T/alice/race.md"; FAKE_GH_LOGIN=alice BRAINSYNC_CONFIG_DIR="$T/alice-config" FAKE_GH_BEFORE_MERGE= bash "$BRAIN" push race >/dev/null
EOF
echo "bob race" > "$T/bob/race.md"
out=$(FAKE_GH_BEFORE_MERGE="$T/race.sh" as bob push "bob race"); echo "$out" | sed 's/^/    /'
check "push still succeeded" grep -q "Shared!" <<<"$out"
check "alice's racing version on main" test "$(remote_file race.md)" = "sneaky"
check "bob's racing version kept" test "$(remote_file 'race (your version).md')" = "bob race"

echo "== repo that requires review"
echo "needs review" > "$T/bob/review.md"
out=$(FAKE_GH_REQUIRE_REVIEW=1 as bob push "Review me"); code=$?; echo "$out" | sed 's/^/    /'
check "exit code 2 = waiting" test $code -eq 2
check "approval link given" grep -q "pull/" <<<"$out"
echo "more" >> "$T/bob/review.md"
FAKE_GH_REQUIRE_REVIEW=1 as bob push "Review me" >/dev/null
check "second push reused the same PR" test "$(grep -c 'brain/bob .* open' "$FAKE_GH_STATE/prs")" -eq 1
out=$(FAKE_GH_REQUIRE_REVIEW=1 as bob status); echo "$out" | sed 's/^/    /'
check "status mentions pending approval" grep -q "waiting for a teammate" <<<"$out"
as bob push >/dev/null   # review rule lifted → merges
check "pending change landed later" remote_has review.md

echo "== repo that only allows squash"
echo "squashy" > "$T/alice/squash.md"; as alice pull >/dev/null
out=$(FAKE_GH_NO_MERGE_COMMITS=1 as alice push "squash"); echo "$out" | sed 's/^/    /'
check "squash fallback merged" remote_has squash.md
check "local history lined up with shared" test "$(git -C "$T/alice" rev-parse HEAD)" = "$(git --git-dir="$FAKE_GH_REMOTE" rev-parse main)"
out=$(as alice push); check "nothing-to-share detected" grep -q "Nothing new" <<<"$out"

echo "== binary file conflict"
printf '\x89PNG\x01' > "$T/alice/pic.png"; as alice push >/dev/null; as bob pull >/dev/null
printf '\x89PNG\x02' > "$T/alice/pic.png"; as alice push >/dev/null
printf '\x89PNG\x03' > "$T/bob/pic.png";   as bob push >/dev/null
check "binary: shared version kept" test "$(remote_file pic.png | xxd -p)" = "89504e4702"
check "binary: bob's version kept" test "$(remote_file 'pic (your version).png' | xxd -p)" = "89504e4703"

echo "== GitHub answers 502 but created the PR anyway"
echo "flaky" > "$T/bob/flaky.md"
out=$(FAKE_GH_FLAKY_CREATE=1 BRAIN_BACKOFF=0 as bob push "flaky"); echo "$out" | sed 's/^/    /'
check "push recovered from 502" grep -q "Shared!" <<<"$out"
check "no duplicate PR created" test "$(grep -c 'brain/bob' "$FAKE_GH_STATE/prs")" -eq "$(grep -c 'brain/bob .* merged' "$FAKE_GH_STATE/prs")"

echo "== GitHub errors on merge but the merge went through"
echo "flaky merge" > "$T/bob/flaky-merge.md"
out=$(FAKE_GH_FLAKY_MERGE=1 BRAIN_BACKOFF=0 as bob push "flaky merge"); echo "$out" | sed 's/^/    /'
check "push reported success" grep -q "Shared!" <<<"$out"
check "file is on main" remote_has flaky-merge.md

echo "== status is clean at the end"
out=$(as bob status); echo "$out" | sed 's/^/    /'
check "no unshared edits" grep -q "No unshared edits" <<<"$out"

echo; echo "$PASS passed, $FAIL failed"; [ $FAIL -eq 0 ]
