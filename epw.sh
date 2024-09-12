#!/bin/bash
# set -xv

main_path=/opt/data/epweather
cities_path=$main_path/db
database_path=$cities_path/cities.txt

fetch_weather() {
    local city_name=$1
    echo "$(date): $(curl -s wttr.in/$city_name?format='%l+-+%t+-+%C+-+%w+-+%h\n')"
    # TODO: Country is not shown
    # TODO: return error status when internet connection is not available
}

add_city_to_db() {
    local city_name=$1
    if grep -qi "\b$city_name\b" $database_path; then
        echo "$city_name exists!"
    else
        echo $city_name >>$database_path
        touch $cities_path/$city_name.txt
    fi
}

list_cities() {
    cat $database_path
}

delete_city_from_db() {
    local city_name=$1
    if grep -qi "\b$city_name\b" $database_path; then
        sed -i "/\b$city_name\b/Id" $database_path
        rm $cities_path/$city_name.txt
    else
        echo "$city_name does not exist!"
    fi
}

update_cities_db() {
    while IFS='' read -r city_name; do
        fetch_weather $city_name >>$cities_path/$city_name.txt
    done <$database_path
}

print_usage() {
    echo "epweather [-lhu] [CityName] [-a CityName] [-d CityName] [-n CityName]"
}

no_flag=true
while getopts ":a:ld:n:hu" flag; do
    case $flag in
    a)
        city_name=$OPTARG
        add_city_to_db $city_name
        ;;
    l)
        list_cities
        ;;
    d)
        city_name=$OPTARG
        delete_city_from_db $city_name
        ;;
    n)
        city_name=$OPTARG
        fetch_weather $city_name
        ;;
    h)
        print_usage
        ;;
    u)
        update_cities_db
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
elif [[ $no_flag == "true" ]]; then
    city_name=$1
    fetch_weather $city_name
fi
