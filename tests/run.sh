#!/usr/bin/env bash
# End-to-end scenarios for brain.sh with two simulated users (alice, bob)
# sharing a local bare repo through a fake GitHub CLI.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
BRAIN="$HERE/../skills/brainsync/scripts/brain.sh"
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
sedi() { sed "$1" "$2" > "$2.tmp" && mv "$2.tmp" "$2"; }  # portable sed -i
hex() { od -An -tx1 | tr -d ' \n'; }                       # portable xxd -p
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
sedi 's/one/ONE/' "$T/alice/list.md"; as alice push >/dev/null
sedi 's/five/FIVE/' "$T/bob/list.md"; as bob push >/dev/null
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
check "binary: shared version kept" test "$(remote_file pic.png | hex)" = "89504e4702"
check "binary: bob's version kept" test "$(remote_file 'pic (your version).png' | hex)" = "89504e4703"

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

echo "== setup refuses a folder inside iCloud or OneDrive"
out=$(HOME="$T/home" as carol setup fake/brain "$T/home/Library/Mobile Documents/com~apple~CloudDocs/Brain"); echo "$out" | sed 's/^/    /'
check "iCloud folder refused" grep -q "inside iCloud" <<<"$out"
check "nothing downloaded there" test ! -e "$T/home/Library/Mobile Documents/com~apple~CloudDocs/Brain"

echo "== sign-in helper uses the full path to gh"
check "credential helper is absolute" grep -q "^!'/" <<<"$(git -C "$T/alice" config --get-all credential.helper | tail -1)"

case $(uname -s) in
  MINGW*|MSYS*|CYGWIN*)
    # Windows can't create such a name, so test the receiving side: a
    # teammate's note called "Call 10:30.md" arrives and is explained.
    echo "== a teammate's note with a name Windows can't store"
    # Built with plumbing in the shared repo: Windows can't check this file out.
    R=(git --git-dir="$FAKE_GH_REMOTE" -c user.name=mac -c user.email=m@x)
    blob=$(echo x | "${R[@]}" hash-object -w --stdin)
    tree=$({ "${R[@]}" ls-tree main; printf '100644 blob %s\tCall 10:30.md\n' "$blob"; } | "${R[@]}" mktree)
    "${R[@]}" update-ref refs/heads/main "$("${R[@]}" commit-tree "$tree" -p main -m "mac note")"
    out=$(as bob pull); code=$?; echo "$out" | sed 's/^/    /'
    check "pull fails safely" test $code -eq 1
    check "explains the name problem" grep -q "name this computer can't store" <<<"$out"
    tree=$("${R[@]}" ls-tree main | grep -v 'Call 10:30' | "${R[@]}" mktree)
    "${R[@]}" update-ref refs/heads/main "$("${R[@]}" commit-tree "$tree" -p main -m "renamed")"
    as bob pull >/dev/null && as alice pull >/dev/null
    check "pull works again after the rename" test $? -eq 0
    ;;
  *)
    echo "== names Windows can't store get a warning"
    echo "x" > "$T/alice/Call 10:30.md"; echo "y" > "$T/alice/fine name.md"
    out=$(as alice push "names"); echo "$out" | sed 's/^/    /'
    check "warned about the colon" grep -q "won't work for teammates on Windows" <<<"$out"
    check "only the bad name listed" test "$(grep -c '•' <<<"$out")" -eq 1
    check "still shared" remote_has "Call 10:30.md"
    git -C "$T/alice" rm -q "Call 10:30.md"; as alice push "rename" >/dev/null; as bob pull >/dev/null

    ;;
esac

echo "== Windows (Git Bash) behaviour, simulated"
W="$T/winbin"; mkdir -p "$W"; printf '#!/bin/sh\necho MINGW64_NT-10.0\n' > "$W/uname"; chmod +x "$W/uname"
out=$(PATH="$W:$PATH" HOME="$T/whome" as dana setup fake/brain "$T/whome/OneDrive - Acme/Brain"); echo "$out" | sed 's/^/    /'
check "OneDrive folder refused" grep -q "inside OneDrive" <<<"$out"
out=$(PATH="$W:$PATH" as dana setup fake/brain "$T/dana"); echo "$out" | sed 's/^/    /'
check "windows setup works" grep -q "All set" <<<"$out"
check "line endings handled" test "$(git -C "$T/dana" config core.autocrlf)" = true
check "long paths enabled" test "$(git -C "$T/dana" config core.longpaths)" = true
out=$(PATH="$W:$PATH" BRAIN_GH=/nonexistent/gh as dana doctor); echo "$out" | sed 's/^/    /'
check "windows install hint" grep -q "winget install --id GitHub.cli" <<<"$out"

echo "== sign-in without a terminal"
touch "$FAKE_GH_STATE/signed-out-erin"
out=$(as erin signin); code=$?; echo "$out" | sed 's/^/    /'
check "signin waits for the user (exit 3)" test $code -eq 3
check "signin shows the one-time code" grep -q "ABCD-1234" <<<"$out"
out=$(as erin signin-wait); echo "$out" | sed 's/^/    /'
check "signin-wait sees the sign-in" grep -q "Signed in to GitHub as erin" <<<"$out"

echo "== install-tools when everything is there"
out=$(as erin install-tools); echo "$out" | sed 's/^/    /'
check "install-tools reports ready" grep -q "GitHub helper is ready" <<<"$out"

echo "== doctor"
out=$(as bob doctor); echo "$out" | sed 's/^/    /'
check "doctor passes when ready" grep -q "Everything looks ready" <<<"$out"
out=$(BRAIN_GH=/nonexistent/gh as bob doctor); code=$?; echo "$out" | sed 's/^/    /'
check "doctor flags missing gh" test $code -eq 1
check "doctor explains the fix" grep -q "GitHub helper is missing" <<<"$out"

echo "== status is clean at the end"
out=$(as bob status); echo "$out" | sed 's/^/    /'
check "no unshared edits" grep -q "No unshared edits" <<<"$out"

echo; echo "$PASS passed, $FAIL failed"; [ $FAIL -eq 0 ]
