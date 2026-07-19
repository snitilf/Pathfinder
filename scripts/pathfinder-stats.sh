#!/usr/bin/env sh
# summarize pathfinder jsonl logs if present. missing logs are a normal state.
#
# empty-vs-null agent_type: on SubagentStop the hook writes agent_type as an
# empty string (never null) when it could not attribute the run; SessionEnd and
# other events carry null. jq's // does not catch empty string ("" // "x" is ""),
# so we key the unattributed bucket on empty-string agent_type among SubagentStop
# events and report it explicitly. null agent_type is only surfaced by the
# existing by_agent_type block. this representation is applied consistently below.
#
# schema detection uses has("models"), not .models == null: a v1.2.0 line whose
# transcript was missing also has models == null, so null would misreport fresh
# data as legacy. three buckets: v1 (no models key), v2 models null, v2 present.
#
# no prices here on purpose. tokens are reported by (agent_type x model); dollars
# are a human step so there is no rate to drift. see docs if a cost number is wanted.

set -eu

LOG_ROOT="${PATHFINDER_LOG_DIR:-$HOME/.claude/pathfinder/logs}"
AGENTS_DIR="${PATHFINDER_AGENTS_DIR:-$HOME/.claude/agents}"
PINNED_ROLES="scout Explore mech-executor executor verifier light-verifier security-executor"

if [ ! -d "$LOG_ROOT" ]; then
  echo "no pathfinder logs directory at $LOG_ROOT (normal if hooks are not installed)"
  exit 0
fi

# shellcheck disable=SC2012
FILES="$(ls -1 "$LOG_ROOT"/*.jsonl 2>/dev/null || true)"
if [ -z "$FILES" ]; then
  echo "no jsonl logs under $LOG_ROOT (normal if no hook events yet)"
  exit 0
fi

echo "pathfinder log summary ($LOG_ROOT)"
echo "---"

if ! command -v jq >/dev/null 2>&1; then
  TOTAL="$(cat "$LOG_ROOT"/*.jsonl 2>/dev/null | wc -l | tr -d ' ')"
  echo "total_lines: $TOTAL"
  echo "(install jq for breakdown by event, agent_type, routing, and pin compliance)"
  exit 0
fi

# counts by event and agent_type across all days (unchanged output).
# fromjson? drops malformed/truncated lines so one bad line does not abort the
# summary or the sections below; well-formed lines produce identical output.
cat "$LOG_ROOT"/*.jsonl 2>/dev/null | jq -R 'fromjson?' 2>/dev/null | jq -s '
  "total_lines: \(length)",
  "by_event:",
  (group_by(.event) | map({(.[0].event // "null"): length}) | add // {}),
  "by_agent_type:",
  (group_by(.agent_type) | map({(.[0].agent_type // "null"): length}) | add // {})
' 2>/dev/null || {
  TOTAL="$(cat "$LOG_ROOT"/*.jsonl 2>/dev/null | wc -l | tr -d ' ')"
  echo "total_lines: $TOTAL (jq parse failed; raw line count only)"
}

# read the pin for each role from installed agent frontmatter (real source of
# truth, not a hardcoded copy). adapted from pathfinder-diag.sh frontmatter idiom
# to parse model: instead of name:. read-only.
PINFILE=""
cleanup() { [ -n "$PINFILE" ] && rm -f "$PINFILE" 2>/dev/null || true; }
trap cleanup EXIT
PINFILE="$(mktemp 2>/dev/null || true)"
if [ -n "$PINFILE" ]; then
  for r in $PINNED_ROLES; do
    f="$AGENTS_DIR/$r.md"
    a=""
    if [ -f "$f" ]; then
      a="$(awk 'NR==1{if($0!="---")exit} NR>1&&/^---/{exit} NR>1&&/^model:[ \t]*/{sub(/^model:[ \t]*/,"");sub(/[ \t]*$/,"");print;exit}' "$f" 2>/dev/null || true)"
    fi
    printf '%s\t%s\n' "$r" "$a" >> "$PINFILE" 2>/dev/null || true
  done
fi
[ -n "$PINFILE" ] && [ -f "$PINFILE" ] || PINFILE=/dev/null

# stream SubagentStop lines as tsv: bucket, agent_type, model-set, tokens.
# fromjson? tolerates malformed/truncated lines without halting. keyed by the
# joined model set so multi-model runs are one row and tokens are never split.
cat "$LOG_ROOT"/*.jsonl 2>/dev/null \
| jq -rR 'fromjson?
    | select(.event=="SubagentStop")
    | (if has("models") then (if .models==null then "v2null" else "v2present" end) else "v1" end) as $b
    | [ $b,
        (.agent_type // ""),
        (if $b=="v2present" then (.models|join("+")) else "-" end),
        (.output_tokens // 0),(.input_tokens // 0),
        (.cache_read_tokens // 0),(.cache_creation_tokens // 0)
      ] | @tsv' 2>/dev/null \
| awk -F'\t' -v PF="$PINFILE" '
  function fam_of_model(model,   m) {
    m = model
    sub(/\[1m\]$/, "", m)   # main-session model may appear as opus[1m]
    if (index(m,"claude-haiku-")==1  || m=="claude-haiku")  return "haiku"
    if (index(m,"claude-sonnet-")==1 || m=="claude-sonnet") return "sonnet"
    if (index(m,"claude-opus-")==1   || m=="claude-opus")   return "opus"
    if (index(m,"claude-fable-")==1  || m=="claude-fable")  return "fable"
    return "?"
  }
  # first file: role \t alias pins
  FILENAME==PF && PF!="/dev/null" {
    porder[++np]=$1; pin[$1]=$2; isrole[$1]=1
    pinknown[$1]=($2=="haiku"||$2=="sonnet"||$2=="opus"||$2=="fable")
    next
  }
  {
    bucket=$1; at=$2; mset=$3
    stop_total++
    bcount[bucket]++
    if (at=="") { unattr++; next }   # unattributed: no agent_type, cannot attribute to a role
    if (!(at in atseen)) { atseen[at]=1; atorder[++nat]=at }
    atcount[at]++
    if (bucket=="v2present") {
      atmodel[at]++
      key=at SUBSEP mset
      if (!(key in rcount)) { rkeyat[key]=at; rkeymset[key]=mset }
      rcount[key]++
      rout[key]+=$4; rin[key]+=$5; rcread[key]+=$6; rccreate[key]+=$7
      n=split(mset, arr, "+")
      matchall=1
      for (i=1;i<=n;i++) {
        mm=arr[i]
        gm[at SUBSEP mm]++
        if (isrole[at] && pinknown[at] && fam_of_model(mm)!=pin[at]) matchall=0
      }
      if (isrole[at]) {
        if (pinknown[at]) { if (matchall) comp[at]++; else offc[at]++ }
        else unkpin[at]++
      }
    } else {
      atnomodel[at]++
    }
  }
  END {
    b1 = (("v1" in bcount) ? bcount["v1"] : 0)
    b2n = (("v2null" in bcount) ? bcount["v2null"] : 0)
    b2p = (("v2present" in bcount) ? bcount["v2present"] : 0)
    st = stop_total + 0
    ua = unattr + 0

    printf "\n"
    print "schema buckets (SubagentStop = " st "):"
    printf "  schema v1 (pre-v1.2.0, no model data ever captured): %d (%s%%)\n", b1, pct(b1, st)
    printf "  schema v2, models null (v1.2.0, no transcript available): %d (%s%%)\n", b2n, pct(b2n, st)
    printf "  schema v2, models present (real data): %d (%s%%)\n", b2p, pct(b2p, st)

    printf "\n"
    print "unattributed: no agent_type from the hook, no transcript"
    printf "  %d of %d SubagentStop (%s%%)\n", ua, st, pct(ua, st)
    print "  these carry an empty-string agent_type; they cannot be attributed to any"
    print "  role and are excluded from the per-role compliance denominators below,"
    print "  reported here so the denominator is never silently shrunk."

    printf "\n"
    print "routing table (agent_type x models, SubagentStop with model data):"
    if (b2p == 0) {
      print "  (no schema-v2 lines with model data yet; run under v1.2.0 to populate)"
    } else {
      for (t=1;t<=nat;t++) {
        a=atorder[t]
        printed=0
        for (k in rcount) {
          if (rkeyat[k] != a) continue
          if (!printed) { printf "  %s%s:\n", a, (isrole[a]?"":" (unpinned)"); printed=1 }
          printf "    %-28s calls=%d out=%d in=%d cache_read=%d cache_creation=%d\n", \
                 rkeymset[k], rcount[k], rout[k], rin[k], rcread[k], rccreate[k]
        }
        nm=(a in atnomodel)?atnomodel[a]:0
        if (printed && nm>0) printf "    (no model data: %d lines)\n", nm
      }
    }

    printf "\n"
    print "pin compliance (observed model vs frontmatter pin; alias-to-family by prefix):"
    if (np == 0) {
      print "  (agent frontmatter not readable at " PF "; cannot check pins)"
    } else {
      for (p=1;p<=np;p++) {
        r=porder[p]
        tot=(r in atcount)?atcount[r]:0
        wm=(r in atmodel)?atmodel[r]:0
        nm=(r in atnomodel)?atnomodel[r]:0
        c=(r in comp)?comp[r]:0
        o=(r in offc)?offc[r]:0
        if (!pinknown[r]) {
          if (pin[r]=="")
            printf "  %-18s pin=(none read) - reporting only, no compliance computed\n", r
          else
            printf "  %-18s pin=%s (alias not recognized) - reporting only, no compliance computed\n", r, pin[r]
          printf "                     calls=%d, with model data=%d, no model data=%d\n", tot, wm, nm
          print_models(r)
          continue
        }
        printf "  %-18s pin=%s\n", r, pin[r]
        if (c+o==0) {
          printf "                     calls=%d, no model data=%d - no compliance sample yet\n", tot, nm
        } else {
          printf "                     compliant=%d / %d with model data (%s%%), off-pin=%d\n", c, c+o, pct(c, c+o), o
          printf "                     (also: %d calls with no model data, not counted; total calls=%d)\n", nm, tot
        }
        print_models(r)
      }
      print "  note: unattributed stops (above) have no agent_type and are in no"
      print "  role denominator here. compliance is over lines carrying model data only."
    }

    printf "\n"
    print "ungoverned delegation (types with no pinned model):"
    any=0
    for (t=1;t<=nat;t++) {
      a=atorder[t]
      if (isrole[a]) continue
      any=1
      printf "  %s: calls=%d\n", a, atcount[a]
      print_models(a)
      nm=(a in atnomodel)?atnomodel[a]:0
      if (nm>0) printf "    (no model data: %d lines)\n", nm
    }
    if (!any) print "  (none observed)"
    print "  report only, not an accusation: these types have no pinned model. whether"
    print "  a model was set explicitly or inherited from the calling session is not"
    print "  distinguishable from telemetry (the log records no session model), so no"
    print "  inheritance judgement is made here."
  }
  function pct(x, d) { return (d>0) ? sprintf("%.1f", 100*x/d) : "0.0" }
  function print_models(a,   k, parts, mm) {
    for (k in gm) {
      split(k, parts, SUBSEP)
      if (parts[1] != a) continue
      mm=parts[2]
      printf "                     observed %-26s x%d%s\n", mm, gm[k], \
             (isrole[a] && pinknown[a] ? (fam_of_model(mm)==pin[a] ? " (matches pin)" : " (OFF-PIN)") : "")
    }
  }
' "$PINFILE" - || true

exit 0
