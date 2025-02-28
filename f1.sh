#!/bin/bash

# shc -f f1.sh -o f1 -H

## fps a3func2build.sh m45.fps:0 m100.fps:0,1-4 m100.fps:5 m100.fps:6-8 m100.fps:0,10,12 m100.fps:-,13,14 m283.fps:-

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
    opts="inst uninst keys draw norm stat find sift sort merge"
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
  done < <( { tail -n +2 "$file"; [[ $SYST -gt 1 && "$(tail -c 1 "$file")" != $'\n' ]] && printf "\n"; } )
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
  done < <( { tail -n +2 "$file"; [[ $SYST -gt 1 && "$(tail -c 1 "$file")" != $'\n' ]] && printf "\n"; } )
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
  local key op val
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
    if ! is_numeric "$val"; then
      echo "$0: Sifting value '$val' not numeric in '$comp'."
      exit 1
    fi
    numericCols+=( "${colIndex[$key]}" )
  done
  # check chart colums numeric
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
  # "key op value" condition to awk
  local awkExpr="$filterString"
  for name in "${!colIndex[@]}"; do
    awkExpr="$(sed "s|\b${name}\b|\$${colIndex[$name]}|g" <<< "$awkExpr")"
  done
  # create sift output
  local hash0=$(echo -n "$awkExpr" | sha1sum | awk '{print substr($1,1,16)}')
  local outFile="${file%.fps}#${hash0}.fps"
  echo "$h0" > "$outFile"
  # awk condition go
  awk -F '|' '
    NR==1 { next } # skip header
    {
      if( '"$awkExpr"' )
        print
    }
  ' "$file" >> "$outFile"
  local siftCount=$(tail -n +2 "$outFile" | wc -l)
  echo "$0: With '$filterString'"
  echo "$0: i.e. '$awkExpr'"
  echo "$0: Sifted '$file' to '$outFile' #= $siftCount"
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
  done < <( { tail -n +2 "$file"; [[ $SYST -gt 1 && "$(tail -c 1 "$file")" != $'\n' ]] && printf "\n"; } )
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
    done < <( { tail -n +2 "${input_files[f1]}"; [[ $SYST -gt 1 && "$(tail -c 1 "${input_files[f1]}")" != $'\n' ]] && printf "\n"; } )
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
            if ! [[ "$subRun" =~ ^[0-9]+$ ]]; then
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
      ./"$script"
    elif [[ "$script" == *.py ]]; then
      local var0="$var0b"
      var0+="${c0}='${nl0}'; "
      for (( i0=0; i0<${#ps0[@]}; i0++ )); do
        var0+="${c0}${ps0[$i0]}='${rowArr[$i0]}'; "
      done
      python3 -c "import os; ${var0}exec(open('$script').read())"
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
        if ! [[ "$subRun" =~ ^[0-9]+$ ]]; then
          echo "$0: Skipped background '$bentry' invalid run number '$subRun'."
          continue
        fi
        _setup_bg_iterative "$subFile" "$subRun"
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
    done < <( { tail -n +2 "$file"; [[ $SYST -gt 1 && "$(tail -c 1 "$file")" != $'\n' ]] && printf "\n"; } )
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
    done < <( { tail -n +2 "$file"; [[ $SYST -gt 1 && "$(tail -c 1 "$file")" != $'\n' ]] && printf "\n"; } )
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
    done < <( { tail -n +2 "$file"; [[ $SYST -gt 1 && "$(tail -c 1 "$file")" != $'\n' ]] && printf "\n"; } )
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

### Main
if [[ $# -lt 1 ]]; then
  echo "Usage:"
  echo "$0 inst                                 # install"
  echo "$0 uninst                               # uninstall"
  echo "$0 keys x.fps                           # list keys"
  echo "$0 draw x.fps                           # draw align -> @.fps"
  echo "$0 norm x.fps                           # normalize -> prere.fps"
  echo "$0 stat x.fps Key                       # show stat of a key -> @.stat"
  echo "$0 find x.fps Word                      # search for a word in prere/chart"
  echo "$0 sift x.fps Condition                 # sift with condition -> #hash.fps"
  echo "$0 sort x.fps Key 1/+ or 2/-            # sort key ascend/descend -> @.fps"
  echo "$0 merge out0.fps in1.fps ...           # merge same key set and normalize"
  echo "$0 ELF/.sh/.py x.fps[:0=pll|:N=run] ... # run script with ordered variable"
  exit 0
fi

if [[ $(uname -s) == "Linux" ]]; then
  SYST=1
elif [[ $(uname -s) =~ MINGW|MSYS|CYGWIN ]]; then
  SYST=2
else
  SYST=3
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
    fin0=0
    exe0=0
    if [[ -x "$1" ]] && file "$1" | grep -q "ELF"; then
      exe0=1
    fi
    if [[ $exe0 -eq 1
      || "$1" == *.sh
      || "$1" == *.py
    ]]; then
      local_script="$1"
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
        # comma in selector
        if [[ "$local_sel" == *","* ]]; then
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
        else # no comma in selector
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
    [[ $fin0 -eq 1 ]] && wait
    exit 0
    ;;
esac
