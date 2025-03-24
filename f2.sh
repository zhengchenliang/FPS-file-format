#!/bin/bash

# shc -f f1.sh -o f1 -H

## fps a3func2build.sh:"build vers=\"v1\" functional" m45.fps:0 m100.fps:0,1-4 m100.fps:5 m100.fps:6-8 m100.fps:0,10,12 m100.fps:-,13,14 m100.fps:0,"name = 'test'" m283.fps:-

### Func
is_numeric() {
  local value="$1"
  if [[ "$value" =~ ^-?[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$ ]]; then
    return 0 # Numeric
  else
    return 1
  fi
}

this_name="fps"

fps_inst() {
  local full_path=$(readlink -f "$0")
  chmod +x "$full_path"
  ln -sf "$full_path" /usr/local/bin/${this_name}
  echo "$0: Installed '/usr/local/bin/${this_name}'"
  local comp_file="/etc/bash_completion.d/${this_name}"
  sudo tee "$comp_file" > /dev/null << 'EOF'
if [[ -n "$BASH_VERSION" && -n "$PS1" ]]; then
_fps_completion() {
  local cur prev opts
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  if [[ $COMP_CWORD -eq 1 ]]; then
    opts="inst uninst keys draw norm json jfps flat stat find sift sort merge"
    local opt_completions=( $(compgen -W "${opts}" -- "${cur}") )
    local file_completions=( $(compgen -f -- "${cur}") )
    local filtered_file_completions=()
    for file in "${file_completions[@]}"; do
      if [[ ! -d "$file" ]] && ! grep -qw "$file" <<< "$opts"; then
        local exe0=0
        if [[ -x "$file" ]] && file "$file" | grep -q "ELF"; then
          exe0=1
        fi
        if [[ $exe0 -eq 1
          || "$file" == *.sh
          || "$file" == *.py
        ]]; then
          filtered_file_completions+=("$file")
        fi
      fi
    done
    COMPREPLY=( "${opt_completions[@]}" "${filtered_file_completions[@]}" )
  else
    COMPREPLY=( $(compgen -f -- "${cur}") )
  fi
}
complete -F _fps_completion __THIS_NAME__
fi
EOF
  sudo sed -i "s/__THIS_NAME__/${this_name}/g" "$comp_file"
  echo "$0: Installed bash completion for '${this_name}' in '${comp_file}'"
}

fps_uninst() {
  if [[ -L /usr/local/bin/${this_name} ]]; then
    rm -f /usr/local/bin/${this_name}
    echo "$0: Uninstalled '/usr/local/bin/${this_name}'"
  fi
  local comp_file="/etc/bash_completion.d/${this_name}"
  if [[ -f "$comp_file" ]]; then
    sudo rm -f "$comp_file"
    echo "$0: Removed bash completion file '${comp_file}'"
  fi
}

fps_keys() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "$0: '$file' not found."
    exit 1
  fi
  local h0=$(head -n1 "$file")
  local b0=$(echo "$h0" | awk -F'[|][|]' '{print $3}') # backg
  local c0=$(echo "$h0" | awk -F'[|][|]' '{print $2}') # prere
  local p0=$(echo "$h0" | awk -F'[|][|]' '{print $1}') # chart
  local out1="$file void Key"
  [[ ! -z $p0 ]] && {
    IFS='|' read -ra ps0 <<< "$p0"
    out1="$file Keys ="
    for key1 in "${ps0[@]}"; do
      out1="$out1 \$${c0}${key1}"
    done
  }
  [[ ! -z $b0 ]] && {
    IFS='|' read -ra bs0 <<< "$b0"
    out1="$out1 | Bkg ="
    for bkg1 in "${bs0[@]}"; do
      out1="$out1 ${bkg1}"
    done
  }
  echo "$out1"
}

fps_draw() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "$0: '$file' not found."
    exit 1
  fi
  declare -a data=()
  local index=0
  while IFS='' read -r line; do
    data[$index]="$line"
    ((index++))
  done < "$file"
  if [[ ${#data[@]} -lt 1 ]]; then
    echo "$0: '$file' has no chart."
    return
  fi
  local h0="${data[0]}"
  local b0=$(echo "$h0" | awk -F'[|][|]' '{print $3}') # backg
  local c0=$(echo "$h0" | awk -F'[|][|]' '{print $2}') # prere
  local p0=$(echo "$h0" | awk -F'[|][|]' '{print $1}') # chart
  IFS='|' read -ra ps0 <<< "$p0"
  local nps0=${#ps0[@]}
  declare -a splittedFields=()
  declare -a maxLen=()
  for ((j=0; j<nps0; j++)); do
    maxLen[$j]=0
  done
  # align first pass
  local totalLines=${#data[@]}
  local chartLines=$((totalLines - 1))
  for ((i=0; i<totalLines; i++)); do
    local chartPart
    if (( i == 0 )); then
      chartPart=$(echo "${data[$i]}" | awk -F'[|][|]' '{print $1}')
    else
      chartPart=$(echo "${data[$i]}")
    fi
    IFS='|' read -ra fields <<< "$chartPart"
    if [[ ${#fields[@]} -eq $nps0 ]]; then
      for ((j=0; j<nps0; j++)); do
        splittedFields[$((i*nps0 + j))]="${fields[$j]}"
        local length=${#fields[$j]}
        if (( length > maxLen[j] )); then
          maxLen[$j]=$length
        fi
      done
    else # same mismatched
      for ((j=0; j<${#fields[@]}; j++)); do
        splittedFields[$((i*nps0 + j))]="${fields[$j]}"
      done
    fi
    echo -ne "\r$0: Aligning 1st pass sort #$i/$chartLines ..."
  done
  echo
  # align second pass
  local aligned=""
  for ((i=0; i<totalLines; i++)); do
    local chartPart
    if (( i == 0 )); then
      chartPart=$(echo "${data[$i]}" | awk -F'[|][|]' '{print $1}')
    else
      chartPart=$(echo "${data[$i]}")
    fi
    IFS='|' read -ra checkArr <<< "$chartPart"
    if [[ ${#checkArr[@]} -eq $nps0 ]]; then
      local newLine=""
      for ((j=0; j<nps0; j++)); do
        local cell="${splittedFields[$((i*nps0 + j))]}"
        local needed=$(( maxLen[j] - ${#cell} ))
        local padding="$(printf '%*s' "$needed")" # append spaces
        newLine+="${cell}${padding}"
        if (( j < nps0-1 )); then
          newLine+="|"
        fi
      done
      if (( i == 0 )); then
        newLine+="||${c0}||${b0}"
      fi
      aligned+="$newLine"$'\n'
    else # same mismatched
      aligned+="${data[$i]}"$'\n'
    fi
    echo -ne "\r$0: Aligning 2nd pass draw #$i/$chartLines ..."
  done
  local outfile="${file%.fps}@.fps"
  aligned="${aligned%$'\n'}"
  echo "$aligned" > "$outfile"
  echo -e "\r"
  echo "$0: Aligned '$file' to '$outfile'"
}

fps_norm() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "$0: '$file' not found."
    exit 1
  fi
  local h0=$(head -n1 "$file")
  local b0=$(echo "$h0" | awk -F'[|][|]' '{print $3}') # backg
  local c0=$(echo "$h0" | awk -F'[|][|]' '{print $2}') # prere
  local p0=$(echo "$h0" | awk -F'[|][|]' '{print $1}') # chart
  IFS='|' read -ra ps0 <<< "$p0"
  local nps0=${#ps0[@]}
  local sps0=$(echo "${ps0[@]}" | tr ' ' '\n' | sort | tr '\n' ' ')
  declare -A sidx0 # keys-column dict
  local i0=0
  for key0 in $sps0; do
    for j0 in "${!ps0[@]}"; do
      if [[ "${ps0[$j0]}" == "$key0" ]]; then
        sidx0[$j0]=$i0
      fi
    done
    ((i0++))
  done
  local sln0=$(echo "$sps0" | tr ' ' '|')
  local out0="${sln0}|${c0}||${b0}"
  out0+=$'\n'
  # reorder each row by keys-column
  while IFS='|' read -ra pe0; do
    if [[ ${#pe0[@]} -eq $nps0 ]]; then
      local slm0=()
      for j0 in "${!ps0[@]}"; do
        slm0[${sidx0[$j0]}]="${pe0[$j0]}"
      done
      out0+=$(IFS='|'; echo "${slm0[*]}")$'\n'
    fi
  done < <( { tail -n +2 "$file"; [[ "$(tail -c 1 "$file")" != $'\n' ]] && printf "\n"; } )
  out0="${out0%$'\n'}"
  echo "$out0" > "${c0}.fps"
  echo "$0: Normalized '$file' to '${c0}.fps'"
}

fps_stat() {
  local file="$1"
  local key="$2"
  if [[ ! -f "$file" ]]; then
    echo "$0: '$file' not found." >&2
    exit 1
  fi
  local keyTrim=$(echo "$key" | sed 's/^[ \t]*//; s/[ \t]*$//')
  local h0=$(head -n1 "$file")
  local p0=$(echo "$h0" | awk -F'[|][|]' '{print $1}')
  IFS='|' read -ra keys <<< "$p0"
  local col=-1
  for (( i=0; i<${#keys[@]}; i++ )); do
    local trimmed=$(echo "${keys[$i]}" | sed 's/^[ \t]*//; s/[ \t]*$//')
    if [[ "$trimmed" == "$keyTrim" ]]; then
      col=$((i+1))
      break
    fi
  done
  if [[ $col -eq -1 ]]; then
    echo "$0: Key '$keyTrim' not found in '$file'."
    exit 1
  else
    echo "$0: Processing stat of '$keyTrim' in '$file' ..."
  fi
  # awk stats go
  local stats=$(awk -F'|' -v col="$col" '
    function trim(s) {
      gsub(/^[ \t]+|[ \t]+$/, "", s)
      return s
    }
    NR > 1 {
      if (NF >= col) {
        val = trim($col)
        if (val ~ /^-?[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$/) {
          count++
          sum += val
          sumsq += (val * val)
          if ((min == "") || (val < min))
            min = val
          if ((max == "") || (val > max))
            max = val
          data[count] = val
        }
      }
    }
    END {
      if (count > 0) {
        mean = sum / count
        variance = (sumsq - (sum * sum) / count) / count
        if (variance < 0) variance = 0
        std = sqrt(variance)
      } else {
        mean = std = 0
      }
      # Print stats: count, sum, mean, std, min, max
      printf "%d %f %f %f %f %f\n", count, sum, mean, std, min, max
      # Then print all numeric values space-separated for histogram building.
      for (i = 1; i <= count; i++) {
        printf "%f ", data[i]
      }
    }
  ' "$file")
  # parse awk stats output
  local firstLine=$(echo "$stats" | head -n1)
  local count=$(echo "$firstLine" | awk '{print $1}')
  local sum=$(echo "$firstLine" | awk '{print $2}')
  local mean=$(echo "$firstLine" | awk '{print $3}')
  local std=$(echo "$firstLine" | awk '{print $4}')
  local min=$(echo "$firstLine" | awk '{print $5}')
  local max=$(echo "$firstLine" | awk '{print $6}')
  local values=$(echo "$stats" | tail -n1)
  # awk histogram auto binning with Sturges's formula: bins = ceil(log2(n)) + 1
  local bins=$(awk -v n="$count" 'BEGIN {
    if (n > 0) {
      x = log(n)/log(2) + 1;
      bins = int(x);
      if (x > bins) bins++;
      print bins
    } else {
      print 0
    }
  }')
  local binWidth=$(awk -v mn="$min" -v mx="$max" -v bins="$bins" 'BEGIN {
    if (mx == mn)
      printf "%.10f", 1
    else
      printf "%.10f", (mx - mn) / bins
  }')
  echo "$0: Auto histogram binning #= ${bins} width ${binWidth} on events #= ${count} ..."
  declare -a hist # histogram bin counts
  for (( i=0; i<bins; i++ )); do
    hist[i]=0
  done
  for val in $values; do # fill in
    local binIndex=$(awk -v v="$val" -v mn="$min" -v width="$binWidth" -v bins="$bins" 'BEGIN {
      idx = int((v - mn) / width)
      if (idx >= bins) idx = bins - 1
      printf "%d", idx
    }')
    hist[binIndex]=$(( hist[binIndex] + 1 ))
  done
  local maxCount=0
  for c in "${hist[@]}"; do
    if (( c > maxCount )); then
      maxCount=$c
    fi
  done
  # text build histogram lines
  local maxBar=64
  local histo=""
  for (( i=0; i<bins; i++ )); do
    local low=$(awk -v mn="$min" -v i="$i" -v width="$binWidth" 'BEGIN {printf "%.2f", mn + i * width}')
    local high=$(awk -v mn="$min" -v i="$i" -v width="$binWidth" 'BEGIN {printf "%.2f", mn + (i+1) * width}')
    local count_bin=${hist[i]}
    local barLength=$(awk -v cnt="$count_bin" -v max="$maxCount" -v maxBar="$maxBar" 'BEGIN {if (max > 0) printf "%d", (cnt/max)*maxBar; else printf "0"}')
    local bar=$(printf "%0.s#" $(seq 1 $barLength))
    histo+=$(printf "%-${maxBar}s [%-16s , %16s)    # %d" "$bar" "$low" "$high" "$count_bin")
    histo+=$'\n'
  done
  histo="${histo%$'\n'}"
  local outFile="${file%.fps}@${keyTrim}.stat"
  {
    echo -e "----------\n"
    echo -e "'$keyTrim' in '$file':\n"
    echo "  #       = $count"
    echo "  Sum     = $sum"
    echo "  Mean    = $mean"
    echo "  Std Dev = $std"
    echo "  Max     = $max"
    echo "  Min     = $min"
    echo ""
    echo -e "Histogram bins #= $bins width $binWidth\n"
    echo "$histo"
  } > "$outFile"
  echo "$0: Stat key '$keyTrim' in '$file' to '$outFile'"
  echo
  cat "$outFile"
}

fps_find() {
  local file="$1"
  local value="$2"
  if [[ ! -f "$file" ]]; then
    echo "$0: '$file' not found."
    exit 1
  fi
  local h0=$(head -n1 "$file")
  local b0=$(echo "$h0" | awk -F'[|][|]' '{print $3}') # backg
  local c0=$(echo "$h0" | awk -F'[|][|]' '{print $2}') # prere
  local p0=$(echo "$h0" | awk -F'[|][|]' '{print $1}') # chart
  IFS='|' read -ra bs0 <<< "$b0"
  local bfound=()
  for bval in "${bs0[@]}"; do
    if grep -qF "$value" <<< "$bval"; then
      bfound+=("$bval")
    fi
  done
  IFS='|' read -ra ps0 <<< "$p0"
  local pfound=()
  for pval in "${ps0[@]}"; do
    if grep -qF "$value" <<< "$pval"; then
      pfound+=("$pval")
    fi
  done
  local nps0=${#ps0[@]}
  local lin2=1
  local found=()
  while IFS='|' read -r line; do
    IFS='|' read -ra pe0 <<< "$line"
    if [[ ${#pe0[@]} -eq ${nps0}
        && ( "$line" == *"$value|"*
          || "$line" == *"|$value"*
        )
      ]]; then
        found+=("$lin2")
    fi
    ((lin2++))
  done < <( { tail -n +2 "$file"; [[ "$(tail -c 1 "$file")" != $'\n' ]] && printf "\n"; } )
  local anyfound=false
  if [[ ${#pfound[@]} -gt 0 ]]; then
    echo "$file Word '$value' in Prerequisite: ${pfound[*]}"
    anyfound=true
  fi
  if [[ ${#bfound[@]} -gt 0 ]]; then
    echo "$file Word '$value' in Background: ${bfound[*]}"
    anyfound=true
  fi
  if [[ ${#found[@]} -gt 0 ]]; then
    echo "$file Word '$value' in Run ${found[*]} #= ${#found[@]}"
    anyfound=true
  fi
  if ! $anyfound; then
    echo "$file Word '$value' nonexist"
  fi
}

fps_sift() {
  local file="$1"
  local filterString="$2"
  local outputMode="${3:-file}" # Default to file output, can be "array" for row numbers
  if [[ ! -f "$file" ]]; then
    echo "$0: '$file' not found."
    exit 1
  fi
  if [[ -z "$filterString" ]]; then
    echo "$0: Missing sift condition string."
    exit 1
  fi
  local h0=$(head -n1 "$file")
  local b0=$(echo "$h0" | awk -F'[|][|]' '{print $3}') # background
  local c0=$(echo "$h0" | awk -F'[|][|]' '{print $2}') # prere
  local p0=$(echo "$h0" | awk -F'[|][|]' '{print $1}') # chart
  IFS='|' read -ra ps0 <<< "$p0"
  local nps0=${#ps0[@]}
  # extract comparisons plain inside [^|&()]+
  local -a comparisons=()
  local validOps='==|!=|>=|<=|>|<'
  while IFS= read -r plain; do
    local trimmed="$(echo "$plain" | sed 's/^[ \t]*//; s/[ \t]*$//')" # init and fina spaces
    local op="$(echo "$trimmed" | grep -oE "$validOps")"
    if [[ -z "$op" ]]; then
      continue # maybe logical constant
    fi
    local left="${trimmed%%$op*}"
    local right="${trimmed#*$op}"
    left="$(echo "$left" | sed 's/[ \t]*$//')"
    right="$(echo "$right" | sed 's/^[ \t]*//')"
    comparisons+=("$left $op $right")
  done < <(grep -oE "[^|&()]+[ \t]*($validOps)[ \t]*[^&|()]+" <<< "$filterString") # plain
  # key-column dict trimmed init and fina spaces
  declare -A colIndex=()
  for (( i0=0; i0<nps0; i0++ )); do
    local trimmed="$(echo "${ps0[$i0]}" | sed 's/^[ \t]*//; s/[ \t]*$//')"
    colIndex["$trimmed"]=$((i0+1))
  done
  # check comparisons plain
  local -a numericCols=() # those columns used in numeric comps
  local -a stringCols=() # those columns used in string comps
  local key op val
  local awkExpr="$filterString"
  for comp in "${comparisons[@]}"; do
    IFS=' ' read -r key op val <<< "$comp" # comp = "key op value"
    if [[ -z "${colIndex[$key]}" ]]; then
      echo "$0: Sifting key '$key' unknown in '$comp'."
      exit 1
    fi
    case "$op" in
      '=='|'!='|'>'|'>='|'<'|'<=')
        ;;
      *)
        echo "$0: Sifting operator '$op' invalid in '$comp'."
        exit 1
        ;;
    esac
    # Determine if value is numeric or string (quoted)
    if [[ "$val" =~ ^\".*\"$ || "$val" =~ ^\'.*\'$ ]]; then
      # String value - remove outer quotes for comparison
      stringCols+=( "${colIndex[$key]}" )
      # Extract the content between quotes
      local string_content
      if [[ "$val" =~ ^\"(.*)\"$ ]]; then
        string_content="${BASH_REMATCH[1]}"
      elif [[ "$val" =~ ^\'(.*)\'$ ]]; then
        string_content="${BASH_REMATCH[1]}"
      fi
      # Replace the original comparison in the expression with properly quoted version
      # Find the specific comparison pattern and replace it
      local regex_safe_key=$(echo "$key" | sed 's/[]\/$*.^[]/\\&/g')
      local regex_safe_val=$(echo "$val" | sed 's/[]\/$*.^[]/\\&/g')
      local regex_safe_op=$(echo "$op" | sed 's/[]\/$*.^[]/\\&/g')
      # Prepare the awk expression replacement with string comparison
      local awk_repl="\$${colIndex[$key]} $op \"$string_content\""
      # Replace the comparison in the entire expression
      awkExpr=$(echo "$awkExpr" | sed "s/${regex_safe_key}[ \t]*${regex_safe_op}[ \t]*${regex_safe_val}/${awk_repl}/g")
    else
      # Numeric value
      if ! is_numeric "$val"; then
        echo "$0: Sifting value '$val' not quoted string or numeric in '$comp'. Forgot to quote '...' strings?"
        exit 1
      fi
      numericCols+=( "${colIndex[$key]}" )
    fi
  done
  # check chart columns numeric
  declare -A numericSet=()
  for c in "${numericCols[@]}"; do
    numericSet[$c]=1
  done
  if [[ ${#numericSet[@]} -gt 0 ]]; then
    local checkCols=""
    for c in "${!numericSet[@]}"; do
      checkCols+="$c|"
    done
    checkCols="${checkCols%|}"
    awk -F '|' -v cols="$checkCols" -v file="$file" -v nps0="$nps0" '
      NR==1 { next } # skip header
      {
        if (NF != nps0) {
          next
        }
        split(cols,a,"|")
        for(i in a) {
          c=a[i]+0 # convert to int
          # Check if the field is numeric
          if($c !~ /^-?[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$/){
            printf("%s: Non-numeric in row #%d, col=%d => \"%s\"\n", file, NR, c, $c) > "/dev/stderr"
            exit 1
          }
        }
      }
    ' "$file" || {
      exit 1 # Abort on awk fails
    }
  fi
  # Replace key names with column references for remaining parts
  for name in "${!colIndex[@]}"; do
    # Only replace if not already handled in string comparisons
    local field_ref="\$${colIndex[$name]}"
    local regex_safe_name=$(echo "$name" | sed 's/[]\/$*.^[]/\\&/g')
    awkExpr=$(echo "$awkExpr" | sed "s/\b${regex_safe_name}\b/${field_ref}/g")
  done
  # Handle different output modes
  if [[ "$outputMode" == "array" ]]; then
    # Return comma-separated list of row numbers that match the condition
    local matching_rows=$(awk -F '|' -v awkExpr="$awkExpr" '
      BEGIN { first = 1 }
      NR==1 { next } # skip header
      {
        if('"$awkExpr"') {
          if (first) {
            printf("%d", NR-1);
            first = 0;
          } else {
            printf(",%d", NR-1);
          }
        }
      }
    ' "$file")
    echo "$matching_rows"
  else
    # Default file output mode
    local hash0=$(echo -n "$awkExpr" | sha1sum | awk '{print substr($1,1,16)}')
    local outFile="${file%.fps}#${hash0}.fps"
    echo "$h0" > "$outFile"
    # awk condition go
    awk -F '|' '
      NR==1 { next } # skip header
      {
        if('"$awkExpr"')
          print
      }
    ' "$file" >> "$outFile"
    local siftCount=$(tail -n +2 "$outFile" | wc -l)
    echo "$0: With '$filterString'"
    echo "$0: i.e. '$awkExpr'"
    echo "$0: Sifted '$file' to '$outFile' #= $siftCount"
  fi
}

fps_sort_key() {
  local file="$1"
  local keyword="$2"
  if [[ ! -f "$file" ]]; then
    echo "$0: '$file' not found."
    exit 1
  fi
  local order
  if [[ "$3" == "1" || "$3" == "+" ]]; then
    order="+"
  else
    order="-"
  fi
  local output_file="${file%.fps}@${keyword}${order}.fps"
  local header
  header=$(head -n 1 "$file")
  IFS='|' read -ra headers <<< "$header"
  local col=-1
  for i in "${!headers[@]}"; do
    if [[ "${headers[i]}" == "$keyword" ]]; then
      col=$((i+1)) # sort by this column (1-based index for sort command)
      break
    fi
  done
  if [[ $col -eq -1 ]]; then
    echo "Sort key '${keyword}' does not exist in '${file}'."
    exit 0
  fi
  echo "$header" > "$output_file"
  local sample_count=0
  local numeric=true
  while IFS='|' read -ra line; do
    local value="${line[$((col-1))]}"
    if [[ -n "$value" ]]; then
      if ! is_numeric "$value"; then
        numeric=false
        break
      fi
      ((sample_count++))
      [[ $sample_count -ge 10 ]] && break # Limit to first 10 samples to save time
    fi
  done < <( { tail -n +2 "$file"; [[ "$(tail -c 1 "$file")" != $'\n' ]] && printf "\n"; } )
  local sort_command
  if $numeric; then
    if [[ "$order" == "+" ]]; then
      sort_command="sort -t '|' -k${col},${col}n"
    else
      sort_command="sort -t '|' -k${col},${col}nr"
    fi
  else
    if [[ "$order" == "+" ]]; then
      sort_command="sort -t '|' -k${col},${col}"
    else
      sort_command="sort -t '|' -k${col},${col}r"
    fi
  fi
  tail -n +2 "$file" | eval "$sort_command" | sed '$!{/^$/d;}' >> "$output_file"
  echo "${file} sorted by '${keyword}' (${order}) to ${output_file}"
}

fps_merge_set() {
  local output_file="$1"
  shift
  local input_files=("$@")
  if [[ ${#input_files[@]} -lt 2 ]]; then
    echo "$0: Need 1 output and >= 2 input files to merge."
    exit 1
  fi
  for file in "${input_files[@]}"; do
    if [[ ! -f "$file" ]]; then
      echo "$0: File '$file' does not exist."
      exit 1
    fi
    if [[ "$file" != *.fps ]]; then
      echo "$0: File '$file' is not fps."
      exit 2
    fi
  done
  # 1st regularize
  local h1=$(head -n 1 "${input_files[0]}")
  local b1=$(echo "$h1" | awk -F'[|][|]' '{print $3}') # backg
  local c1=$(echo "$h1" | awk -F'[|][|]' '{print $2}') # prere
  local p1=$(echo "$h1" | awk -F'[|][|]' '{print $1}') # chart
  IFS='|' read -ra ps1 <<< "$p1"
  local nps1=${#ps1[@]}
  local sps1=$(echo "${ps1[@]}" | tr ' ' '\n' | sort | tr '\n' ' ')
  echo "$0: Key set in '${input_files[0]}'..."
  # check that all files have the same sorted key set
  for ((f1=1; f1<${#input_files[@]}; f1++)); do
    local h2=$(head -n 1 "${input_files[f1]}")
    local b2=$(echo "$h2" | awk -F'[|][|]' '{print $3}')
    local c2=$(echo "$h2" | awk -F'[|][|]' '{print $2}')
    local p2=$(echo "$h2" | awk -F'[|][|]' '{print $1}')
    IFS='|' read -ra ps2 <<< "$p2"
    local nps2=${#ps2[@]}
    local sps2=$(echo "${ps2[@]}" | tr ' ' '\n' | sort | tr '\n' ' ')
    if [[ $nps1 != $nps2 || $sps1 != $sps2 ]]; then
      echo "$0: Key set in '${input_files[f1]}' mismatched with '${input_files[0]}'. Merge aborted."
      exit 1
    else
      echo "$0: Key set in '${input_files[f1]}' ..."
    fi
  done
  # key set merge
  local sln1=$(echo "$sps1" | tr ' ' '|')
  local out1="${sln1}|${c1}||${b1}"
  echo "$out1" > "$output_file"
  for ((f1=0; f1<${#input_files[@]}; f1++)); do
    echo "$0: Merging key set in ${input_files[f1]} ..."
    out1=""
    local h1=$(head -n 1 "${input_files[f1]}")
    local b1=$(echo $h1 | awk -F'[|][|]' '{print $3}')
    local c1=$(echo $h1 | awk -F'[|][|]' '{print $2}')
    local p1=$(echo $h1 | awk -F'[|][|]' '{print $1}')
    IFS='|' read -r -a ps1 <<< "$p1"
    local nps1=${#ps1[@]}
    local sps1=$(echo "${ps1[@]}" | tr ' ' '\n' | sort | tr '\n' ' ')
    declare -A sidx1 # sort index dict
    local i1=0
    for key1 in ${sps1}; do
      for j1 in "${!ps1[@]}"; do
        if [[ "${ps1[$j1]}" == "${key1}" ]]; then
          sidx1[$j1]=$i1
        fi
      done
      ((i1++))
    done
    while IFS='|' read -ra pe1; do
      if [[ ${#pe1[@]} -eq ${nps1} ]]; then
        slm1=()
        for j1 in "${!ps1[@]}"; do
          slm1[${sidx1[$j1]}]="${pe1[$j1]}"
        done
        out1+=$(IFS='|'; echo "${slm1[*]}")$'\n'
      fi
    done < <( { tail -n +2 "${input_files[f1]}"; [[ "$(tail -c 1 "${input_files[f1]}")" != $'\n' ]] && printf "\n"; } )
    out1="${out1%$'\n'}"
    echo "$out1" >> $output_file
  done
  echo "$0: Merged key set into ${output_file}."
}

fps_run_script() {
  local script="$1"
  local file="$2"
  local sel="$3"
  if [[ ! -f "$script" ]]; then
    echo "$0: provided '$script' not accessed as a file."
    exit 2
  fi
  if [[ ! -f "$file" ]]; then
    echo "$0: provided '$file' not accessed as a file."
    exit 2
  fi
  local h0=$(head -n 1 "$file")
  local b0=$(echo "$h0" | awk -F'[|][|]' '{print $3}') # backg
  local c0=$(echo "$h0" | awk -F'[|][|]' '{print $2}') # prere
  local p0=$(echo "$h0" | awk -F'[|][|]' '{print $1}') # chart
  IFS='|' read -ra ps0 <<< "$p0"
  local nps0=${#ps0[@]}
  local nl0=0 # total lines processed
  local nl1=0 # total lines matched/executed

  declare -A _bgVisited=() # track visited fps:run tuple
  _setup_bg_iterative() {
    local initFile="$1"
    [[ "$initFile" != *.fps ]] && initFile="${initFile}.fps"
    local initRun="$2"
    declare -a queue=()
    queue+=("${initFile}:${initRun}")
    while [[ ${#queue[@]} -gt 0 ]]; do
      # queue pop the last element
      local item="${queue[${#queue[@]}-1]}"
      unset "queue[${#queue[@]}-1]"
      queue=("${queue[@]}") # re-index bash array to eliminate the hole from unset
      local bfile="${item%%:*}"
      local brun="${item##*:}"
      local visitedKey="${bfile%.fps}:${brun}"
      if [[ -n "${_bgVisited[$visitedKey]}" ]]; then # kill visited
        continue
      fi
      _bgVisited[$visitedKey]=1 # mark visited
      # queue visit
      if [[ ! -f "$bfile" ]]; then
        echo "$0: Skipped background '$bfile' not accessed as a file."
        continue
      fi
      local bh0=$(head -n 1 "$bfile")
      local bb0=$(echo "$bh0" | awk -F'[|][|]' '{print $3}') # backg
      local bc0=$(echo "$bh0" | awk -F'[|][|]' '{print $2}') # prere
      local bp0=$(echo "$bh0" | awk -F'[|][|]' '{print $1}') # chart
      IFS='|' read -ra bps0 <<< "$bp0"
      local nbps0=${#bps0[@]}
      local lineNum=$((brun + 1))
      local boneLine=$(tail -n +$lineNum "$bfile" | head -n 1)
      if [[ -z "$boneLine" ]]; then
        echo "$0: Skipped in '$bfile' run #$brun nonexist."
        continue
      fi
      IFS='|' read -ra bfields <<< "$boneLine"
      if [[ ${#bfields[@]} -ne $nbps0 ]]; then
        echo "$0: Skipped in '$bfile' run #$brun mismatch."
        continue
      fi
      if [[ $exe0 -eq 1 || "$script" == *.sh ]]; then
        export "${bc0}=${brun}"
        for (( i0=0; i0<nbps0; i0++ )); do
          export "${bc0}${bps0[$i0]}=${bfields[$i0]}"
        done
      elif [[ "$script" == *.py ]]; then
        var0b+="${bc0}='${brun}'; "
        for (( i0=0; i0<nbps0; i0++ )); do
          var0b+="${bc0}${bps0[$i0]}='${bfields[$i0]}'; "
        done
      fi
      # queue append
      if [[ -n "$bb0" ]]; then
        IFS='|' read -ra bbs0 <<< "$bb0"
        for bval in "${bbs0[@]}"; do
          local subFile="${bval%%:*}"
          [[ "$subFile" != *.fps ]] && subFile="${subFile}.fps"
          if [[ "$bval" == *":"* ]]; then
            local subRun="${bval##*:}"
            # Check if this is a condition-based selector (enclosed in double quotes)
            if [[ "$subRun" =~ ^\".*\"$ ]]; then
              # Extract the condition from the quotes
              local subConditionSelector="${subRun:1:$((${#subRun}-2))}"
              echo "$0: Processing condition-based sub-background selector: $subConditionSelector for $subFile"
              # Get matching run numbers using fps_sift
              if [[ -f "$subFile" ]]; then
                local sub_matching_runs=$(fps_sift "$subFile" "$subConditionSelector" "array")
                if [[ -z "$sub_matching_runs" ]]; then
                  echo "$0: No runs in '$subFile' match the condition: $subConditionSelector"
                  continue
                fi
                echo "$0: Matched runs in '$subFile': $sub_matching_runs"
                # Add each matching run to the queue
                IFS=',' read -ra sub_run_arr <<< "$sub_matching_runs"
                for r in "${sub_run_arr[@]}"; do
                  queue+=("${subFile}:${r}")
                done
              else
                echo "$0: Skipped background '$subFile' not accessed as a file."
              fi
              continue
            elif ! [[ "$subRun" =~ ^[0-9]+$ ]]; then
              echo "$0: Skipped background '$bval' invalid run number '$subRun'."
              continue
            fi
            queue+=("${subFile}:${subRun}")
          else # default run 1
            queue+=("${subFile}:1")
          fi
        done
      fi
    done
  }
  run_row() {
    local -n rowArr="$1" # name reference to pass array by name
    # prere
    if [[ $exe0 -eq 1 || "$script" == *.sh ]]; then
      export "${c0}=${nl0}"
      for (( i0=0; i0<${#ps0[@]}; i0++ )); do
        export "${c0}${ps0[$i0]}=${rowArr[$i0]}"
      done
      if [[ -n "${FPS_RUN_ARGS}" ]]; then
        eval "./$script ${FPS_RUN_ARGS}"
      else
        ./"$script"
      fi
    elif [[ "$script" == *.py ]]; then
      local var0="$var0b"
      var0+="${c0}='${nl0}'; "
      for (( i0=0; i0<${#ps0[@]}; i0++ )); do
        var0+="${c0}${ps0[$i0]}='${rowArr[$i0]}'; "
      done
      if [[ -n "${FPS_RUN_ARGS}" ]]; then
        eval "python3 -c \"import os; ${var0}exec(open('$script').read())\" ${FPS_RUN_ARGS}"
      else
        python3 -c "import os; ${var0}exec(open('$script').read())"
      fi
    fi
  }
  # backg
  local var0b=""
  if [[ -n "$b0" ]]; then
    IFS='|' read -ra bs0 <<< "$b0"
    for bentry in "${bs0[@]}"; do
      if [[ "$bentry" == *":"* ]]; then
        local subFile="${bentry%%:*}"
        local subRun="${bentry##*:}"
        # Check if this is a condition-based selector (enclosed in double quotes)
        if [[ "$subRun" =~ ^\".*\"$ ]]; then
          # Extract the condition from the quotes
          local conditionSelector="${subRun:1:$((${#subRun}-2))}"
          echo "$0: Processing condition-based background selector: $conditionSelector for $subFile"
          # Get matching run numbers using fps_sift
          [[ "$subFile" != *.fps ]] && subFile="${subFile}.fps"
          if [[ -f "$subFile" ]]; then
            local matching_runs=$(fps_sift "$subFile" "$conditionSelector" "array")
            if [[ -z "$matching_runs" ]]; then
              echo "$0: No runs in '$subFile' match the condition: $conditionSelector"
              continue
            fi
            echo "$0: Matched runs in '$subFile': $matching_runs"
            # Process each matching run
            IFS=',' read -ra run_arr <<< "$matching_runs"
            for r in "${run_arr[@]}"; do
              _setup_bg_iterative "$subFile" "$r"
            done
          else
            echo "$0: Skipped background '$subFile' not accessed as a file."
          fi
        elif ! [[ "$subRun" =~ ^[0-9]+$ ]]; then
          echo "$0: Skipped background '$bentry' invalid run number '$subRun'."
          continue
        else
          _setup_bg_iterative "$subFile" "$subRun"
        fi
      else # default run 1
        _setup_bg_iterative "$bentry" "1"
      fi
    done
    echo "${!_bgVisited[@]}"
    echo "----------"
  fi
  # chart
  if [[ -z "$sel" ]]; then # serial run
    while IFS='|' read -ra fields; do
      ((nl0++))
      if [[ ${#fields[@]} -eq $nps0 ]]; then
        run_row fields
        ((nl1++))
      else
        echo "$0: Skipping mismatched run #$nl0."
      fi
    done < <( { tail -n +2 "$file"; [[ "$(tail -c 1 "$file")" != $'\n' ]] && printf "\n"; } )
    echo "$0: Done with ${nl1}/${nl0} runs (serial)"
  elif [[ "$sel" == "0" ]]; then # parallel run then wait
    while IFS='|' read -ra fields; do
      ((nl0++))
      if [[ ${#fields[@]} -eq $nps0 ]]; then
        ( run_row fields ) &
        ((nl1++))
      else
        echo "$0: Skipping mismatched run #$nl0."
      fi
    done < <( { tail -n +2 "$file"; [[ "$(tail -c 1 "$file")" != $'\n' ]] && printf "\n"; } )
    wait
    echo "$0: Done with ${nl1}/${nl0} runs (parallel)"
  elif [[ "$sel" == "-" ]]; then # parallel run mixed
    while IFS='|' read -ra fields; do
      ((nl0++))
      if [[ ${#fields[@]} -eq $nps0 ]]; then
        ( run_row fields ) &
        ((nl1++))
      else
        echo "$0: Skipping mismatched run #$nl0."
      fi
    done < <( { tail -n +2 "$file"; [[ "$(tail -c 1 "$file")" != $'\n' ]] && printf "\n"; } )
    fin0=1
    echo "$0: Done with ${nl1}/${nl0} runs (parallel)"
  else # single run
    if [[ "$sel" =~ ^[0-9]+$ ]]; then
      local lineNum=$((sel + 1)) # +1 to skip the header
      local oneLine=$(tail -n +$lineNum "$file" | head -n 1)
      if [[ -z "$oneLine" ]]; then
        echo "$0: No row #$sel found in '$file'."
        return
      fi
      IFS='|' read -ra fields <<< "$oneLine"
      if [[ ${#fields[@]} -eq $nps0 ]]; then
        run_row fields
        echo "$0: Done with 1/1 run (#$sel)"
      else
        echo "$0: Mismatched run #$sel."
      fi
    else
      echo "$0: Invalid run number '$sel'."
      exit 1
    fi
  fi
}

fps_json() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "$0: '$file' not found."
    exit 1
  fi
  # Extract header components
  local h0=$(head -n 1 "$file")
  local b0=$(echo "$h0" | awk -F'[|][|]' '{print $3}') # backg
  local c0=$(echo "$h0" | awk -F'[|][|]' '{print $2}') # prere
  local p0=$(echo "$h0" | awk -F'[|][|]' '{print $1}') # chart
  IFS='|' read -ra ps0 <<< "$p0"
  local nps0=${#ps0[@]}
  local key_file="${file%.fps}"
  local out_file="${key_file}.json"
  # Start building the JSON
  local json="{\n"
  # Add _chart section
  json+="  \"_chart\": {\n"
  json+="    \"_set\": \"$key_file\",\n"
  json+="    \"_key\": \"$c0\",\n"
  # Process each run (line) in the main file
  local run_num=0
  local run_count=0
  local runs_json=""
  while IFS='|' read -ra fields; do
    ((run_num++))
    if [[ ${#fields[@]} -eq $nps0 ]]; then
      # Start the run JSON
      if [[ $run_count -gt 0 ]]; then
        runs_json+=",\n"
      fi
      runs_json+="      \"$run_num\": {\n"
      # Add each field
      local first_field=true
      for (( i=0; i<nps0; i++ )); do
        local key="${ps0[$i]}"
        local value="${fields[$i]}"
        # Check if value is an array (enclosed in curly braces)
        if [[ "$value" =~ ^\{.*\}$ ]]; then
          # Extract the content between braces
          local array_content="${value:1:$((${#value}-2))}"
          # Split by ", " to get array elements
          IFS=', ' read -ra array_elements <<< "$array_content"
          if ! $first_field; then
            runs_json+=",\n"
          else
            first_field=false
          fi
          # Start JSON array
          runs_json+="        \"$key\": ["
          local first_element=true
          for element in "${array_elements[@]}"; do
            # Add comma separator if not the first element
            if ! $first_element; then
              runs_json+=", "
            else
              first_element=false
            fi
            # Check if element is numeric
            if is_numeric "$element"; then
              runs_json+="$element"
            else
              # Escape quotes in string values
              element="${element//\"/\\\"}"
              runs_json+="\"$element\""
            fi
          done
          # Close JSON array
          runs_json+="]"
        # Regular non-array value handling
        elif is_numeric "$value"; then
          if ! $first_field; then
            runs_json+=",\n"
          else
            first_field=false
          fi
          runs_json+="        \"$key\": $value"
        else
          # Escape quotes in string values
          value="${value//\"/\\\"}"
          if ! $first_field; then
            runs_json+=",\n"
          else
            first_field=false
          fi
          runs_json+="        \"$key\": \"$value\""
        fi
      done
      # Close the run
      runs_json+="\n      }"
      ((run_count++))
    fi
  done < <( { tail -n +2 "$file"; [[ "$(tail -c 1 "$file")" != $'\n' ]] && printf "\n"; } )
  # Add the runs to the _chart section
  json+="    \"_run\": {\n$runs_json\n    }\n  }"
  # Process background files iteratively if they exist
  if [[ -n "$b0" ]]; then
    json+=",\n  \"_backg\": {"
    # Temporary arrays to store background JSON data
    declare -A backg_files=()
    declare -A backg_charts=()
    declare -A backg_data=()
    # Use iterative approach like in fps_run_script
    declare -A _bgVisited=() # track visited fps:run tuple
    # Queue for iterative processing
    declare -a queue=()
    # Add initial background entries to the queue
    IFS='|' read -ra bs0 <<< "$b0"
    for bentry in "${bs0[@]}"; do
      local bfile="${bentry%%:*}"
      [[ "$bfile" != *.fps ]] && bfile="${bfile}.fps"
      local brun=1 # Default run
      local processAllRuns=false
      local conditionSelector=""
      if [[ "$bentry" == *":"* ]]; then
        brun="${bentry##*:}"
        # Check if this is a condition-based selector (enclosed in double quotes)
        if [[ "$brun" =~ ^\".*\"$ ]]; then
          # Extract the condition from the quotes
          conditionSelector="${brun:1:$((${#brun}-2))}"
          echo "$0: Processing condition-based background selector: $conditionSelector for $bfile"
          # Get matching run numbers using fps_sift
          if [[ -f "$bfile" ]]; then
            local matching_runs=$(fps_sift "$bfile" "$conditionSelector" "array")
            if [[ -z "$matching_runs" ]]; then
              echo "$0: No runs in '$bfile' match the condition: $conditionSelector"
              continue
            fi
            echo "$0: Matched runs in '$bfile': $matching_runs"
            # Add each matching run to the queue
            IFS=',' read -ra run_arr <<< "$matching_runs"
            for r in "${run_arr[@]}"; do
              queue+=("${bfile}:${r}")
            done
          else
            echo "$0: Skipped background '$bfile' not accessed as a file."
          fi
          continue
        elif [[ "$brun" == "0" ]]; then
          # Special case: process all runs in the file
          processAllRuns=true
        elif ! [[ "$brun" =~ ^[0-9]+$ ]]; then
          echo "$0: Skipped background '$bentry' invalid run number '$brun'."
          continue
        fi
      else
        # No run specified (like "b0") - treat as "process all runs"
        processAllRuns=true
      fi
      if $processAllRuns; then
        # Process all runs in the file
        if [[ ! -f "$bfile" ]]; then
          echo "$0: Skipped background '$bfile' not accessed as a file."
          continue
        fi
        # Always process the background references from the header
        local bh0=$(head -n 1 "$bfile")
        local bb0=$(echo "$bh0" | awk -F'[|][|]' '{print $3}') # backg
        local bc0=$(echo "$bh0" | awk -F'[|][|]' '{print $2}') # prere
        local bp0=$(echo "$bh0" | awk -F'[|][|]' '{print $1}') # chart
        # If file has background references, process them
        if [[ -n "$bb0" ]]; then
          IFS='|' read -ra bbs0 <<< "$bb0"
          for bval in "${bbs0[@]}"; do
            local subFile="${bval%%:*}"
            [[ "$subFile" != *.fps ]] && subFile="${subFile}.fps"
            local subRun=1 # Default run
            local processAllSubRuns=false
            if [[ "$bval" == *":"* ]]; then
              subRun="${bval##*:}"
              # Check if this is a condition-based selector (enclosed in double quotes)
              if [[ "$subRun" =~ ^\".*\"$ ]]; then
                # Extract the condition from the quotes
                local subConditionSelector="${subRun:1:$((${#subRun}-2))}"
                echo "$0: Processing condition-based sub-background selector: $subConditionSelector for $subFile"
                # Get matching run numbers using fps_sift
                if [[ -f "$subFile" ]]; then
                  local sub_matching_runs=$(fps_sift "$subFile" "$subConditionSelector" "array")
                  if [[ -z "$sub_matching_runs" ]]; then
                    echo "$0: No runs in '$subFile' match the condition: $subConditionSelector"
                    continue
                  fi
                  echo "$0: Matched runs in '$subFile': $sub_matching_runs"
                  # Add each matching run to the queue
                  IFS=',' read -ra sub_run_arr <<< "$sub_matching_runs"
                  for r in "${sub_run_arr[@]}"; do
                    queue+=("${subFile}:${r}")
                  done
                else
                  echo "$0: Skipped background '$subFile' not accessed as a file."
                fi
                continue
              elif [[ "$subRun" == "0" ]]; then
                # Special case: process all runs in the file
                processAllSubRuns=true
              elif ! [[ "$subRun" =~ ^[0-9]+$ ]]; then
                echo "$0: Skipped background '$bval' invalid run number '$subRun'."
                continue
              fi
            else
              # No run specified (like "b0") - treat as "process all runs"
              processAllSubRuns=true
            fi
            if $processAllSubRuns; then
              # Process all runs in the file
              if [[ ! -f "$subFile" ]]; then
                echo "$0: Skipped background '$subFile' not accessed as a file."
                continue
              fi
              # Count the number of lines (runs) in the file, excluding the header
              local subRunCount=$(wc -l < "$subFile")
              ((subRunCount--)) # Subtract 1 for the header line
              # Add each run to the queue
              for ((r=1; r<=subRunCount; r++)); do
                queue+=("${subFile}:${r}")
              done
              # If the sub-file has 0 run lines but has background references, add it to process
              if [[ $subRunCount -eq 0 ]]; then
                local subHeader=$(head -n 1 "$subFile")
                local subBackg=$(echo "$subHeader" | awk -F'[|][|]' '{print $3}') # backg
                if [[ -n "$subBackg" ]]; then
                  queue+=("${subFile}:1")
                fi
              fi
            else
              # Process the single specified run
              queue+=("${subFile}:${subRun}")
            fi
          done
        fi
        # Count the number of lines (runs) in the file, excluding the header
        local runCount=$(wc -l < "$bfile")
        ((runCount--)) # Subtract 1 for the header line
        # If the file is void-body but has background references, add a dummy run
        if [[ $runCount -eq 0 && -n "$bb0" ]]; then
          queue+=("${bfile}:1")
        elif [[ $runCount -gt 0 ]]; then
          # Only add runs to the queue if there are any
          # Add each run to the queue
          for ((r=1; r<=runCount; r++)); do
            queue+=("${bfile}:${r}")
          done
        fi
      else
        # Process the single specified run
        queue+=("${bfile}:${brun}")
      fi
    done
    # Process the queue
    while [[ ${#queue[@]} -gt 0 ]]; do
      # Pop the last element from the queue
      local item="${queue[${#queue[@]}-1]}"
      unset "queue[${#queue[@]}-1]"
      queue=("${queue[@]}") # re-index the array
      local bfile="${item%%:*}"
      local brun="${item##*:}"
      local visitedKey="${bfile%.fps}:${brun}"
      # Skip if already visited
      if [[ -n "${_bgVisited[$visitedKey]}" ]]; then
        continue
      fi
      _bgVisited[$visitedKey]=1 # Mark as visited
      # Process the background file
      if [[ ! -f "$bfile" ]]; then
        echo "$0: Skipped background '$bfile' not accessed as a file."
        continue
      fi
      # Extract header components
      local bh0=$(head -n 1 "$bfile")
      local bb0=$(echo "$bh0" | awk -F'[|][|]' '{print $3}') # backg
      local bc0=$(echo "$bh0" | awk -F'[|][|]' '{print $2}') # prere
      local bp0=$(echo "$bh0" | awk -F'[|][|]' '{print $1}') # chart
      # Check if this is a void-body file
      local is_void_body=false
      IFS='|' read -ra bps0 <<< "$bp0"
      local nbps0=${#bps0[@]}
      # Get the specified run
      local lineNum=$((brun + 1))
      local boneLine=$(tail -n +$lineNum "$bfile" | head -n 1)
      # Add to the data structure
      local cleanFile="${bfile%.fps}"
      local chartPrefix="${bc0}"
      # Store file and chart in sets (to track unique values)
      backg_files["$cleanFile"]=1
      backg_charts["$cleanFile:$chartPrefix"]=1
      if [[ -z "$boneLine" && "$is_void_body" == "true" ]]; then
        # Void-body file with no runs - store empty data
        backg_data["$cleanFile:$chartPrefix:$brun"]=""
      elif [[ -n "$boneLine" ]]; then
        # Normal file with data - process as before
        IFS='|' read -ra bfields <<< "$boneLine"
        if [[ ${#bfields[@]} -ne $nbps0 && "$is_void_body" == "false" ]]; then
          echo "$0: Skipped in '$bfile' run #$brun mismatch."
          continue
        fi
        # Build the JSON for this run
        local run_json=""
        if [[ "$is_void_body" == "false" ]]; then
          # Only process fields for non-void-body files
          for (( i=0; i<nbps0; i++ )); do
            local key="${bps0[$i]}"
            local value="${bfields[$i]}"
            # Check if value is an array (enclosed in curly braces)
            if [[ "$value" =~ ^\{.*\}$ ]]; then
              # Extract the content between braces
              local array_content="${value:1:$((${#value}-2))}"
              # Split by ", " to get array elements
              IFS=', ' read -ra array_elements <<< "$array_content"
              if [[ -n "$run_json" ]]; then
                run_json+=",\n"
              fi
              # Start JSON array
              run_json+="            \"$key\": ["
              local first_element=true
              for element in "${array_elements[@]}"; do
                # Add comma separator if not the first element
                if ! $first_element; then
                  run_json+=", "
                else
                  first_element=false
                fi
                # Check if element is numeric
                if is_numeric "$element"; then
                  run_json+="$element"
                else
                  # Escape quotes in string values
                  element="${element//\"/\\\"}"
                  run_json+="\"$element\""
                fi
              done
              # Close JSON array
              run_json+="]"
            # Regular non-array value handling
            elif is_numeric "$value"; then
              if [[ -n "$run_json" ]]; then
                run_json+=",\n"
              fi
              run_json+="            \"$key\": $value"
            else
              # Escape quotes in string values
              value="${value//\"/\\\"}"
              if [[ -n "$run_json" ]]; then
                run_json+=",\n"
              fi
              run_json+="            \"$key\": \"$value\""
            fi
          done
        fi
        # Store the run data
        backg_data["$cleanFile:$chartPrefix:$brun"]="$run_json"
      fi
      # Add sub-backgrounds to the queue if they exist
      if [[ -n "$bb0" ]]; then
        IFS='|' read -ra bbs0 <<< "$bb0"
        for bval in "${bbs0[@]}"; do
          local subFile="${bval%%:*}"
          [[ "$subFile" != *.fps ]] && subFile="${subFile}.fps"
          local subRun=1 # Default run
          local processAllRuns=false
          if [[ "$bval" == *":"* ]]; then
            subRun="${bval##*:}"
            # Check if this is a condition-based selector (enclosed in double quotes)
            if [[ "$subRun" =~ ^\".*\"$ ]]; then
              # Extract the condition from the quotes
              local subConditionSelector="${subRun:1:$((${#subRun}-2))}"
              echo "$0: Processing condition-based sub-background selector: $subConditionSelector for $subFile"
              # Get matching run numbers using fps_sift
              if [[ -f "$subFile" ]]; then
                local sub_matching_runs=$(fps_sift "$subFile" "$subConditionSelector" "array")
                if [[ -z "$sub_matching_runs" ]]; then
                  echo "$0: No runs in '$subFile' match the condition: $subConditionSelector"
                  continue
                fi
                echo "$0: Matched runs in '$subFile': $sub_matching_runs"
                # Add each matching run to the queue
                IFS=',' read -ra sub_run_arr <<< "$sub_matching_runs"
                for r in "${sub_run_arr[@]}"; do
                  queue+=("${subFile}:${r}")
                done
              else
                echo "$0: Skipped background '$subFile' not accessed as a file."
              fi
              continue
            elif [[ "$subRun" == "0" ]]; then
              # Special case: process all runs in the file
              processAllRuns=true
            elif ! [[ "$subRun" =~ ^[0-9]+$ ]]; then
              echo "$0: Skipped background '$bval' invalid run number '$subRun'."
              continue
            fi
          else
            # No run specified (like "b0") - treat as "process all runs"
            processAllRuns=true
          fi
          if $processAllRuns; then
            # Process all runs in the file
            if [[ ! -f "$subFile" ]]; then
              echo "$0: Skipped background '$subFile' not accessed as a file."
              continue
            fi
            # Check if the sub-file is a void-body file
            local subHeader=$(head -n 1 "$subFile")
            local subChart=$(echo "$subHeader" | awk -F'[|][|]' '{print $1}') # chart
            local subBackg=$(echo "$subHeader" | awk -F'[|][|]' '{print $3}') # backg
            local is_sub_void_body=false
            if [[ "$subChart" == "-" ]]; then
              is_sub_void_body=true
            fi
            # Count the number of lines (runs) in the file, excluding the header
            local subRunCount=$(wc -l < "$subFile")
            ((subRunCount--)) # Subtract 1 for the header line
            # If the file is void-body but has background references, add a dummy run
            if [[ $subRunCount -eq 0 && -n "$subBackg" ]]; then
              queue+=("${subFile}:1")
            elif [[ $subRunCount -gt 0 ]]; then
              # Add each run to the queue
              for ((r=1; r<=subRunCount; r++)); do
                queue+=("${subFile}:${r}")
              done
            fi
          else
            # Process the single specified run
            queue+=("${subFile}:${subRun}")
          fi
        done
      fi
    done
    # Now build the background JSON from the collected data
    local first_file=true
    # Iterate through files
    for bfile in "${!backg_files[@]}"; do
      if ! $first_file; then
        json+=","
      else
        first_file=false
      fi
      json+="\n    \"$bfile\": {"
      local first_chart=true
      # Iterate through charts for this file
      for chart_key in "${!backg_charts[@]}"; do
        local file_part="${chart_key%%:*}"
        local chart_part="${chart_key##*:}"
        # Only process if this chart belongs to the current file
        if [[ "$file_part" == "$bfile" ]]; then
          if ! $first_chart; then
            json+=","
          else
            first_chart=false
          fi
          json+="\n      \"$chart_part\": {"
          json+="\n        \"_run\": {"
          local first_run=true
          # Find all runs for this file and chart
          for data_key in "${!backg_data[@]}"; do
            local dk_file="${data_key%%:*}"
            local remainder="${data_key#*:}"
            local dk_chart="${remainder%%:*}"
            local dk_run="${remainder##*:}"
            # Only process if this run belongs to the current file and chart
            if [[ "$dk_file" == "$bfile" && "$dk_chart" == "$chart_part" ]]; then
              if ! $first_run; then
                json+=","
              else
                first_run=false
              fi
              json+="\n          \"$dk_run\": {\n${backg_data[$data_key]}\n          }"
            fi
          done
          json+="\n        }"
          json+="\n      }"
        fi
      done
      json+="\n    }"
    done
    # Close _backg section
    json+="\n  }"
  fi
  # Close the JSON
  json+="\n}"
  # Write the JSON to file with proper formatting
  echo -e "$json" > "$out_file"
  echo "$0: Converted '$file' to '$out_file'"
}

fps_jfps() {
  local json_file="$1"
  if [[ ! -f "$json_file" || "$json_file" != *.json ]]; then
    echo "$0: FPS induced JSON '$json_file' not found."
    exit 1
  fi
  local fields=""
  local set_name=$(grep -o '"_set": *"[^"]*"' "$json_file" | head -1 | sed 's/"_set": *"\([^"]*\)"/\1/')
  local key_name=$(grep -o '"_key": *"[^"]*"' "$json_file" | head -1 | sed 's/"_key": *"\([^"]*\)"/\1/')
  if [[ -z "$set_name" || -z "$key_name" ]]; then
    echo "$0: Could not extract _set or _key from FPS-induced JSON."
    exit 1
  fi
  local out_file="${set_name}.fps"
  extract_backgrounds_from_json() {
    local json_file="$1"
    local bg_refs=""
    if grep -q '"_backg":' "$json_file"; then
      local bg_section=$(sed -n '/"_backg": *{/,/^  }/p' "$json_file")
      local bg_files=$(echo "$bg_section" | grep -o '"[^"]*": *{' | grep -v "_backg" | sed 's/": *{//g; s/"//g')
      declare -A bg_runs_map
      for bg_file in $bg_files; do
        local bg_file_section=$(echo "$bg_section" | sed -n "/\"$bg_file\": *{/,/^    }/p")
        local nested_sections=$(echo "$bg_file_section" | grep -o '"[^"]*": *{' | sed 's/": *{//g; s/"//g')
        for nested_obj in $nested_sections; do
          [[ "$nested_obj" == "$bg_file" ]] && continue # Skip the background file itself
          local nested_section=$(echo "$bg_file_section" | sed -n "/\"$nested_obj\": *{/,/^      }/p")
          if echo "$nested_section" | grep -q '"_run": *{'; then
            local run_section=$(echo "$nested_section" | sed -n '/"_run": *{/,/^        }/p')
            local runs=$(echo "$run_section" | grep -o '"[0-9]\+": *{' | sed 's/": *{//g; s/"//g' | sort -n)
            if [[ -n "$runs" ]]; then
              [[ -z "${bg_runs_map[$bg_file]}" ]] && bg_runs_map[$bg_file]=""
              for run in $runs; do
                bg_runs_map[$bg_file]="${bg_runs_map[$bg_file]} $run"
              done
            fi
          fi
        done
      done
      for bg_file in "${!bg_runs_map[@]}"; do # Now format the background references
        local sorted_runs=$(echo "${bg_runs_map[$bg_file]}" | tr ' ' '\n' | sort -n | uniq | tr '\n' ' ')
        [[ -z "$sorted_runs" ]] && continue # Skip if no runs
        # Format runs with ranges
        local formatted_runs=""
        local prev_run=""
        local range_start=""
        local in_range=false
        for run in $sorted_runs; do
          [[ -z "$run" ]] && continue # Skip empty runs
          if [[ -z "$prev_run" ]]; then
            range_start="$run"
            prev_run="$run"
          elif [[ $((run - prev_run)) -eq 1 ]]; then
            in_range=true
            prev_run="$run"
          else
            # Non-adjacent run - end previous range if any
            if $in_range; then
              if [[ $((prev_run - range_start)) -ge 2 ]]; then
                # Range of at least 3 numbers
                formatted_runs="${formatted_runs:+$formatted_runs,}${range_start}-${prev_run}"
              else
                # Just two numbers, list them individually
                formatted_runs="${formatted_runs:+$formatted_runs,}${range_start},${prev_run}"
              fi
            else
              # Single number
              formatted_runs="${formatted_runs:+$formatted_runs,}${range_start}"
            fi
            # Start new potential range
            range_start="$run"
            prev_run="$run"
            in_range=false
          fi
        done
        # Handle the last run or range
        if $in_range; then
          if [[ $((prev_run - range_start)) -ge 2 ]]; then
            # Range of at least 3 numbers
            formatted_runs="${formatted_runs:+$formatted_runs,}${range_start}-${prev_run}"
          else
            # Just two numbers, list them individually
            formatted_runs="${formatted_runs:+$formatted_runs,}${range_start},${prev_run}"
          fi
        else
          # Single number
          formatted_runs="${formatted_runs:+$formatted_runs,}${range_start}"
        fi
        bg_refs="${bg_refs:+$bg_refs|}${bg_file}:${formatted_runs}"
      done
    fi
    echo "$bg_refs"
  }
  local chart_run_section=""
  local start_line=$(grep -n '"_run": *{' "$json_file" | head -1 | cut -d: -f1)
  if [[ -z "$start_line" ]]; then
    echo "$0: Error: Could not find _run section in JSON."
    exit 1
  fi
  local brace_count=0
  local in_run_section=false
  local line_num=0
  while IFS= read -r line; do
    ((line_num++))
    if [[ $line_num -eq $start_line ]]; then
      in_run_section=true
      chart_run_section+="$line"$'\n'
      # Count opening braces
      brace_count=$((brace_count + $(echo "$line" | grep -o '{' | wc -l)))
      # Count closing braces
      brace_count=$((brace_count - $(echo "$line" | grep -o '}' | wc -l)))
    elif [[ $in_run_section = true ]]; then
      chart_run_section+="$line"$'\n'
      # Count opening braces
      brace_count=$((brace_count + $(echo "$line" | grep -o '{' | wc -l)))
      # Count closing braces
      brace_count=$((brace_count - $(echo "$line" | grep -o '}' | wc -l)))
      # If we're back to brace level 0, we've found the end of the run section
      if [[ $brace_count -eq 0 ]]; then
        break
      fi
    fi
  done < "$json_file"
  # Extract all run numbers from the chart run section
  local run_keys=$(echo "$chart_run_section" | grep -o '"[0-9]\+": *{' | sed 's/": *{//g; s/"//g' | sort -n)
  if [[ -z "$run_keys" ]]; then
    fields="-"
  else
    local first_run=$(echo "$run_keys" | head -1)
    local first_run_block=""
    local capture=false
    # Extract the first run block using pattern matching
    while IFS= read -r line; do
      if [[ "$line" =~ \"$first_run\":\ *\{ ]]; then
        capture=true
        first_run_block+="$line"$'\n'
      elif [[ $capture = true ]]; then
        first_run_block+="$line"$'\n'
        if [[ "$line" =~ \}, ]]; then
          break
        fi
      fi
    done < <(echo "$chart_run_section")
    # Extract field names from the first run block
    while IFS= read -r line; do
      if [[ "$line" =~ \"([a-zA-Z][^\"]*)\": ]]; then
        local field="${BASH_REMATCH[1]}"
        if [[ "$field" != "_run" && "$field" != "_set" && "$field" != "_key" ]]; then
          fields="${fields:+$fields|}$field"
        fi
      fi
    done < <(echo "$first_run_block")
  fi
  local bg_refs=""
  if [[ -f "$out_file" ]]; then # Original FPS file exists
    cp "$out_file" "${out_file}_jtmp"
    local orig_header=$(head -1 "$out_file")
    local orig_fields=$(echo "$orig_header" | awk -F'[|][|]' '{print $1}')
    local orig_key=$(echo "$orig_header" | awk -F'[|][|]' '{print $2}')
    local orig_bg=$(echo "$orig_header" | awk -F'[|][|]' '{print $3}')
    # If fields and key match, reuse the original background references
    if [[ "$fields" == "$orig_fields" && "$key_name" == "$orig_key" ]]; then
      bg_refs="$orig_bg"
      echo "$0: Reusing background references from original FPS file."
    else
      bg_refs=$(extract_backgrounds_from_json "$json_file")
    fi
  else
    bg_refs=$(extract_backgrounds_from_json "$json_file")
  fi
  echo "${fields}||${key_name}||${bg_refs}" > "$out_file"
  IFS='|' read -ra field_names <<< "$fields"
  local max_run=$(echo "$run_keys" | sort -n | tail -1)
  for run_num in $(seq 1 $max_run); do
    if echo "$run_keys" | grep -q "^$run_num$"; then
      local run_block=""
      local capture=false
      while IFS= read -r line; do
        if [[ "$line" =~ \"$run_num\":\ *\{ ]]; then
          capture=true
          run_block+="$line"$'\n'
        elif [[ $capture = true ]]; then
          run_block+="$line"$'\n'
          if [[ "$line" =~ \}, ]]; then
            break
          fi
        fi
      done < <(echo "$chart_run_section")
      local line_values=""
      for field in "${field_names[@]}"; do
        local value=""
        # Match string values with content between quotes - preserving escaped quotes
        if grep -q "\"$field\": *\"" <(echo "$run_block"); then
          # Extract everything between the quotes, handling escaped quotes properly
          local quoted_section=$(echo "$run_block" | grep "\"$field\": *\"")
          # Extract what's inside the quotes, preserving escaped quotes
          if [[ "$quoted_section" =~ \"$field\":\ *\"(([^\"]|\\\")*[^\\])\" ]]; then
            value="${BASH_REMATCH[1]}"
            # Preserve escaped quotes in the output
            value="${value//\\\"/\"}"
          fi
        # Match array values - both string and numeric arrays
        elif grep -q "\"$field\": *\[" <(echo "$run_block"); then
          local array_line=$(echo "$run_block" | grep "\"$field\": *\[")
          # Check if the entire array is on one line
          if [[ "$array_line" =~ \"$field\":\ *\[(.*)\] ]]; then
            # Single line array
            value="{${BASH_REMATCH[1]}}"
          else
            # Multi-line array - extract all lines until closing bracket
            local array_content=""
            local array_started=false
            local array_ended=false
            while IFS= read -r line; do
              if [[ "$line" =~ \"$field\":\ *\[ ]]; then
                array_started=true
                # Extract any content after the opening bracket
                if [[ "$line" =~ \"$field\":\ *\[(.*) ]]; then
                  array_content+="${BASH_REMATCH[1]}"
                fi
              elif [[ "$array_started" = true && "$array_ended" = false ]]; then
                if [[ "$line" =~ .*\] ]]; then
                  # Found the closing bracket
                  array_ended=true
                  # Extract content before the closing bracket
                  if [[ "$line" =~ (.*)\] ]]; then
                    array_content+="${BASH_REMATCH[1]}"
                  fi
                else
                  # Middle of array - add the whole line
                  array_content+="$line"
                fi
              fi
              # Stop if we've found the entire array
              [[ "$array_ended" = true ]] && break
            done < <(echo "$run_block")
            # Clean up the array content
            array_content=$(echo "$array_content" | sed 's/^[[:space:]]*//g; s/[[:space:]]*$//g')
            value="{$array_content}" # Format the value
          fi
          # Remove unnecessary quotes around string values in arrays
          value=$(echo "$value" | sed 's/"//g')
        # Match numeric values
        elif grep -q "\"$field\": *[0-9]" <(echo "$run_block"); then
          value=$(echo "$run_block" | grep "\"$field\": *[0-9]" | sed 's/.*": *\([0-9][0-9]*\).*/\1/')
        # Match dashes and other special values
        elif grep -q "\"$field\": *-" <(echo "$run_block"); then
          value="-"
        fi
        value="${value//|/\\|}" # Escape pipe characters
        line_values="${line_values}${value}|"
      done
      line_values="${line_values%|}"
      echo "$line_values" >> "$out_file"
    else
      if [[ -f "${out_file}_jtmp" ]]; then
        local orig_line=$(tail -n +$((run_num + 1)) "${out_file}_jtmp" | head -n 1)
        if [[ -n "$orig_line" ]]; then
          echo "$orig_line" >> "$out_file"
        else
          echo "" >> "$out_file" # Add empty line
        fi
      else
        echo "" >> "$out_file" # Add empty line for missing runs if no original file
      fi
    fi
  done
  [[ -f "${out_file}_jtmp" ]] && rm "${out_file}_jtmp"
  echo "$0: Updated '$out_file' from '$json_file'"
}

fps_flat() {
  local json_file="$1"
  if [[ ! -f "$json_file" || "$json_file" != *.json ]]; then
    echo "$0: Error: '$json_file' is not a valid JSON file." >&2
    return 1
  fi
  echo "$0: Flattening '$json_file' to FPS format..." >&2
  local base_filename="${json_file%.json}"
  local main_fps="${base_filename}_.fps"
  created_files=()
  # Function to clean up created files in case of an error
  cleanup() {
    echo "$0: Cleaning up..." >&2
    for file in "${created_files[@]}"; do
      if [[ -f "$file" ]]; then
        rm -f "$file"
      fi
    done
    exit 1
  }
  # Set trap for ctrl-c and errors
  trap cleanup SIGINT SIGTERM ERR
  # Function to process a nested object into an FPS file
  process_nested_object() {
    local src_json="$1"     # Source JSON file
    local json_path="$2"    # JSON path for jq
    local fps_prefix="$3"   # Prefix for the FPS filename
    local object_name="$4"  # Name of this object
    # Create FPS file for this object
    local object_fps="${fps_prefix}.fps"
    local object_keys=$(jq -r "$json_path | keys[]" "$src_json" 2>/dev/null || echo "")
    local object_header=""
    local object_body=""
    local object_backgrounds=""
    local object_has_values=false
    # Process each key in this object
    for obj_key in $object_keys; do
      local obj_type=$(jq -r "$json_path.\"$obj_key\" | type" "$src_json")
      if [[ "$obj_type" == "string" || "$obj_type" == "number" || "$obj_type" == "boolean" ]]; then
        # Direct value
        object_has_values=true
        object_header+="${obj_key}|"
        # Get the value
        local obj_value=$(jq -r "$json_path.\"$obj_key\"" "$src_json")
        # Escape special chars
        obj_value="${obj_value//\\/\\\\}"
        obj_value="${obj_value//|/\\|}"
        object_body+="${obj_value}|"
      elif [[ "$obj_type" == "array" && $(jq -r "$json_path.\"$obj_key\" | map(type) | map(. == \"object\") | any" "$src_json") == "true" ]]; then
        # Array of objects
        [[ -n "$object_backgrounds" ]] && object_backgrounds+="|"
        object_backgrounds+="${fps_prefix}_${obj_key}"
        # Process this nested array
        process_nested_array "$src_json" "$json_path.\"$obj_key\"" "${fps_prefix}_${obj_key}" "${obj_key}"
      elif [[ "$obj_type" == "array" ]]; then
        # Array of primitives
        object_has_values=true
        object_header+="${obj_key}|"
        # Format array values
        local arr_values=$(jq -r "$json_path.\"$obj_key\"[]" "$src_json" 2>/dev/null || echo "")
        local fmt_array="{"
        local first_val=true
        while read -r arr_val; do
          if [[ -n "$arr_val" ]]; then
            if ! $first_val; then
              fmt_array+=", "
            else
              first_val=false
            fi
            # Escape special chars
            arr_val="${arr_val//\\/\\\\}"
            arr_val="${arr_val//|/\\|}"
            fmt_array+="$arr_val"
          fi
        done <<< "$arr_values"
        fmt_array+="}"
        object_body+="${fmt_array}|"
      elif [[ "$obj_type" == "object" ]]; then
        # Nested object
        [[ -n "$object_backgrounds" ]] && object_backgrounds+="|"
        object_backgrounds+="${fps_prefix}_${obj_key}"
        # Process this nested object recursively
        process_nested_object "$src_json" "$json_path.\"$obj_key\"" "${fps_prefix}_${obj_key}" "${obj_key}"
      fi
    done
    # Remove trailing pipes
    object_header="${object_header%|}"
    object_body="${object_body%|}"
    # Write the object FPS file
    if [[ "$object_has_values" == "true" ]]; then
      echo "${object_header}||${object_name}||${object_backgrounds}" > "$object_fps"
      if [[ -n "$object_body" ]]; then
        echo "${object_body}" >> "$object_fps"
      fi
    else
      echo "-||${object_name}||${object_backgrounds}" > "$object_fps"
    fi
    created_files+=("$object_fps")
    echo "$0: Created '$object_fps'" >&2
  }
  # Function to process a nested array of objects and return the formatted array value for inclusion in parent
  process_nested_array() {
    local src_json="$1"     # Source JSON file
    local json_path="$2"    # JSON path for jq
    local fps_prefix="$3"   # Prefix for the FPS filename
    local array_name="$4"   # Name of this array
    # Create FPS files for array elements
    local array_size=$(jq -r "$json_path | length" "$src_json")
    local formatted_array=""
    local array_backgrounds=""
    # Process each array element into its own file
    local i
    for ((i=0; i<array_size; i++)); do
      local elem_type=$(jq -r "$json_path[$i] | type" "$src_json")
      if [[ "$elem_type" == "object" ]]; then
        # Process this object element
        local element_fps="${fps_prefix}_${i}.fps"
        local element_keys=$(jq -r "$json_path[$i] | keys[]" "$src_json" 2>/dev/null || echo "")
        local element_header=""
        local element_body=""
        local element_backgrounds=""
        local element_has_values=false
        # Process each key in this element
        for element_key in $element_keys; do
          local element_type=$(jq -r "$json_path[$i].\"$element_key\" | type" "$src_json")
          if [[ "$element_type" == "string" || "$element_type" == "number" || "$element_type" == "boolean" ]]; then
            # Direct value
            element_has_values=true
            element_header+="${element_key}|"
            # Get the value
            local element_value=$(jq -r "$json_path[$i].\"$element_key\"" "$src_json")
            # Escape special chars
            element_value="${element_value//\\/\\\\}"
            element_value="${element_value//|/\\|}"
            element_body+="${element_value}|"
          elif [[ "$element_type" == "array" && $(jq -r "$json_path[$i].\"$element_key\" | map(type) | map(. == \"object\") | any" "$src_json") == "true" ]]; then
            # Array of objects
            [[ -n "$element_backgrounds" ]] && element_backgrounds+="|"
            element_backgrounds+="${fps_prefix}_${i}_${element_key}"
            # Process this nested array recursively
            process_nested_array "$src_json" "$json_path[$i].\"$element_key\"" "${fps_prefix}_${i}_${element_key}" "${element_key}"
          elif [[ "$element_type" == "array" ]]; then
            # Array of primitives
            element_has_values=true
            element_header+="${element_key}|"
            # Format array values
            local arr_values=$(jq -r "$json_path[$i].\"$element_key\"[]" "$src_json" 2>/dev/null || echo "")
            local fmt_array="{"
            local first_val=true
            while read -r arr_val; do
              if [[ -n "$arr_val" ]]; then
                if ! $first_val; then
                  fmt_array+=", "
                else
                  first_val=false
                fi
                # Escape special chars
                arr_val="${arr_val//\\/\\\\}"
                arr_val="${arr_val//|/\\|}"
                fmt_array+="$arr_val"
              fi
            done <<< "$arr_values"
            fmt_array+="}"
            element_body+="${fmt_array}|"
          elif [[ "$element_type" == "object" ]]; then
            # Nested object
            [[ -n "$element_backgrounds" ]] && element_backgrounds+="|"
            element_backgrounds+="${fps_prefix}_${i}_${element_key}"
            # Process this nested object
            process_nested_object "$src_json" "$json_path[$i].\"$element_key\"" "${fps_prefix}_${i}_${element_key}" "${element_key}"
          fi
        done
        # Remove trailing pipes
        element_header="${element_header%|}"
        element_body="${element_body%|}"
        # Write the element file
        local element_id="#${i}"
        if [[ "$element_has_values" == "true" ]]; then
          echo "${element_header}||${element_id}||${element_backgrounds}" > "$element_fps"
          if [[ -n "$element_body" ]]; then
            echo "${element_body}" >> "$element_fps"
          fi
        else
          echo "-||${element_id}||${element_backgrounds}" > "$element_fps"
        fi
        created_files+=("$element_fps")
        echo "$0: Created '$element_fps'" >&2
        # Add this element to the array's background references
        if [[ -n "$array_backgrounds" ]]; then
          array_backgrounds+="|"
        fi
        # IMPORTANT FIX: Always use the current loop index i to construct the reference
        local correct_reference="${fps_prefix}_${i}"
        array_backgrounds+="$correct_reference"
        # Add to the formatted array
        if [[ -n "$formatted_array" ]]; then
          formatted_array+=", "
        fi
        formatted_array+="${element_id}"
      fi
    done
    # Create a container file for the array with background references to all elements
    local array_container="${fps_prefix}.fps"
    echo "-||${array_name}||${array_backgrounds}" > "$array_container"
    created_files+=("$array_container")
    echo "$0: Created '$array_container'" >&2
    # Wrap the formatted array with braces for return
    if [[ -n "$formatted_array" ]]; then
      echo "{$formatted_array}"
    else
      echo "{}"
    fi
  }
  # Create the main FPS file first
  local main_keys=$(jq -r "keys[]" "$json_file" 2>/dev/null || echo "")
  local main_header=""
  local main_body=""
  local main_backgrounds=""
  local has_direct_values=false
  # Identify top-level direct key-value pairs for main file
  for key in $main_keys; do
    local value_type=$(jq -r ".\"$key\" | type" "$json_file")
    if [[ "$value_type" == "string" || "$value_type" == "number" || "$value_type" == "boolean" ]]; then
      # Direct value - add to header and body
      has_direct_values=true
      main_header+="${key}|"
      # Get the value
      local value=$(jq -r ".\"$key\"" "$json_file")
      main_body+="${value}|"
    elif [[ "$value_type" == "array" && $(jq -r ".\"$key\" | map(type) | map(. == \"object\") | any" "$json_file") == "true" ]]; then
      process_nested_array "$json_file" ".\"$key\"" "${base_filename}_${key}" "${key}" > /dev/null
      # Add as background for nested files
      [[ -n "$main_backgrounds" ]] && main_backgrounds+="|"
      main_backgrounds+="${base_filename}_${key}"
    elif [[ "$value_type" == "array" ]]; then
      # Array of primitives - add as formatted value
      has_direct_values=true
      main_header+="${key}|"
      # Get array values
      local array_values=$(jq -r ".\"$key\"[]" "$json_file" 2>/dev/null || echo "")
      local formatted_array="{"
      local first=true
      while read -r val; do
        if [[ -n "$val" ]]; then
          if ! $first; then
            formatted_array+=", "
          else
            first=false
          fi
          # Escape special chars
          val="${val//\\/\\\\}"
          val="${val//|/\\|}"
          formatted_array+="$val"
        fi
      done <<< "$array_values"
      formatted_array+="}"
      main_body+="${formatted_array}|"
    elif [[ "$value_type" == "object" ]]; then
      # Object - add as background
      [[ -n "$main_backgrounds" ]] && main_backgrounds+="|"
      main_backgrounds+="${base_filename}_${key}"
    fi
  done
  # Remove trailing pipes
  main_header="${main_header%|}"
  main_body="${main_body%|}"
  # Write the main FPS file
  local root_name=$(basename "$base_filename")
  if [[ "$has_direct_values" == "true" ]]; then
    echo "${main_header}||${root_name}||${main_backgrounds}" > "$main_fps"
    if [[ -n "$main_body" ]]; then
      echo "${main_body}" >> "$main_fps"
    fi
  else
    echo "-||${root_name}||${main_backgrounds}" > "$main_fps"
  fi
  created_files+=("$main_fps")
  echo "$0: Created '$main_fps'" >&2
  # Process non-array nested objects at the top level
  for key in $main_keys; do
    local value_type=$(jq -r ".\"$key\" | type" "$json_file")
    if [[ "$value_type" == "object" ]]; then
      # Process nested objects at the top level
      process_nested_object "$json_file" ".\"$key\"" "${base_filename}_${key}" "${key}"
    fi
  done
  echo "$0: Successfully flattened '$json_file' to FPS format" >&2
  echo "$0: Main file: '${main_fps}'" >&2
  trap - EXIT
  return 0
}

### Main
if [[ $# -lt 1 ]]; then
  echo "Usage:"
  echo "$0 inst                                 # install"
  echo "$0 uninst                               # uninstall"
  echo "$0 keys x.fps                           # list keys"
  echo "$0 draw x.fps                           # draw align -> @.fps"
  echo "$0 norm x.fps                           # normalize -> prere.fps"
  echo "$0 json x.fps                           # convert fps to json -> .json"
  echo "$0 jfps x.json                          # convert json back to -> .fps"
  echo "$0 flat x.json                          # convert json to fps -> _.fps"
  echo "$0 stat x.fps Key                       # show stat of a key -> @.stat"
  echo "$0 find x.fps Word                      # search for a word in prere/chart"
  echo "$0 sift x.fps Condition                 # sift with condition -> #hash.fps"
  echo "$0 sort x.fps Key 1/+ or 2/-            # sort key ascend/descend -> @.fps"
  echo "$0 merge out0.fps in1.fps ...           # merge same key set and normalize"
  echo "$0 ELF/.sh/.py x.fps[:0=pll|:N=run] ... # run script with environment vars"
  echo "$0 ELF/.sh/.py x.fps:-,\"a > 2\"          # run script with condition sifter"
  exit 0
fi

case "$1" in
  "inst")
    fps_inst
    ;;
  "uninst")
    fps_uninst
    ;;
  "keys")
    [[ $# -ne 2 ]] && { echo "$0: '$1' requires = 2 args"; exit 1; }
    fps_keys "$2"
    ;;
  "draw")
    [[ $# -ne 2 ]] && { echo "$0: '$1' requires = 2 args"; exit 1; }
    fps_draw "$2"
    ;;
  "norm")
    [[ $# -ne 2 ]] && { echo "$0: '$1' requires = 2 args"; exit 1; }
    fps_norm "$2"
    ;;
  "json")
    [[ $# -lt 2 ]] && { echo "$0: '$1' requires at least 1 input file"; exit 1; }
    shift 1
    for file_arg in "$@"; do
      fps_json "$file_arg"
    done
    ;;
  "jfps")
    [[ $# -lt 2 ]] && { echo "$0: '$1' requires at least 1 input file"; exit 1; }
    shift 1
    for file_arg in "$@"; do
      fps_jfps "$file_arg"
    done
    ;;
  "flat")
    [[ $# -lt 2 ]] && { echo "$0: '$1' requires at least 1 input file"; exit 1; }
    shift 1
    for file_arg in "$@"; do
      fps_flat "$file_arg"
    done
    ;;
  "stat")
    [[ $# -ne 3 ]] && { echo "$0: '$1' requires = 3 args"; exit 1; }
    fps_stat "$2" "$3"
    ;;
  "find")
    [[ $# -ne 3 ]] && { echo "$0: '$1' requires = 3 args"; exit 1; }
    fps_find "$2" "$3"
    ;;
  "sift")
    [[ $# -ne 3 ]] && { echo "$0: '$1' requires = 3 args"; exit 1; }
    fps_sift "$2" "$3"
    ;;
  "sort")
    [[ $# -ne 4 ]] && { echo "$0: '$1' requires = 4 args"; exit 1; }
    fps_sort_key "$2" "$3" "$4"
    ;;
  "merge")
    [[ $# -lt 4 ]] && { echo "$0: '$1' requires >= 4 args"; exit 1; }
    merge_out="$2"
    shift 2
    fps_merge_set "$merge_out" "$@"
    ;;
  *) # run $1 a ELF or .sh or .py script
    [[ $# -lt 2 ]] && { echo "$0: run requires >= 2 args for ELF/.sh/.py x.fps[:0=pll|:N=run] ..."; exit 1; }
    # Usage information for run modes:
    # 1. Simple run: script.sh file.fps                                     - Run sequentially all rows
    # 2. Single run: script.sh file.fps:5                                   - Run only row #5
    # 3. Multiple runs: script.sh file.fps:1,3,5-7                          - Run rows 1,3,5,6,7 sequentially
    # 4. Parallel run: script.sh file.fps:0,1,3,5-7                         - Run rows 1,3,5,6,7 in parallel, wait for all to finish
    # 5. Parallel mix: script.sh file.fps:-,1,3,5-7                         - Run rows 1,3,5,6,7 in parallel, continue without waiting
    # 6. Condition-based: script.sh file.fps:"version == '1.0' && tier > 2" - Run rows matching the condition sequentially
    # 7. Parallel condition: script.sh file.fps:0,"version == '1.0'"        - Run matching rows in parallel, wait for all
    # 8. Parallel mix condition: script.sh file.fps:-,"version == '1.0'"    - Run matching rows in parallel, continue without waiting
    # 9. Script with arguments: script.sh:"arg1 \"arg2\" arg3" file.fps     - Pass arguments to the script
    local_script="$1"
    local_script_args=""
    if [[ "$local_script" == *:* ]]; then
      local_script_args="${local_script#*:}"
      local_script="${local_script%%:*}"
      # Remove surrounding quotes if present
      if [[ "$local_script_args" =~ ^\".*\"$ && ${#local_script_args} -gt 2 ]]; then
        local_script_args="${local_script_args#\"}"
        local_script_args="${local_script_args%\"}"
      fi
      local_script_args="${local_script_args//\\\"/\"}" # Remove escaped quotes
    fi
    if [[ -n "$local_script_args" ]]; then
      FPS_RUN_ARGS="$local_script_args"
    else
      FPS_RUN_ARGS=""
    fi
    fin0=0
    exe0=0
    if [[ -x "$local_script" ]] && file "$local_script" | grep -q "ELF"; then
      exe0=1
    fi
    if [[ $exe0 -eq 1
      || "$local_script" == *.sh
      || "$local_script" == *.py
    ]]; then
      shift 1
      expand_range() { # "11-14" -> (11 12 13 14)
        term="$1"
        if [[ "$term" == "-" ]]; then
          echo "$term"
        elif [[ "$term" == *-* ]]; then
          IFS='-' read -r start end <<< "$term"
          seq "$start" "$end"
        else
          echo "$term"
        fi
      }
      for farg in "$@"; do
        echo "--------------------"
        if [[ "$farg" == *:* ]]; then
          local_fps="${farg%%:*}"
          local_sel="${farg##*:}"
        else
          local_fps="$farg"
          local_sel=""
        fi
        [[ ! -f "$local_fps" ]] && { echo "$0: Info '$local_fps' not accessed."; continue; }
        [[ "$local_fps" != *.fps ]] && { echo "$0: Info '$local_fps' not .fps file."; continue; }
        # condition-based selector
        if [[ "$local_sel" =~ (==|!=|>=|<=|>|<) ]]; then
          echo "$0: Processing condition-based selector: $local_sel"
          local_parallel_mode=""
          if [[ "$local_sel" == "0,"* ]]; then
            local_parallel_mode="wait"
            local_sel="${local_sel#0,}"
            echo "$0: Using parallel execution with wait"
          elif [[ "$local_sel" == "-,"* ]]; then
            local_parallel_mode="mix"
            local_sel="${local_sel#-,}"
            echo "$0: Using parallel execution without wait"
          fi
          local_matching_runs=$(fps_sift "$local_fps" "$local_sel" "array")
          if [[ -z "$local_matching_runs" ]]; then
            echo "$0: No runs match the condition: $local_sel"
            continue
          fi
          echo "$0: Matched runs: $local_matching_runs"
          IFS=',' read -ra sel_arr <<< "$local_matching_runs"
          if [[ "$local_parallel_mode" == "wait" ]]; then # parallel then wait
            for s in "${sel_arr[@]}"; do
              fps_run_script "$local_script" "$local_fps" "$s" &
            done
            wait
          elif [[ "$local_parallel_mode" == "mix" ]]; then # parallel mix run
            for s in "${sel_arr[@]}"; do
              fps_run_script "$local_script" "$local_fps" "$s" &
            done
            fin0=1
          else # sequential
            for s in "${sel_arr[@]}"; do
              fps_run_script "$local_script" "$local_fps" "$s"
            done
          fi
        # comma in selector for explicit run numbers or special modes
        elif [[ "$local_sel" == *","* ]]; then
          IFS=',' read -ra sel_arr <<< "$local_sel"
          if [[ "${sel_arr[0]}" == "0" ]]; then # parallel then wait
            for term in "${sel_arr[@]:1}"; do
              for s in $( expand_range "$term" ); do
                fps_run_script "$local_script" "$local_fps" "$s" &
              done
            done
            wait
          elif [[ "${sel_arr[0]}" == "-" ]]; then # parallel mix run
            for term in "${sel_arr[@]:1}"; do
              for s in $( expand_range "$term" ); do
                fps_run_script "$local_script" "$local_fps" "$s" &
              done
            done
            fin0=1
          else # sequential
            for term in "${sel_arr[@]}"; do
              for s in $( expand_range "$term" ); do
                fps_run_script "$local_script" "$local_fps" "$s"
              done
            done
          fi
        # no comma in selector
        else
          if [[ -z "$local_sel" ]]; then
            fps_run_script "$local_script" "$local_fps" ""
          else
            for s in $( expand_range "$local_sel" ); do
              fps_run_script "$local_script" "$local_fps" "$s" # 0 = then wait; - = mix run
            done
          fi
        fi
      done
    else
      echo "$0: Unrecognized command or script '$1'."
      exit 1
    fi
    unset FPS_RUN_ARGS
    [[ $fin0 -eq 1 ]] && wait
    exit 0
    ;;
esac
