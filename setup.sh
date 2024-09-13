#!/bin/bash

add_user() {
    local username="part"
    useradd $username -m -G sudo
}

set_mirror() {
    local official_repos=$(cat <<-END
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
    
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb-src http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware

deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
END
    )

    local sources_list_path=/etc/apt/sources.list

    echo "$official_repos" > $sources_list_path
}


main() {
    # Program Flow
    # initial_setup
    set_mirror
}


main