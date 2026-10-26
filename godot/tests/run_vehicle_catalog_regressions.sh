#!/usr/bin/env bash
set -u

project_root="${1:?project root}"
log_dir="${2:?log directory}"
mkdir -p "$log_dir"
failures=0
tests=(
  vehicle_catalog_cache_smoke
  profile_recovery_smoke
  garage_loadout_smoke
  garage_smoke
  pre_race_smoke
  career_gameplay_smoke
  race_finish_smoke
  controls_smoke
  survival_smoke
  survival_boss_schedule_smoke
  survival_biker_crew_smoke
  survival_roguelite_smoke
  survival_round_guard_smoke
  survival_restart_smoke
  survival_reward_feedback_smoke
  tactical_arsenal_smoke
  release_v1_smoke
  release_candidate_smoke
)

for name in "${tests[@]}"; do
  timeout 120s flatpak run --filesystem="$project_root" org.godotengine.Godot \
    --headless --path "$project_root" --script "res://tests/${name}.gd" \
    > "$log_dir/$name.log" 2>&1
  code=$?
  if (( code == 0 )) && ! rg -q 'SCRIPT ERROR|Parse Error|: FAIL| FAIL:' "$log_dir/$name.log"; then
    printf 'PASS %s\n' "$name"
  else
    printf 'FAIL %s exit=%d\n' "$name" "$code"
    failures=$((failures + 1))
  fi
done
printf 'REGRESSION_RESULT failures=%d total=%d\n' "$failures" "${#tests[@]}"
exit "$((failures != 0))"
