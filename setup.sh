#!/bin/bash

add_user() {
    local user="part"
    useradd $user -m -G sudo
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

cron_add_task() {
    local cron_time=$1
    local cron_command=$2

    (crontab -l; \
        echo "$cron_time $cron_command" \
    ) | crontab -
}

cron_config() {
    local main_path=/opt/data

    local user=root
    local processes_num_path=$main_path/${user}_processes_num

    local open_ports_path=$main_path/open_ports

    local uid=1000
    local users_list_path=$main_path/users_list_${uid}

    mkdir -p $main_path
    touch -a $processes_num_path $open_ports_path $users_list_path

    local cron_time="*/2 * * * *"
    cron_add_task \
        "$cron_time" \
        "ps -u $user -U $user --no-headers | wc -l >> $processes_num_path"

    cron_add_task \
        "$cron_time" \
        "netstat -tulpn | grep LISTEN >> $open_ports_path"

    cron_add_task \
        "$cron_time" \
        "awk -F: '(\$3 < $uid) {print \$1}' /etc/passwd >> $users_list_path"
}

main() {
    # Program Flow
    # initial_setup
    
    # ssh_config

    # ntp_config

    # cron_config
}


main