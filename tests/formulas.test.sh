#!/usr/bin/env bash
# End-to-end walk of the arena formulas against a real bd binary: pours a season, slices tickets,
# runs a round to a (simulated) merge, a bout and a patrol, and checks every gate on the way.
# Usage: tests/formulas.test.sh   (needs bd, jq, git on PATH; BD=/path/to/bd to override)
set -euo pipefail
command -v "${BD:-bd}" >/dev/null 2>&1 && "${BD:-bd}" version >/dev/null 2>&1 || { echo "bd not found or not runnable: install @beads/bd (unset CI, see README)"; exit 1; }
PLUGIN="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
BD="${BD:-bd}"
WORK="$(mktemp -d)"; trap '[ -n "${KEEP:-}" ] && echo "workspace kept: $WORK" || rm -rf "$WORK"' EXIT
cd "$WORK" && git init -q
$BD init --quiet --prefix ar >/dev/null 2>&1
mkdir -p .beads/formulas && cp "$PLUGIN"/formulas/*.toml .beads/formulas/
$BD config set validation.on-create error >/dev/null
$BD config set status.custom "in_review:wip" >/dev/null
$BD mol pour arena-season --var name=dark-mode --var hypothesis="we believe a dark theme raises evening session length by 10 percent for night users" >/dev/null
R=$($BD list --type molecule --json | jq -r '.[0].id')

step() { { $BD children "$R" --json; $BD gate list --all --json; } | jq -rs --arg t "$1" 'add | .[] | select(.title|test($t)) | .id' | head -1; }
ready_titles() { $BD ready --json | jq -r '.[]? | .title' | sort | tr '\n' '|'; echo; }
fails=0
check() { if [[ -n "$3" && "$2" == *"$3"* ]] || [[ -z "$3" && -z "$2" ]]; then echo "PASS $1"; else echo "FAIL $1 :: got [$2] want [$3]"; fails=$((fails+1)); fi; }
refute() { if [[ "$2" != *"$3"* ]]; then echo "PASS $1"; else echo "FAIL $1 :: [$3] should be absent"; fails=$((fails+1)); fi; }

FRAME=$(step "^Frame"); SPEC=$(step "^Spec"); SIGN=$(step "signs off"); SLICE=$(step "^Slice")
SLSIGN=$(step "breakdown"); BUILD=$(step "^Build"); INTEG=$(step "^Integrate"); REL=$(step "^Prepare")
SHIPOK=$(step "deploy$"); SHIP=$(step "^Ship"); BAKE=$(step "^Bake")

$BD close "$FRAME" --reason "grilled" >/dev/null
check "spec ready after frame" "$(ready_titles)" "Spec dark-mode"
$BD close "$SPEC" --reason "spec written" >/dev/null
refute "signoff hidden from agent ready queue" "$(ready_titles)" "signs off"
check "signoff listed for the human" "$($BD gate list --json | jq -r '.[].id' | tr '\n' ' ')" "$SIGN"
$BD gate resolve "$SIGN" --reason "approved" >/dev/null
check "slice ready after signoff" "$(ready_titles)" "Slice dark-mode"

# slice: tickets under the build step, in one graph transaction
cat > plan.json <<EOF
{"commit_message":"arena: slice dark-mode",
 "nodes":[
  {"key":"t1","title":"Theme tokens end to end","type":"task","parent_id":"$BUILD","description":"tokens","acceptance_criteria":"- tokens resolve in light and dark","labels":["triage:ready-for-agent"]},
  {"key":"t2","title":"Theme toggle persists","type":"task","parent_id":"$BUILD","description":"toggle","acceptance_criteria":"- toggle persists across reload","labels":["triage:ready-for-agent","bout"],"deps":[{"type":"blocks","target":"t1"}]}
 ]}
EOF
IDS=$($BD create --graph plan.json --json); T1=$(echo "$IDS" | jq -r .ids.t1); T2=$(echo "$IDS" | jq -r .ids.t2)
SW=$($BD swarm validate "$BUILD" 2>&1 || true)
check "swarm validate sees the tickets as waves" "$SW" "Theme toggle persists"
$BD close "$SLICE" --reason "sliced" >/dev/null
refute "tickets not ready before breakdown approval" "$(ready_titles)" "Theme tokens"
$BD gate resolve "$SLSIGN" --reason "breakdown ok" >/dev/null
check "first ticket ready after approval" "$(ready_titles)" "Theme tokens end to end"
refute "second ticket still blocked" "$(ready_titles)" "Theme toggle persists"

# build cannot close with open tickets
if $BD close "$BUILD" --reason x >/dev/null 2>&1; then echo "FAIL build closed with open children"; else echo "PASS build refuses to close while tickets open"; fi

# round wisp for T1
W=$($BD mol wisp arena-round --var ticket="$T1" --var slug=theme-tokens --json | jq -r '.root_id // .new_epic_id // .id // empty')
[ -z "$W" ] && W=$($BD mol wisp list --json | jq -r '.[-1].id // .[-1].root_id // empty')
wstep() { $BD list --all --include-ephemeral --limit 0 --json | jq -r --arg r "$W" --arg t "$1" '.[] | select(.parent==$r and (.title|test($t))) | .id' | head -1; }
check "round starts at brief" "$($BD ready --mol "$W" --json | jq -r '.. | strings' | tr '\n' ' ')" "$(wstep '^Brief')"
for t in '^Brief' '^Red' '^Green' '^Prove'; do $BD close "$(wstep "$t")" --reason ok >/dev/null; done
LENSES=$($BD mol current "$W" 2>&1 | grep -c "\[ready\] .*Lens" || true)
check "three lenses ready in parallel" "$LENSES" "3"
for t in '^Lens Standards' '^Lens Spec' '^Lens Doubt'; do $BD close "$(wstep "$t")" --reason ok >/dev/null; done
LAND=$(wstep '^Land')
$BD gate create --type=gh:pr --await-id 12 --blocks "$LAND" --title "PR #12 merged" >/dev/null
$BD update "$T1" --claim >/dev/null; $BD update "$T1" --status in_review --external-ref gh-12 >/dev/null
for t in '^Open the PR' '^Get CI' '^Answer every'; do $BD close "$(wstep "$t")" --reason ok >/dev/null; done
check "land blocked by gh:pr gate (bd blocked)" "$($BD blocked --json | jq -r '.[]?.id' | tr '\n' ' ')" "$LAND"
refute "land absent from ready queue" "$($BD ready --include-ephemeral --json | jq -r '.[]?.id' | tr '\n' ' ')" "$LAND"
$BD gate resolve "$($BD gate list --json | jq -r '.[] | select(.title=="PR #12 merged") | .id')" --reason "merged (simulated)" >/dev/null
check "land ready after merge gate" "$($BD ready --include-ephemeral --json | jq -r '.[]?.id' | tr '\n' ' ')" "$LAND"
check "patrol finds the merged round by label" "$($BD ready --include-ephemeral --label round:land --json | jq -r '.[]?.id' | tr '\n' ' ')" "$LAND"
$BD close "$(wstep '^Land')" --reason ok >/dev/null
$BD close "$T1" --reason "merged PR #12" >/dev/null
check "T2 ready after T1 merged" "$(ready_titles)" "Theme toggle persists"
if $BD mol squash "$W" >/dev/null 2>&1; then echo "PASS wisp squashed into digest"; else echo "FAIL squash"; fails=$((fails+1)); fi

# bout spawner for T2
B=$($BD mol wisp arena-bout --var ticket="$T2" --json | jq -r '.root_id // .new_epic_id // .id // empty')
[ -z "$B" ] && B=$($BD mol wisp list --json | jq -r '.[-1].id // empty')
bstep() { $BD list --all --include-ephemeral --limit 0 --json | jq -r --arg r "$B" --arg t "$1" '.[] | select(.parent==$r and (.title|test($t))) | .id' | head -1; }
$BD close "$(bstep '^Frame')" --reason ok >/dev/null
CAND=$(bstep '^Candidates')
for n in 1 2 3; do $BD create "Candidate $n for $T2" -d "direction $n" --acceptance "- artifact" --parent "$CAND" --labels bout:candidate --silent >/dev/null; done
check "judge waits for candidates" "$($BD mol current "$B" 2>&1 | grep Cross-judge)" "pending"
for id in $($BD children "$CAND" --json | jq -r '.[].id'); do $BD close "$id" --reason ok >/dev/null; done
$BD close "$CAND" --reason "3 candidates done" >/dev/null
check "judge ready after all candidates" "$($BD mol current "$B" 2>&1 | grep Cross-judge)" "ready"
$BD mol burn "$B" --force >/dev/null 2>&1 || $BD mol burn "$B" >/dev/null 2>&1 || true

# strict mode accepts the decision and spike commands the skills give
DEC=$($BD create "Decision: toggle shape" -t decision --deps discovered-from:"$T2" --acceptance "- verdict recorded" --silent --body-file - <<'BODY'
## Decision
Base c2, graft c1 persistence adapter.
## Rationale
Smallest API.
## Alternatives Considered
c1 and c3 lost on the rubric.
BODY
) && check "strict mode accepts the decision command" "$DEC" "ar-" || { echo "FAIL decision command refused"; fails=$((fails+1)); }
SPK=$($BD create "Spike: which storage" -t spike --parent "$R" --acceptance "- answer recorded" -d $'## Goal\nPick storage\n## Findings\npending' --silent) \
  && check "strict mode accepts the spike command" "$SPK" "ar-" || { echo "FAIL spike command refused"; fails=$((fails+1)); }
$BD close "$SPK" --reason "answered" >/dev/null

# a ticket created with --parent on the build step gets a dotted id and still counts as a ticket
T3=$($BD create "Theme in emails" -t task -d "email theme" --acceptance "- emails follow theme" --parent "$BUILD" --no-inherit-labels --silent)
refute "--no-inherit-labels keeps spawner labels off the ticket" "$($BD show "$T3" --json | jq -r '.[0].labels // [] | join(",")')" "arena:spawner"
check "ticket under the build step has a dotted id" "$T3" "$BUILD."
$BD update "$T3" --claim >/dev/null; $BD close "$T3" --reason "merged PR #14" >/dev/null
$BD update "$T2" --remove-label bout >/dev/null; $BD update "$T2" --claim >/dev/null; $BD close "$T2" --reason "merged PR #13" >/dev/null

# patrol closes the build step once its last ticket landed, and the season moves on
if $BD close "$BUILD" --reason "all children closed" >/dev/null 2>&1; then echo "PASS build step closes after the last ticket"; else echo "FAIL build step did not close"; fails=$((fails+1)); fi
check "integrate ready after build" "$(ready_titles)" "Integrate dark-mode"

# patrol
P=$($BD mol wisp arena-patrol --json | jq -r '.root_id // .new_epic_id // .id // empty')
[ -z "$P" ] && P=$($BD mol wisp list --json | jq -r '.[-1].id // empty')
check "five patrol sweeps run in parallel" "$($BD mol current "$P" 2>&1 | grep -c '\[ready\]' || true)" "5"

# timer gate created at ship time
TG=$($BD gate create --type=timer --timeout 72h --blocks "$BAKE" --title "Bake dark-mode 72h" --json | jq -r .id)
check "timer gate armed with 72h" "$($BD show "$TG" --json | jq -r '.[0].timeout // .timeout')" "259200000000000"
# vitals computed from what this walk produced
L=$($BD create "Learning: lint rule for X" -t chore -l learning,learning:structural -d "evidence" --acceptance "- rule exists" --deps discovered-from:"$T1" --silent)
$BD close "$L" --reason "rule merged" >/dev/null
V=$(BD="$BD" PATH="$(dirname "$(command -v "$BD")"):$PATH" "$PLUGIN/bin/arena-vitals" --json)
val() { jq -r --arg k "$1" '.metrics[] | select(.key==$k) | .hours.n' <<<"$V"; }
check "vitals: season time-to-ready measured" "$(val time_to_ready_season)" "1"
check "vitals: intent-to-merge counts dotted tickets too" "$(val intent_to_merge)" "3"
check "vitals: review latency measured" "$(val review_latency)" "1"
check "vitals: human wait over both resolved gates" "$(val human_wait)" "2"
check "vitals: learning velocity measured" "$(val learning_velocity)" "1"
check "vitals: structural share" "$(jq -r '.learning.structuralShare' <<<"$V")" "1"
check "vitals: oneline renders" "$(PATH="$(dirname "$(command -v "$BD")"):$PATH" "$PLUGIN/bin/arena-vitals" --oneline)" "arena 30d | pit"

echo "---"; if [ "$fails" -eq 0 ]; then echo "all checks passed"; else echo "$fails check(s) failed"; exit 1; fi
