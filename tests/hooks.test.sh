#!/usr/bin/env bash
# Feeds real PreToolUse / SessionStart / Stop payloads to the arena hooks and checks each decision.
# Usage: tests/hooks.test.sh   (needs bd, jq, git on PATH)
set -uo pipefail

PLUGIN="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
H="$PLUGIN/hooks"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
pass=0; fail=0

arena="$WORK/arena"; plain="$WORK/plain"
mkdir -p "$arena" "$plain"
git -C "$arena" init -q; git -C "$plain" init -q
(cd "$arena" && bd init --quiet --prefix tt >/dev/null 2>&1)

bash_payload() { jq -n --arg c "$1" --arg d "$2" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d, hook_event_name: "PreToolUse"}'; }
edit_payload() { jq -n --arg f "$1" --arg o "$2" --arg n "$3" --arg d "$4" '{tool_name: "Edit", tool_input: {file_path: $f, old_string: $o, new_string: $n}, cwd: $d, hook_event_name: "PreToolUse"}'; }
write_payload() { jq -n --arg f "$1" --arg c "$2" --arg d "$3" '{tool_name: "Write", tool_input: {file_path: $f, content: $c}, cwd: $d, hook_event_name: "PreToolUse"}'; }

decision() { jq -r '.hookSpecificOutput.permissionDecision // "allow"' 2>/dev/null <<<"$1" || echo allow; }

expect() { # expect <name> <want> <hook> <payload>
  local out got; out="$("$H/$3" <<<"$4")"; got="$(decision "${out:-{\}}")"
  [ -z "$out" ] && got="allow"
  if [ "$got" = "$2" ]; then pass=$((pass+1)); echo "PASS $1"; else fail=$((fail+1)); echo "FAIL $1: want $2, got $got :: $out"; fi
}

# guard-bash
expect "commit without Refs is denied"        deny  guard-bash.sh "$(bash_payload 'git commit -m "feat: add toggle"' "$arena")"
expect "commit with Refs is allowed"          allow guard-bash.sh "$(bash_payload $'git commit -m "feat: add toggle" -m "Refs: tt-a1b"' "$arena")"
expect "heredoc commit with Refs is allowed"  allow guard-bash.sh "$(bash_payload $'git commit -F - <<EOF\nfeat: x\n\nRefs: tt-a1b\nEOF' "$arena")"
printf 'feat: y\n\nRefs: tt-9zz\n' > "$arena/msg.txt"
expect "commit -F file with Refs is allowed"  allow guard-bash.sh "$(bash_payload "git commit -F $arena/msg.txt" "$arena")"
expect "merge commit --no-edit is allowed"    allow guard-bash.sh "$(bash_payload 'git commit --no-edit' "$arena")"
expect "commit outside an arena is ignored"   allow guard-bash.sh "$(bash_payload 'git commit -m "wip"' "$plain")"
expect "bd edit is denied"                    deny  guard-bash.sh "$(bash_payload 'bd edit tt-a1b' "$arena")"
expect "forcing a claim is denied"            deny  guard-bash.sh "$(bash_payload 'bd update tt-a1b --claim --force' "$arena")"
expect "plain force push is denied"           deny  guard-bash.sh "$(bash_payload 'git push --force origin arena/tt-a1b-x' "$arena")"
expect "force-with-lease is allowed"          allow guard-bash.sh "$(bash_payload 'git push --force-with-lease origin arena/tt-a1b-x' "$arena")"
expect "push to main asks"                    ask   guard-bash.sh "$(bash_payload 'git push origin main' "$arena")"
expect "gh pr merge asks"                     ask   guard-bash.sh "$(bash_payload 'gh pr merge 12 --squash' "$arena")"
expect "terraform apply asks"                 ask   guard-bash.sh "$(bash_payload 'cd infra && terraform apply -auto-approve' "$arena")"
expect "terraform plan is allowed"            allow guard-bash.sh "$(bash_payload 'terraform plan -out tf.plan' "$arena")"
expect "cdk deploy asks"                      ask   guard-bash.sh "$(bash_payload 'npx cdk deploy MyStack' "$arena")"
expect "aws s3 rm --recursive asks"           ask   guard-bash.sh "$(bash_payload 'aws s3 rm s3://bucket/prefix --recursive' "$arena")"
expect "git reset --hard asks"                ask   guard-bash.sh "$(bash_payload 'git reset --hard HEAD~1' "$arena")"
expect "bd ready is allowed"                  allow guard-bash.sh "$(bash_payload 'bd ready --json' "$arena")"
expect "bd gate resolve asks the human"       ask   guard-bash.sh "$(bash_payload 'bd gate resolve ar-mol-x1 --reason ok' "$arena")"
expect "bd gate check is allowed"             allow guard-bash.sh "$(bash_payload 'bd gate check' "$arena")"
expect "merge through gh api asks"            ask   guard-bash.sh "$(bash_payload 'gh api -X PUT repos/o/r/pulls/12/merge' "$arena")"
expect "refspec push to main asks"            ask   guard-bash.sh "$(bash_payload 'git push origin HEAD:refs/heads/main' "$arena")"
expect "+refspec force push is denied"        deny  guard-bash.sh "$(bash_payload 'git push origin +arena/tt-a1b-x' "$arena")"
expect "push of an arena branch is allowed"   allow guard-bash.sh "$(bash_payload 'git push -u origin arena/tt-a1b-main-menu' "$arena")"
expect "npm run deploy asks"                  ask   guard-bash.sh "$(bash_payload 'npm run deploy' "$arena")"
expect "gh workflow run asks"                 ask   guard-bash.sh "$(bash_payload 'gh workflow run release.yml' "$arena")"
expect "vercel --prod asks"                   ask   guard-bash.sh "$(bash_payload 'vercel deploy --prod' "$arena")"
expect "helm upgrade asks"                    ask   guard-bash.sh "$(bash_payload 'helm upgrade api ./chart' "$arena")"
expect "kubectl apply asks"                   ask   guard-bash.sh "$(bash_payload 'kubectl apply -f k8s/' "$arena")"
expect "npm test is allowed"                  allow guard-bash.sh "$(bash_payload 'npm test -- --run' "$arena")"

# guard-floor
expect "adding @ts-ignore is denied"          deny  guard-floor.sh "$(edit_payload "$arena/src/a.ts" 'const x = f(y)' $'// @ts-ignore\nconst x = f(y)' "$arena")"
expect "@ts-ignore with arena-allow passes"   allow guard-floor.sh "$(edit_payload "$arena/src/a.ts" 'const x = f(y)' $'// @ts-ignore arena-allow: upstream types wrong, see tt-b2c\nconst x = f(y)' "$arena")"
expect "removing an existing suppression"     allow guard-floor.sh "$(edit_payload "$arena/src/a.ts" $'// eslint-disable-next-line\nfoo()' 'foo()' "$arena")"
expect "it.skip is denied"                    deny  guard-floor.sh "$(edit_payload "$arena/src/a.test.ts" "it('works', () => {" "it.skip('works', () => {" "$arena")"
expect "focused test is denied"               deny  guard-floor.sh "$(edit_payload "$arena/src/a.test.ts" "describe('x', () => {" "describe.only('x', () => {" "$arena")"
expect "not-implemented stub is denied"       deny  guard-floor.sh "$(write_payload "$arena/src/b.ts" $'export const f = () => {\n  throw new Error("not implemented")\n}' "$arena")"
expect "markdown may mention patterns"        allow guard-floor.sh "$(write_payload "$arena/docs/x.md" 'Never use @ts-ignore.' "$arena")"
expect "floor outside an arena is ignored"    allow guard-floor.sh "$(edit_payload "$plain/a.ts" 'a' $'// @ts-ignore\na' "$plain")"
expect "clean edit is allowed"                allow guard-floor.sh "$(edit_payload "$arena/src/a.ts" 'const a = 1' 'const a = 2' "$arena")"

# session-start
ss() { jq -n --arg d "$arena" '{cwd: $d, source: "startup", hook_event_name: "SessionStart"}' | "$H/session-start.sh" | jq -r '.hookSpecificOutput.additionalContext'; }
if grep -qs 'bd prime' "$arena/.claude/settings.json"; then
  ctx="$(ss)"
  if [[ "$ctx" == "# Arena"* && "$ctx" != *"Beads Workflow Context"* ]]; then pass=$((pass+1)); echo "PASS session-start adds only the brief when Beads' own hook runs bd prime"; else fail=$((fail+1)); echo "FAIL session-start duplicated bd prime: ${ctx:0:200}"; fi
  mv "$arena/.claude/settings.json" "$arena/.claude/settings.json.bak"
fi
ctx="$(ss)"
if [[ "$ctx" == "# Arena"* && "$ctx" == *"Beads Workflow Context"* && ${#ctx} -le 10000 ]]; then pass=$((pass+1)); echo "PASS session-start injects brief first, then bd prime, when no Beads hook exists (${#ctx} chars)"; else fail=$((fail+1)); echo "FAIL session-start: ${ctx:0:200}"; fi
out="$(jq -n --arg d "$plain" '{cwd: $d, source: "startup"}' | "$H/session-start.sh")"
if [ -z "$out" ]; then pass=$((pass+1)); echo "PASS session-start silent outside an arena"; else fail=$((fail+1)); echo "FAIL session-start not silent outside an arena"; fi

# stop-landing
(cd "$arena" && id=$(bd create "pit item" -d x --acceptance "- y" --silent) && bd set-state "$id" triage=ready-for-human --reason "merge PR" >/dev/null 2>&1)
out="$(jq -n --arg d "$arena" '{cwd: $d, stop_hook_active: false}' | "$H/stop-landing.sh")"
if [[ "$(jq -r '.systemMessage // empty' <<<"$out")" == *"pit: 1"* ]]; then pass=$((pass+1)); echo "PASS stop hook surfaces the pit"; else fail=$((fail+1)); echo "FAIL stop hook: $out"; fi
out="$(jq -n --arg d "$arena" '{cwd: $d, stop_hook_active: true}' | "$H/stop-landing.sh")"
if [ -z "$out" ]; then pass=$((pass+1)); echo "PASS stop hook stays quiet when already continuing"; else fail=$((fail+1)); echo "FAIL stop hook loop guard"; fi

echo "---"; echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
