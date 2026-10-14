#!/usr/bin/env bash
# tests/bats/fixtures/claude_plugin_structure.sh
# Thin adapter over the SHIPPED engines, so the bats suite pins their real
# behavior instead of a hand-written mirror:
#   skills/structure-check/lib/structure_check.sh     (M1-M11 / R1,R2,R4-R8,R10,R11)
#   skills/structure-refactor/lib/refactor_apply.sh   (dry-run / --apply fixes)
# Spec: skills/structure-check/references/structure-spec.md and
#       skills/structure-refactor/references/plan-and-report-templates.md
# R3 ("README is Simple") is a model judgment in the spec; the shipped
# checker does not score it, so it has no adapter here.
# Requires REPO_ROOT (tests/bats/test_helper.bash).

_CPS_CHECK="$REPO_ROOT/skills/structure-check/lib/structure_check.sh"
_CPS_APPLY="$REPO_ROOT/skills/structure-refactor/lib/refactor_apply.sh"

# _cps_field <repo> <ID> [single|mono] -> the status token of that output line
# (PASS|WARN|FAIL|N/A for checks, the mode for MODE, the verdict for SUMMARY).
_cps_field() {
    bash "$_CPS_CHECK" "$1" ${3:+"--$3"} 2>/dev/null |
        awk -v id="$2" '$1 == id { print $2; exit }'
}

# cps_check <ID> <repo> [single|mono]
cps_check() { _cps_field "$2" "$1" "${3:-}"; }

# cps_mode <repo> [single|mono] -> single|mono
cps_mode() { _cps_field "$1" MODE "${2:-}"; }

# cps_verdict <repo> [single|mono] -> PASS|WARN|FAIL (over the scripted checks)
cps_verdict() { _cps_field "$1" SUMMARY "${2:-}"; }

# cps_refactor <repo> <mp|op> <dry-run|apply> [single|mono]
# Target mode defaults to the detected one, as SKILL.md does.
cps_refactor() {
    local _mode="${4:-$(cps_mode "$1")}" _apply=""
    [ "${3:-}" = apply ] && _apply=--apply
    bash "$_CPS_APPLY" "$1" --mode "$_mode" --scope "${2:-mp}" $_apply >/dev/null 2>&1
}
