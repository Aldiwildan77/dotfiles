add_to_env() {
  local varname="$1"
  local new_value="$2"
  local current_value="${(P)varname}"

  # Check if the new_value is already present by surrounding the list with commas.
  if [[ ",${current_value}," != *",$new_value,"* ]]; then
    if [[ -z "$current_value" ]]; then
      export $varname="$new_value"
    else
      export $varname="${current_value},${new_value}"
    fi
  fi
}
