#!/bin/bash
# Function to update network configuration
update_network_config() {
    local netplan_file="/etc/netplan/50-cloud-init.yaml"
    local new_config=$(cat <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    eth1:
      addresses:
        - 192.168.16.21/24
      gateway4: 192.168.16.2
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
EOF
)

    log "Updating network configuration..."
    # Check if configuration already exists
    if ! grep -q "192.168.16.21" "$netplan_file"; then
        echo "$new_config" | sudo tee -a "$netplan_file" >/dev/null
        sudo netplan apply
        log "Network configuration updated."
    else
        log "Network configuration already up to date."
    fi
}

# Call the function to update network configuration
update_network_config

# Function to update the /etc/hosts file
update_hosts() {
    print_message "Updating /etc/hosts File"
    local new_entry="192.168.16.21    server1"

    # Remove old entry if present
sudo grep -v '^192\.168\.16\.21[[:space:]]\+server1$' /etc/hosts | sudo tee /etc/hosts >/dev/null

    # Add new entry
    echo "$new_entry" | sudo tee -a /etc/hosts >/dev/null
}

# Update /etc/hosts file
update_hosts

# Function to install required software
install_software() {
    if ! package_installed "apache2"; then
        log "Installing Apache2 web server..."
        sudo apt update
        sudo apt install -y apache2
        log "Apache2 web server installed."
    else
        log "Apache2 web server is already installed."
    fi

    if ! package_installed "squid"; then
        log "Installing Squid web proxy..."
        sudo apt update
        sudo apt install -y squid
        log "Squid web proxy installed."
    else
        log "Squid web proxy is already installed."
    fi
}

# Call the function to install required software
install_software

# Function to start and enable Apache2 service
start_apache() {
    print_message "Starting and Enabling Apache2 Service"
    sudo systemctl start apache2
    sudo systemctl enable apache2
}

# Function to start and enable Squid service
start_squid() {
    print_message "Starting and Enabling Squid Service"
    sudo systemctl start squid
    sudo systemctl enable squid
}

# Start and enable Apache2 service
start_apache

# Start and enable Squid service
start_squid

# Function to enable UFW and configure firewall rules
configure_firewall() {
    print_message "Configuring Firewall with UFW"
    
    # Enable UFW
    sudo ufw enable

    # Allow SSH on port 22 only on the management network
    sudo ufw allow from <mgmt_network_ip> to any port 22

    # Allow HTTP on both interfaces
    sudo ufw allow http

    # Allow web proxy on both interfaces (assuming default Squid proxy port 3128)
    sudo ufw allow 3128

    # Reload UFW to apply changes
    sudo ufw reload
}


# Configure firewall rules using UFW
configure_firewall

# Function to create user accounts with SSH keys and sudo access
create_users() {
    local users=("dennis" "aubrey" "captain" "snibbles" "brownie" "scooter" "sandy" "perrier" "cindy" "tiger" "yoda")

    log "Creating user accounts..."

    for user in "${users[@]}"; do
        if ! id "$user" &>/dev/null; then
            log "Creating user: $user"

            sudo useradd -m -s /bin/bash "$user" # Add a user with a specified username and default shell
            sudo mkdir -p "/home/$user/.ssh"
            sudo touch "/home/$user/.ssh/authorized_keys"
            sudo chown -R "$user:$user" "/home/$user/.ssh"

            # Add SSH public keys for users based on their usernames
            case "$user" in
                "dennis")
                    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm" | sudo tee -a "/home/$user/.ssh/authorized_keys" >/dev/null
                    ;;
                *)
                    # For other users, add their public keys here (This part is left as a placeholder)
                    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCezTPysKYTPTnrdXzlSmlbPtjQDebgWwHmE1QfM7LIuCNuKQZprVkbe+wfX4J+Rgp5vN0KHaxW8w/aRgB4yl7B8kTvW84OKcS1EACoKGl9Jrwb" | sudo tee -a "/home/$user/.ssh/authorized_keys" >/dev/null
                    ;;
            esac
            log "SSH keys added for user: $user"
        else
            log "User '$user' already exists. Skipping creation."
        fi
    done

    # Grant sudo access to the 'dennis' user
    sudo usermod -aG sudo dennis
    log "Sudo access granted to user 'dennis'."
}

# Call the function to create user accounts with SSH keys and sudo access
create_users
