#!/bin/bash

get_input() {
    local input_message=$1
    local default_value=$2

    read -p "$input_message (default: $default_value): " user_input
    echo "${user_input:-$default_value}"
}

add_user() {
    local user="part"

    user=$(get_input "Username" $user)
    useradd $user -m -G sudo
}

set_mirror() {
    local repos=$(cat <<-END
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
    
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb-src http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware

deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
END
    )
    repos=$(get_input "Custom repos? [yes]" "Official Debian Repos")
    if [[ "${repos,,}" == "yes" ]]; then
        /usr/bin/nano /tmp/repos_input.tmp
        repos=$(cat /tmp/repos_input.tmp)
        rm /tmp/repos_input.tmp
    fi

    local sources_list_path=/etc/apt/sources.list

    echo "$repos" > $sources_list_path
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
    local ssh_config_path=$1
    local port_num=$2

    sed -i "/\bPort\b/c\Port $port_num" $ssh_config_path
}

ssh_change_login_msg() {
    local ssh_config_path=$1
    local login_msg=$2
    local motd_path=/etc/motd
    
    echo $login_msg > $motd_path

    sed -i \
        -e '/\bUsePAM\b/c\UsePAM no' \
        -e '/\bPrintMotd\b/c\PrintMotd yes' \
        -e '/\bPrintLastLog\b/c\PrintLastLog no' \
        $ssh_config_path
}

ssh_block_root_login() {
    # Include '#' to avoid undesired changes
    sed -i '/#PermitRootLogin\b/c\PermitRootLogin no' $1
}

ssh_config() {
    local package_name="openssh-server"
    local ssh_config_path=/etc/ssh/sshd_config

    install_package $package_name

    port_num=2324 # not local - used in nftables
    ssh_change_port $ssh_config_path $port_num

    local login_msg="Hello from Emperor Penguin 3"
    ssh_change_login_msg $ssh_config_path $login_msg

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

nft_add_table() {
    local table_name=$1

    nft add table $table_name
}

nft_add_chain() {
    local table_name=$1
    local chain_name=$2
    local type=$3
    local policy=$4

    nft add chain $table_name $chain_name { $type \; $policy \; }
}

nft_add_rule() {
    local table_name=$1
    local chain_name=$2
    local rule=$3

    nft add rule $table_name $chain_name $rule
}

nftables_config() {
    local table_name="firewall"
    local input_chain="input"
    local output_chain="output"
    
    nft_add_table $table_name
    
    nft_add_chain $table_name $output_chain "type filter hook output priority 0" "policy accept"
    nft_add_rule $table_name $output_chain "ip daddr deb.debian.org counter"
    
    nft_add_chain $table_name $input_chain "type filter hook input priority 0" "policy drop"
    nft_add_rule $table_name $input_chain "tcp dport $port_num accept"

    # nft list table $table_name >> /etc/nftables.conf
}

main() {
    # Program Flow
    # initial_setup
    
    # ssh_config

    # ntp_config

    # cron_config

    # nftables_config

    set_mirror
}


main