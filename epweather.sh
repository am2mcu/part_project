#!/bin/bash
# set -xv

fetch_weather() {
    CityName=$1
    echo "$(date): $(curl -s wttr.in/$CityName?format='%l:+%t+%c%w+%h\n')"
    # TODO: Country is not shown
}

print_usage() {
    echo "epweather [-lhu] [CityName] [-a CityName] [-d CityName] [-n CityName]"
}

no_flag=true
while getopts ":a:ld:n:hu" flag; do
    case $flag in
    a)
        # TODO
        ;;
    l)
        # TODO
        ;;
    d)
        # filename=$OPTARG
        # TODO
        ;;
    n)
        CityName=$OPTARG
        curl wttr.in/$CityName
        ;;
    h)
        print_usage
        ;;
    u)
        # TODO
        ;;
    \?)
        # Handle invalid options
        echo "Invalid option $OPTARG!"
        ;;
    :)
        echo "Provide option $OPTARG!"
        ;;
    esac
    no_flag=false
done

# getopts processes the options in turn.
# That's its job. If the user happens to pass no option,
# the first invocation of getopts exits the while loop.
if [[ $# == 0 ]]; then
    print_usage
fi

if [[ $no_flag == "true" ]]; then
    CityName=$1
    curl wttr.in/$CityName
fi
