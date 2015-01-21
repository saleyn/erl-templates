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

while getopts 'hm:e:d:t:c:o:' OPTION ; do
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
    *)  echo "This script creates generic Erlang modules from templates."
        echo
        echo "Usage: $0 [-t Type] [-m Module] [-d Description]" 
        echo "          [-e Email] [-c Copyright] [-o OutputDir] [-h]" 
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

if [ -z "$copyrt" ]; then
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
    ${dir}/${template}.erl.in

exec 3>&-       # close temporary file descriptor 3
