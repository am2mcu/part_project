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

update_packages() {
    apt update
    apt upgrade
}

initial_setup() {
    add_user
    set_mirror
    update_packages
}

config_ssh() {
    local ssh_config_path=/etc/ssh/sshd_config
    
    apt -qq install openssh-server

    sed -i '/\bPort\b/c\Port 2324' $ssh_config_path

    sed -i \
        -e '/\bUsePAM\b/c\UsePAM no' \
        -e '/\bPrintMotd\b/c\PrintMotd yes' \
        -e '/\bPrintLastLog\b/c\PrintLastLog no' \
        $ssh_config_path

    # Include '#' to avoid undesired changes
    sed -i '/#PermitRootLogin\b/c\PermitRootLogin no' $ssh_config_path

}


main() {
    # Program Flow
    initial_setup
}


main