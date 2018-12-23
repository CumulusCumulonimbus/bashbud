#!/usr/bin/env bash

___printversion(){
  
cat << 'EOB' >&2
bashbud - version: 1.165
updated: 2018-12-14 by budRich
EOB
}

# environment variables
: "${BASHBUD_DIR:=$XDG_CONFIG_HOME/bashbud}"
: "${BASHBUD_DATEFORMAT:=%Y-%m-%d}"

set -o errexit
set -o pipefail
set -o nounset

main(){

  IFS=$'\n\t'

  # --new|-n  [GENERATOR]  **TARGET_DIR**
  if [[ ${__o[new]:-} = 1 ]]; then
    
    case $# in
      0 ) ERX "no directory specified" ;;
      2 ) newproject "$1" ;;
      1 ) newproject      ;;
      * ) ___printhelp    ;;
    esac

  # --bump|-b  [PROJECT_DIR]
  elif [[ ${__o[bump]:-} = 1 ]]; then
    bumpproject "${1:-$PWD}"
  elif [[ ${__o[version]:-} = 1 ]]; then
    ___printversion
    exit
  else
    ___printhelp
    exit
  fi
}


___printhelp(){
  
cat << 'EOB' >&2
bashbud - Boilerplate and template maker for bash scripts

SYNOPSIS
--------

--new|-n   [GENERATOR] TARGET_DIR
--bump|-b  [PROJECT_DIR]
--help|-h
--version|-v

OPTIONS
-------

--new|-n  
This will create a new script named
"BASHBUD_NEW_SCRIPT_DIR/NAME/NAME.sh" and copy the
info template to the same directory. The
bashbud.sh lib script will get linked to the lib
directory of the script.


--bump|-b  
bump option will update PROJECT by setting update
date in manifest.md to the current date, and also
bump the verion number with (current version +
0.001). It will also temporarly set the project in
development mode (if it isn't already) and
generate readme and manpage files for PROJECT.


--help|-h  
Show help and exit.


--version|-v  
Show version and exit.
EOB
}

bumpproject(){
  local projectdir="${1/'~'/$HOME}"

  [[ -f "$projectdir/manifest.md" ]] \
    || ERX "$projectdir doesn't contain manifest.md"

  # update date and version number
  dateupdate -bu "$projectdir/manifest.md"

  generate "$projectdir"
}

generate() {
  local generatortype genpath
  local projectdir="${1/'~'/$HOME}"
  local templatedir="$projectdir/bashbud"
  local projectname="${projectdir##*/}"

  # prepend full path if dirname is relative
  [[ $projectdir =~ ^[^/] ]] \
    && projectdir="$PWD/$projectdir"

  # get generator and license type from manifest
  eval "$(awk '
    /^type:/ {print "generatortype=" $2}
    /^license:/ {print "licensetype=" $2}
    /^[.]{3}$/ {exit}
    ' "$projectdir/manifest.md"
  )"


  [[ -f $BASHBUD_DIR/licenses/${licensetype:=X} ]] \
    && licensetemplate="$BASHBUD_DIR/licenses/$licensetype"

  # templatedir path priority:
  # 1. $projectdir/bashbud
  # 2. $BASHBUD_DIR/generators/${generatortype:=default}/__templates
  # 3. /usr/share/bashbud/generators/${generatortype:=default}/__templates

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

  awk -v name="$projectname" -v dir="$projectdir" '

    @include "awklib/isfile"
    @include "awklib/isdir"
    @include "awklib/getif"
    @include "awklib/tempexpand"
    @include "awklib/loop"
    @include "awklib/templateinit"
    @include "awklib/readtemplate"
    @include "awklib/readmanifest"
    @include "awklib/readyaml"
    @include "awklib/printformat"
    @include "awklib/makemanifest"
    @include "awklib/expandbody"
    @include "awklib/cat"
    @include "awklib/setvar"
    @include "awklib/mdcat"
    @include "awklib/wrap"
    @include "awklib/wrapcheck"

    BEGIN {
      sqo="'"'"'"
      sqol=sqo "\"" sqo "\"" sqo
      reading=0

      aafrm="___%s[%s-%s]=\"%s\"\n"
      iafrm="___%s+=(\"%s\")\n"

      amani["name"]=name
      curopt=0
    }

    mark=0

    $0=="---" && reading==0 {
      reading="yaml"
      mark=1
    }

    $0=="..." && reading=="yaml" {
      reading="manifest"
      chain=0
      mark=1
    }

    $0=="___START___" && reading=="manifest" {
      makemanifest()
      reading="templates"
      mark=1
      templateinit()
    }

    mark!=1 && reading=="templates" {
      readtemplate()
    }
      

    mark!=1 && reading=="manifest" {
      readmanifest()
    }

    mark!=1 && reading=="yaml" && /./ && match($0,/([[:space:]]*)([-]{,1})[[:space:]]*([0-9a-zA-Z_-]*)([:]{,1})[[:space:]]*(.*)[[:space:]]*$/,ma) {
      readyaml() 
    }

    END {

      # for (k in amani["options"]["mode"]) {print k}
      # print amani["options"]["mode"]["long"]
    }


  ' <(
    cat "$projectdir/manifest.md"
    [[ -d $projectdir/manifest.d ]] \
      && cat "$projectdir/manifest.d/"*
    echo "___START___"
    for d in "$templatedir"/* ; do
      [[ -d $d ]] || continue

      [[ -f $d/__template ]] && {
        cat "$d/__template"
        echo "___PRINT_TEMPLATE___${d}"
      }
    done

    [[ -n ${licensetemplate:-} ]] && {
      cat "$licensetemplate"
      echo "___PRINT_TEMPLATE___${licensetemplate%/*}"
    }
    
  )


}

dateupdate(){

  local f bump

  f="${!#:-}"
  bump=0

  [[ -f $f ]] && [[ manifest.md = "${f##*/}" ]] && {

    while getopts cub option; do
      case "${option}" in
        c ) dtu+=("created") ;;
        u ) dtu+=("updated") ;;
        b ) bump=1 ;;
        *) exit 1 ;;
      esac
    done

    trg=${#dtu[@]}
    ((trg>1)) \
      && srch="^created:$|^updated:$" \
      || srch="^${dtu[0]}:\$"


    awk \
      -i inplace \
      -v bump="$bump" \
      -v today="$(date +"${BASHBUD_DATEFORMAT}")" \
      -v trg="$trg" \
      -v srch="$srch" '
        bump == 1 && $1 == "version:" {
          newver=$2 + 0.001
          sub($2,newver,$0)
          bump=0
        }
        fnd != trg && $1 ~ srch {sub($2,today,$0);fnd++}
        {print}
    ' "$f"
  }

}

# --new|-n  [GENERATOR]  **TARGET_DIR**
newproject(){

  local f fn dn

  local generator="${1:-default}"
  local generatordir="$BASHBUD_DIR/generators/$generator"
  local targetdir="${__lastarg/'~'/$HOME}"

  # test if targetdir exist
  [[ -d $targetdir ]] \
    && ERX "$targetdir already exist."

  # test if generator exist
  [[ -d $generatordir ]] \
    || ERX "generator DIR $generatordir doesn't exist"
  
  # create targetdir
  mkdir -p "$targetdir"

  # copy all files and directories from generatordir
  # not starting with "__"
  for f in "$generatordir"/*; do
    fn="${f##*/}"
    [[ $fn =~ ^__ ]] && continue
    cp -rf "$f" "$targetdir"
  done

  # if __link dir exist, link files and creat
  # directories if needed
  if [[ -s "$generatordir/__link" ]]; then
    for f in $(find "$generatordir/__link" -type f); do
      dn="${f%/*}"
      dn="${dn/$generatordir\/__link/$targetdir}"
      mkdir -p "$dn"
      ln -f "$f" "$dn"
    done
  fi

  # update dates in manifest.md
  dateupdate -cu "$targetdir/manifest.md"

  bumpproject "$targetdir"
}

ERM(){ >&2 echo "$*"; }
ERR(){ >&2 echo "[WARNING]" "$*"; }
ERX(){ >&2 echo "[ERROR]" "$*" && exit 1 ; }

OFS="${IFS}"
IFS=$' \n\t'

declare -A __o
eval set -- "$(getopt --name "bashbud" \
  --options "nbhv" \
  --longoptions "new,bump,help,version," \
  -- "$@"
)"

while true; do
  case "$1" in
    --new        | -n ) __o[new]=1 ;; 
    --bump       | -b ) __o[bump]=1 ;; 
    --help       | -h ) __o[help]=1 ;; 
    --version    | -v ) __o[version]=1 ;; 
    -- ) shift ; break ;;
    *  ) break ;;
  esac
  shift
done

[[ ${__lastarg:="${!#:-}"} =~ ^--$|${0}$ ]] \
  && __lastarg="" \
  || true

IFS="${OFS}"

main "${@:-}"

