#!/bin/bash

### Func
run_tests() {
  echo "========== Checking test files =========="
  ls R0a1t*S1MQL.sift.fps
  echo

  echo "========== Testing fps_draw =========="
  ./$1 draw R0a1t1e0X20241112S1MQL.sift.fps
  echo 
  cat R0a1t1e0X20241112S1MQL.sift@.fps
  echo
  sleep 1

  echo "========== Testing fps_keys =========="
  echo "Keys output:"
  ./$1 keys R0a1t1e0X20241112S1MQL.sift.fps
  echo
  sleep 1

  echo "========== Testing fps_norm =========="
  ./$1 norm R0a1t1e0X20241112S1MQL.sift.fps
  norm_file=$(head -n1 "R0a1t1e0X20241112S1MQL.sift.fps" | awk -F'[|][|]' '{print $2}').fps
  echo
  cat "$norm_file"
  echo
  sleep 1

  echo "========== Testing fps_stat (key: Profit) =========="
  ./$1 stat R0a1t1e0X20241112S1MQL.sift.fps Profit
  echo
  sleep 1

  echo "========== Testing fps_find (word: AUDUSD) =========="
  ./$1 find R0a1t1e0X20241112S1MQL.sift.fps AUDUSD
  echo
  sleep 1

  echo "========== Testing fps_sift (condition: Profit >= 100) =========="
  ./$1 sift R0a1t1e0X20241112S1MQL.sift.fps "0 || (Trades >= 50 && Packload > 0.1) || (Trades > 10 && Packload >= 0.2)"
  sift_output=$(ls R0a1t1e0X20241112S1MQL*#*.fps)
  echo
  cat "$sift_output"
  echo
  sleep 1

  echo "========== Testing fps_sort_key (sort by Profit ascending) =========="
  ./$1 sort R0a1t1e0X20241112S1MQL.sift.fps Packload -
  sort_output="R0a1t1e0X20241112S1MQL.sift@Packload-.fps"
  echo
  cat "$sort_output"
  echo
  sleep 1

  echo "========== Testing fps_merge_set =========="
  ./$1 merge R0a1t_merged.fps R0a1t1e0X20241112S1MQL.sift.fps R0a1t2e0X20241130S1MQL.sift.fps
  echo
  cat R0a1t_merged.fps
  echo
  sleep 1

  echo "========== Testing python run parallel =========="
  ./$1 m1run.py m0.fps 0
  echo
  sleep 1
  echo "========== Testing shell run parallel =========="
  ./$1 m2run.sh m0.fps 0
  echo
  sleep 1
  echo "========== Testing shell run serial =========="
  ./$1 m2run.sh m0.fps
  echo
  sleep 1
  echo "========== Testing shell run single =========="
  ./$1 m2run.sh m0.fps 2
  echo
  sleep 1
  echo "========== Testing C run parallel =========="
  ./$1 m3run m0.fps 0
  echo
  sleep 1
  echo "========== Testing C++ run parallel =========="
  ./$1 m4run m0.fps 0
  echo
  sleep 1
}

### Main
if [[ $# -eq 0 ]]; then
  echo "$0: <f1.sh>"
  exit 1
fi
run_tests $1
