#!/bin/bash

LOG_LEVEL="INFO"

log() {
    declare -A log_levels=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3 [CRIT]=4)
    local log_priority=$1
    local log_msg=$2

    [[ ${log_levels[$log_priority]} ]] || return 1
    (( ${log_levels[$log_priority]} < ${log_levels[$LOG_LEVEL]} )) && return 2

    # Do not include INFO in logs
    [[ "$log_priority" == "INFO" ]] \
        && echo -e "[*] ${log_msg}\n" \
        || echo -e "${log_priority}: ${log_msg}\n"
}

get_input() {
    local input_message=$1
    local default_value=$2

    read -p "$input_message (default: $default_value): " user_input
    echo -e "${user_input:-$default_value}\n"
}

validate_username() {
    local user=$1
    if [[ ! "$user" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        return 1
    fi
}

add_user() {
    local default_user="part"

    log "INFO" "Creating new user..."
    local user=$(get_input "Username" $default_user)
    if ! validate_username $user; then
        log "WARN" "Invalid username (will carry on with $default_user)"
        user=$default_user
    fi

    useradd $user -m -G sudo \
        && log "INFO" "User $user created" \
        || log "ERROR" "Couldn't create user $user"
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
    repos=$(get_input "Enter \"yes\" for custom repositories" "Official Repositories")
    if [[ "${repos,,}" == "yes" ]]; then
        /usr/bin/nano /tmp/repos_input.tmp
        repos=$(cat /tmp/repos_input.tmp)
        rm /tmp/repos_input.tmp
    else
        repos=$official_repos
    fi

    local sources_list_path=/etc/apt/sources.list

    log "INFO" "Setting new repositories..."
    echo "$repos" > $sources_list_path \
        && log "INFO" "Repositories set" \
        || log "ERROR" "Couldn't set repositories"
}

check_network() {
    if ! ping -q -c1 google.com &>/dev/null; then
        return 1
    fi
}

update_packages() {
    if check_network; then
        log "INFO" "Update & upgrading packages..."
        apt -y -qq update
        apt -y -qq upgrade
        log "INFO" "Packages are up to date"
    else
        log "ERROR" "No internet connection"
    fi
}

initial_setup() {
    add_user
    set_mirror
    update_packages
}

install_package() {
    local package_name=$1

    if check_network; then
        log "INFO" "Installing ${package_name}..."
        apt -y -qq install $package_name \
            && log "INFO" "Installed ${package_name}" \
            || log "ERROR" "Couldn't install ${package_name}"
    else
        log "ERROR" "No internet connection (Couldn't install $package_name)"
        return 1
    fi
}

ssh_change_port() {
    local ssh_config_path=$1
    local port_num=$2

    sed -i "/\bPort\b/c\Port $port_num" $ssh_config_path \
        && log "INFO" "SSH port changed to $ssh_port_num" \
        || log "ERROR" "Couldn't change SSH port"
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
        $ssh_config_path \
            && log "INFO" "SSH login message changed to $login_msg" \
            || log "ERROR" "Couldn't change SSH login message"
}

ssh_block_root_login() {
    # Include '#' to avoid undesired changes
    sed -i '/#PermitRootLogin\b/c\PermitRootLogin no' $1 \
        && log "INFO" "Blocked SSH root login" \
        || log "ERROR" "Couldn't block SSH root login"
}

ssh_config() {
    local package_name="openssh-server"
    local ssh_config_path=/etc/ssh/sshd_config

    if ! install_package $package_name; then
        log "ERROR" "Skipping task"
        return 1
    fi

    log "INFO" "Configuring SSH..."
    ssh_port_num=$(get_input "SSH port number" 2324) # not local - used in nftables_config()
    ssh_change_port $ssh_config_path $ssh_port_num

    local ssh_login_msg=$(get_input "SSH login message" "Hello from Emperor Penguin 3")
    ssh_change_login_msg $ssh_config_path $ssh_login_msg

    ssh_block_root_login $ssh_config_path

    systemctl restart ssh \
        && log "INFO" "Configured SSH" \
        || log "ERROR" "Couldn't run SSH service"
}

ntp_add_server() {
    local ntp_config_path=$1
    local ntp_server=$2

    sed -i "/.*Specify.*NTP servers/a server $ntp_server" $ntp_config_path \
        && log "INFO" "Set new NTP server" \
        || log "ERROR" "Couldn't set NTP server"
}

ntp_config() {
    local package_name="ntp"
    local ntp_config_path=/etc/ntpsec/ntp.conf
    
    if ! install_package $package_name; then
        log "ERROR" "Skipping task"
        return 1
    fi

    log "INFO" "Configuring NTP..."
    local ntp_server=$(get_input "NTP server" "pool.ntp.org")
    ntp_add_server $ntp_config_path $ntp_server

    systemctl restart ntp \
        && log "INFO" "Configured NTP" \
        || log "ERROR" "Couldn't run NTP service"
}

cron_add_task() {
    local cron_time=$1
    local cron_command=$2

    (crontab -l; \
        echo "$cron_time $cron_command" \
    ) | crontab - \
        && log "INFO" "Added new cronjob for $cron_command" \
        || log "ERROR" "Couldn't add cronjob"
}

cron_config() {
    local main_path=/opt/data

    log "INFO" "Configuring cronjob..."
    local user=$(get_input "processes cronjob user" "root")
    local processes_num_path=$main_path/${user}_processes_num

    local open_ports_path=$main_path/open_ports

    local uid=$(get_input "user list cronjob uid" 1000)
    local users_list_path=$main_path/users_list_${uid}

    mkdir -p $main_path \
        && log "INFO" "Created $main_path directory" \
        || log "ERROR" "Couldn't create $main_path directory"
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

    nft add rule $table_name $chain_name $rule \
        && log "INFO" "Added new rule $rule" \
        || log "ERROR" "Couldn't add rule"
}

nftables_config() {
    local table_name="firewall"
    local input_chain="input"
    local output_chain="output"
    
    log "INFO" "Configuring nftables..."
    if ! check_network; then
        log "ERROR" "No internet connection"
        log "ERROR" "Skipping task (Problem resolving hosts)"
        return 1
    fi

    nft_add_table $table_name
    
    local nft_counter_host=$(get_input "NFT counter host" "deb.debian.org") 
    nft_add_chain $table_name $output_chain "type filter hook output priority 0" "policy accept"
    nft_add_rule $table_name $output_chain "ip daddr $nft_counter_host counter"
    
    ssh_port_num="${ssh_port_num:-22}"
    local nft_accept_port=$(get_input "NFT accept port" $ssh_port_num)
    nft_add_chain $table_name $input_chain "type filter hook input priority 0" "policy drop"
    nft_add_rule $table_name $input_chain "tcp dport $nft_accept_port accept"

    # make table permanently
    nft list table $table_name >> /etc/nftables.conf \
        && log "INFO" "Configured nftables" \
        || log "ERROR" "Couldn't config new ruleset for nftables"
}

allow_task() {
    local task_name=$1
    local user_input=$(get_input "Run task \"$task_name\" [yes/no]" "yes")
    if [[ ! "${user_input,,}" == "yes" ]]; then
        return 1
    fi
}

main() {
    if [[ $(id -u) != 0 ]]; then
        log "ERROR" "Run as root"
        return 1
    fi

    if allow_task "Initial setup"; then
        initial_setup
    fi
    
    if allow_task "SSH config"; then
        ssh_config
    fi

    if allow_task "NTP config"; then
        ntp_config
    fi

    if allow_task "Cronjob config"; then
        cron_config
    fi

    if allow_task "Nftables config"; then
        nftables_config
    fi
}


main