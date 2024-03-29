#!/bin/bash

parent=$(/bin/ps -o ppid -p $PPID | tail -1)
if [[ -n "$parent" ]]; then
  # shellcheck disable=SC2086
  amended=$(/bin/ps -o command -p ${parent} | grep -e '--amend')
  if [[ -n "$amended" ]]; then
    exit 0
  fi
fi

bash scripts/setup.sh
folders=("models" "server" "app" "translations")
for d in "${folders[@]}"; do
  cd "$d" || exit

  dartfmt -w --fix lib
  output=$(dartanalyzer lib)
  if [[ -d "test" ]]; then
    dartfmt -w --fix test
    output=$(dartanalyzer test)
  fi

  status=$?
  echo "$output"
  if [[ "$status" != 0 ]] || echo "$output" | grep -q "lint" || echo "$output" | grep -q "hint"; then
    d=${d%/}
    echo "$d failed checks"
    exit 1
  fi
  cd ..
done

bash scripts/test.sh
