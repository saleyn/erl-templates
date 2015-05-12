#!/bin/bash
#------------------------------------------------------------------------------
# This script creates generic Erlang modules from templates.
#
# Author:  Serge Aleynikov <saleyn@gmail.com>
# Created: 2010-05-10
#------------------------------------------------------------------------------

exec 3>&1           # Open temp file descriptor 3 and link it with stdout.
exec > /dev/stderr  # Redirect current stdout to stderr (doesn't affect fd 3)

# Setting value by referece
# Example:  template="s"; get_template template; echo $template 
get_template() {
    case ${!1} in
    s)  eval $1="gen_server";       return 0;; 
    l)  eval $1="gen_leader";       return 0;; 
    a)  eval $1="gen_application";  return 0;;
    f)  eval $1="gen_fsm";          return 0;;
    m)  eval $1="module";           return 0;;
    *)  return 1;;
    esac
}

ask() {
    local i=$((54 - ${#1}))
    local p
    printf -v p "%*s" $i
    echo -n "${1}${p// /.}: " 
}

year=$(date +%Y)
now=$(date +%Y-%m-%d)
author=$(awk -F: 'user == $1 {print $5}' user=$USER /etc/passwd)
copyright="$author"
def_email=$(git config --get user.email 2> /dev/null)
tabwidth=4

while getopts 'hm:e:d:t:c:o:w:' OPTION ; do
    case $OPTION in
    c)  [ -n "$OPTARG" ] && copyright="$OPTARG"
        copyrt=1;;
    d)  brief="$OPTARG";;
    e)  email="$OPTARG";;
    m)  module="$OPTARG";;
    t)  template="$OPTARG"
        get_template template
        if [ $? -ne 0 ]; then
           echo "Invalid template type: $template" 
           exit 1
        fi;;
    o)  # Redirect output to file
        [ -d "$OPTARG" ] || (echo "$OPTARG directory doesn't exist!"  && exit 1)
        outdir="$OPTARG"
        ;;
    w)  tabwidth=$OPTARG
        [ $tabwidth -eq 2 -o $tabwidth -eq 4 ] || (echo "Tabwidth must be 2 or 4!" && exit 1);;

    *)  echo "This script creates generic Erlang modules from templates."
        echo
        echo "Usage: $0 [-t Type] [-m Module] [-d Description]" 
        echo "          [-e Email] [-c Copyright] [-o OutputDir] [-h] [-w TabWidth]" 
        echo "  Type        - s = gen_server"
        echo "                l = gen_leader"
        echo "                f = gen_fsm"
        echo "                a = application" 
        echo "                m = module"
        echo "  OutputDir   - when provided, output is redirected to "
        echo "                OutputDir/Module.erl'"
        exit 1;;
    esac
done

shift $((OPTIND - 1))

vars_file=$(readlink -f $0)
vars_file=${vars_file%/*}/vars.${USER}.config

if [ -f "$vars_file"  ]; then
    [ -z "$email"     ] && email=$(sed -n '/^EMAIL/s/EMAIL=\(.*\)/\1/p' "$vars_file")
    [ -z "$copyright" ] && copyright=$(sed -n '/^COPYRIGHT/s/COPYRIGHT=\(.*\)/\1/p' "$vars_file")
fi

while [ -z "$template" ]; do
    echo "Template type [gen_(s)erver, gen_(l)eader, gen_(f)sm"
    ask  "               (a)pplication, (m)odule]"
    read template && get_template template && break
    unset template
done

while [ -z "$module" ]; do
    ask "Module name (e.g. test_server)"
    read module && [ -n "$module" ] && break
done

while [ -z "$email" ]; do
    if [ -n "$def_email" ]; then
        m=" [default: $def_email]"
    fi
    ask "Email address${m}"
    read email && [ -n "$email" ] && break || email="$def_email"
done

if [ -z "$copyright" ]; then
    ask "Copyright [default: $author]"
    read copyright && [ -n "$copyright" ] || copyright="$author"
fi

if [ -z "$brief" ]; then
    ask "Brief description"
    read brief
fi

if [ -n "$outdir" ]; then
    outfile="$outdir/$module.erl"
    echo "Creating file: $outfile" 
    exec > "$outfile" || exit 1
else
    exec 1>&3   # Restore old file descriptor
fi

cur_dir=${0%/*}
old_dir=$PWD
cd $cur_dir
dir=$PWD
cd $old_dir

sed -e "s!%AUTHOR%!${author}!g" \
    -e "s!%BRIEF%!${brief}!g" \
    -e "s!%COPYRIGHT%!${year} ${copyright}!g" \
    -e "s!%DATE%!${now}!g" \
    -e "s!%EMAIL%!${email}!g" \
    -e "s!%MODULE%!${module}!g" \
    -e "s!%TABWIDTH%!${tabwidth}!g" \
    -e "s!^$(printf '%*s' 4 ' ')\([^ ]\)!$(printf '%*s' $tabwidth ' ')\\1!" \
    -e "s!^$(printf '%*s' 8 ' ')\([^ ]\)!$(printf '%*s' $((2*$tabwidth)) ' ')\\1!" \
    ${dir}/${template}.erl.in

exec 3>&-       # close temporary file descriptor 3
