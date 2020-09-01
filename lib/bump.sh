#!/usr/bin/env bash

bumpproject(){

  local generatortype licensetype genpath
  local projectdir="${1/'~'/$HOME}"
  local templatedir="$projectdir/bashbud"

  [[ -f "$projectdir/manifest.md" ]] \
    || ERX "$projectdir doesn't contain manifest.md"

  # prepend full path if dirname is relative
  [[ $projectdir =~ ^[^/] ]] \
    && projectdir="$PWD/$projectdir"

  # get generator and license type from manifest
  eval "$(awk '
    /^generator:/ {print "generatortype=" $2}
    /^license:/ {print "licensetype=" $2}
    /^[.]{3}$/ {exit}
    ' "$projectdir/manifest.md"
  )"

  [[ -f $BASHBUD_DIR/licenses/${licensetype:=X} ]] \
    && licensetemplate="$BASHBUD_DIR/licenses/$licensetype"

  
  # Find template DIR
  if [[ ! -d "$templatedir" ]]; then

    genpath="generators/${generatortype:=default}/__templates"
    
    if [[ -d "$BASHBUD_DIR/$genpath" ]]; then
      templatedir="$BASHBUD_DIR/$genpath"
    elif [[ -d "/usr/share/bashbud/$genpath" ]]; then
      templatedir="/usr/share/bashbud/$genpath"
    else
      ERX "could not locate generator: $generatortype"
    fi
  fi



  # execute any pre-apply script
  [[ -x "$templatedir/__pre-apply" ]] \
    && "$templatedir/__pre-apply" "$projectdir"

  # if __pre-apply.d dir exist, execute scripts
  if [[ -d "$templatedir/__pre-apply.d" ]]; then
    for f in $(getorder "$templatedir/__pre-apply.d"); do
      [[ -x "$f" ]] || continue
      "$f" "$projectdir"
    done
  fi


  # process manifest and templates
  setstream "$projectdir" "$templatedir" "${licensetemplate:-}" \
    | generate "$projectdir"

  # execute any post-apply script
  [[ -x "$templatedir/__post-apply" ]] \
    && "$templatedir/__post-apply" "$projectdir"

  # if __post-apply.d dir exist, execute scripts
  if [[ -d "$templatedir/__post-apply.d" ]]; then
    for f in $(getorder "$templatedir/__post-apply.d"); do
      [[ -x "$f" ]] || continue
      "$f" "$projectdir"
    done
  fi

}
