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

ssh_install_package() {
    apt -qq install openssh-server
}

ssh_change_port() {
    sed -i '/\bPort\b/c\Port 2324' $1
}

ssh_change_login_msg() {
    local login_msg="Hello from Emperor Penguin 3"
    local motd_path=/etc/motd
    
    echo $login_msg > $motd_path

    sed -i \
        -e '/\bUsePAM\b/c\UsePAM no' \
        -e '/\bPrintMotd\b/c\PrintMotd yes' \
        -e '/\bPrintLastLog\b/c\PrintLastLog no' \
        $1
}

ssh_block_root_login() {
    # Include '#' to avoid undesired changes
    sed -i '/#PermitRootLogin\b/c\PermitRootLogin no' $1
}

config_ssh() {
    local ssh_config_path=/etc/ssh/sshd_config

    ssh_install_package

    ssh_change_port $ssh_config_path

    ssh_change_login_msg $ssh_config_path

    ssh_block_root_login $ssh_config_path

    systemctl restart ssh.service
}


main() {
    # Program Flow
    # initial_setup
    
    config_ssh
}


main