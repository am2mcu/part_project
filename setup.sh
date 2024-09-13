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

install_package() {
    local package_name=$1
    apt -y -qq install $package_name
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

ssh_config() {
    local package_name="openssh-server"
    local ssh_config_path=/etc/ssh/sshd_config

    install_package $package_name

    ssh_change_port $ssh_config_path

    ssh_change_login_msg $ssh_config_path

    ssh_block_root_login $ssh_config_path

    systemctl restart ssh
}

ntp_add_server() {
    sed -i '/.*Specify.*NTP servers/a server pool.ntp.org' $1
}

ntp_config() {
    local package_name="ntp"
    local ntp_config_path=/etc/ntpsec/ntp.conf
    
    install_package $package_name

    ntp_add_server $ntp_config_path

    systemctl restart ntp
}


main() {
    # Program Flow
    # initial_setup
    
    # ssh_config

    ntp_config
}


main