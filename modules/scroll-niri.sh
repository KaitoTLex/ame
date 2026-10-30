# The niri actions scroll has no single command for. Bound in modules/scroll.nix.

# focused workspace's number, plus this output's workspace numbers in order
load_workspaces() {
  local ws output
  ws=$(scrollmsg -t get_workspaces)
  current=$(jq '.[] | select(.focused).num' <<<"$ws")
  output=$(jq -r '.[] | select(.focused).output' <<<"$ws")
  mapfile -t numbers < <(jq --arg o "$output" '[.[] | select(.output == $o).num] | sort | .[]' <<<"$ws")
  highest=$(jq '[.[].num] | max' <<<"$ws")
  all=$(jq '[.[].num] | sort | reverse | .[]' <<<"$ws")
}

current_is_empty() {
  scrollmsg -t get_tree | jq -e --argjson n "$current" \
    '.. | objects | select(.type? == "workspace" and .num == $n) | (.nodes + .floating_nodes | length) == 0' >/dev/null
}

# niri keeps an empty workspace above the first one. scroll numbers them, so
# make room below the lowest number when there isn't any left.
workspace_above_first() {
  local first=${numbers[0]} n
  if ((first > 1)) && ! grep -qx "$((first - 1))" <<<"$all"; then
    echo "$((first - 1))"
    return
  fi
  for n in $all; do
    ((n >= first)) && scrollmsg "rename workspace number $n to $((n + 1))" >/dev/null
  done
  echo "$first"
}

# Prints the workspace `up` or `down` lands on, nothing if we're already there.
# Unlike prev/next_on_output this never wraps, same as niri.
workspace_target() {
  local i last=$((${#numbers[@]} - 1))
  for i in "${!numbers[@]}"; do
    [[ ${numbers[i]} == "$current" ]] || continue
    if [[ $1 == up ]]; then
      if ((i > 0)); then
        echo "${numbers[i - 1]}"
      elif ! current_is_empty; then
        workspace_above_first
      fi
    elif ((i < last)); then
      echo "${numbers[i + 1]}"
    elif ! current_is_empty; then
      echo "$((highest + 1))"
    fi
  done
}

# The column holding the focused window. Empty when it's floating.
focused_column() {
  scrollmsg -t get_tree | jq -c 'first(.. | objects | select((.nodes? // []) | any(.focused)))'
}

# scroll keeps every window in a column at full height and scrolls between
# them. niri shares the height out, so refit after anything changes a column.
consume_or_expel() {
  local column self others
  column=$(focused_column)
  [[ -n $column ]] || return 0
  self=$(jq '.nodes[] | select(.focused).id' <<<"$column")
  others=$(jq 'first(.nodes[] | select(.focused | not).id) // empty' <<<"$column")
  scrollmsg "move $1 nomode; fit_size v all equal" >/dev/null
  # expelled from a column: the windows left behind get the space back too
  if [[ -n $others ]]; then
    scrollmsg "[con_id=$others] focus; fit_size v all equal; [con_id=$self] focus" >/dev/null
  fi
}

expel() {
  local column
  column=$(focused_column)
  [[ -n $column ]] || return 0
  # alone in its column, so there's nothing to expel it from
  (($(jq '.nodes | length' <<<"$column") > 1)) || return 0
  consume_or_expel right
}

# toggle_size sets both axes, and niri's maximize-column only touches the width
maximize_column() {
  local heights
  heights=$(scrollmsg -t get_tree | jq -r '
    first(.. | objects | select(.type? == "workspace" and any(.. | objects; .focused? == true))) as $ws
    | first($ws | .. | objects | select(.focused? == true)) as $win
    | "\($win.rect.height) \($ws.rect.height)"')
  scrollmsg "toggle_size this 1.0 $(awk -v h="$heights" 'BEGIN { split(h, a, " "); printf "%.5f", a[1] / a[2] }')" >/dev/null
}

case "${1:-}-${2:-}" in
  workspace-up | workspace-down)
    load_workspaces
    target=$(workspace_target "$2")
    [[ -n $target ]] && scrollmsg "workspace number $target" >/dev/null
    ;;
  move-up | move-down)
    load_workspaces
    target=$(workspace_target "$2")
    [[ -n $target ]] && scrollmsg "move container to workspace number $target; workspace number $target" >/dev/null
    ;;
  swap-up | swap-down)
    # swap leaves focus on the slot; niri's move-workspace follows the workspace
    load_workspaces
    for i in "${!numbers[@]}"; do
      [[ ${numbers[i]} == "$current" ]] || continue
      if [[ $2 == up ]]; then
        ((i > 0)) && scrollmsg "workspace swap number ${numbers[i - 1]}; workspace number ${numbers[i - 1]}" >/dev/null
      else
        ((i < ${#numbers[@]} - 1)) && scrollmsg "workspace swap number ${numbers[i + 1]}; workspace number ${numbers[i + 1]}" >/dev/null
      fi
    done
    ;;
  consume-left | consume-right) consume_or_expel "$2" ;;
  expel-) expel ;;
  maximize-column-) maximize_column ;;
  *)
    echo "usage: scroll-niri workspace|move|swap up|down, consume left|right, expel, maximize-column" >&2
    exit 1
    ;;
esac
exit 0
