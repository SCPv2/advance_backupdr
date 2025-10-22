#!/bin/bash
# Samsung Cloud Platform v2 (OpenStack) - Universal UserData Template
# 45KB limit optimized for OpenStack cloud-init
#
# UNIVERSAL TEMPLATE: Supports both VM-based DB and DBaaS scenarios
# - database_service: Uses VM-based PostgreSQL (includes db_server_module.sh)
# - object_storage: Uses PostgreSQL DBaaS (skips DB server installation)
#
# Template Variables (replaced by userdata_manager.ps1):
# - app: "web", "app", or "db"
# - cesvc.net, 10.1.1.111, 10.1.2.121, 10.1.3.131: Network configuration
# - APPLICATION_INSTALL_MODULE: Server-specific installation module content
# - {"config_metadata":{"template_source":"variables.tf","version":"4.1.0","description":"Samsung Cloud Platform 3-Tier Architecture Master Configuration with DBaaS","created":"2025-10-14 13:22:01","usage":"This file contains all environment-specific settings for the application deployment","generator":"variables_manager.ps1"},"user_input_variables":{"object_storage_access_key_id":"0c75276b96964639a776543eff22eff2","public_domain_name":"creative-energy.net","keypair_name":"mykey","object_storage_secret_access_key":"424527a9-d22e-4321-8025-b8444f837048","_source":"variables.tf USER_INPUT category","private_domain_name":"cesvc.net","object_storage_bucket_string":"89097ddf09b84d96af496aded95dac29","user_public_ip":"14.39.93.74","_comment":"Variables that users input interactively during deployment"},"ceweb_required_variables":{"rollback_enabled":"true","database_host":"db.cesvc.net","nginx_port":"80","_source":"variables.tf CEWEB_REQUIRED category","app_lb_service_ip":"10.1.2.100","timezone":"Asia/Seoul","database_port":"2866","db_max_connections":"100","database_user":"cedbadmin","app_ip":"10.1.2.121","web_lb_service_ip":"10.1.1.100","git_branch":"main","auto_deployment":"true","database_name":"cedb","db_type":"postgresql","app_server_port":"3000","admin_email":"ars4mundus@gmail.com","company_name":"Creative Energy","backup_retention_days":"30","db_ip":"10.1.3.131","bastion_ip":"10.1.1.110","session_secret":"your-secret-key-change-in-production","_comment":"Variables required by ceweb application for business logic and functionality","_database_connection":{"db_ssl_enabled":false,"database_password":"cedbadmin123!","db_pool_idle_timeout":30000,"db_pool_min":20,"db_pool_connection_timeout":60000,"db_pool_max":100},"node_env":"production","web_ip":"10.1.1.111","git_repository":"https://github.com/SCPv2/ceweb.git","ssl_enabled":"false"},"_variable_classification":{"description":"ceweb application variable classification system","categories":{"user_input":"Variables that users input interactively during deployment","terraform_infra":"Variables used by terraform for infrastructure deployment","ceweb_required":"Variables required by ceweb application for business logic and database connections"}},"terraform_infra_variables":{"db_ip2":"10.1.3.33","_source":"variables.tf TERRAFORM_INFRA category","_comment":"Variables used by terraform for infrastructure deployment"}}: Environment-specific configuration JSON

set -euo pipefail
SERVER_TYPE="app"
LOGFILE="/var/log/userdata_app.log"
exec 1> >(tee -a $LOGFILE) 2>&1

echo "=== ${SERVER_TYPE^} Server Init: $(date) ==="

# Module 0: Local DNS Resolution
local_dns_setup() {
    echo "[0/5] Local DNS Resolution setup..."
    
    # Define domain mappings
    PRIVATE_DOMAIN="cesvc.net"
    WEB_IP="10.1.1.111"
    APP_IP="10.1.2.121"
    DB_IP="10.1.3.131"
    
    # Create temporary hosts entries
    cat >> /etc/hosts << EOF

# === SCPv2 Temporary DNS Mappings ===
10.1.1.111 www.${PRIVATE_DOMAIN}
10.1.2.121 app.${PRIVATE_DOMAIN}
10.1.3.131 db.${PRIVATE_DOMAIN}
# === End SCPv2 Mappings ===
EOF
    
    echo "✅ Local DNS mappings added to /etc/hosts"
    echo "   www.${PRIVATE_DOMAIN} -> 10.1.1.111"
    echo "   app.${PRIVATE_DOMAIN} -> 10.1.2.121"
    # DB endpoint type detection
    if [[ "10.1.3.131" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "   db.${PRIVATE_DOMAIN} -> 10.1.3.131 (VM-based DB)"
    else
        echo "   db.${PRIVATE_DOMAIN} -> 10.1.3.131 (PostgreSQL DBaaS)"
    fi
}

# Module 1: System Update (Compact)
sys_update() {
    echo "[1/5] System update..."
    until curl -s --connect-timeout 5 http://www.google.com >/dev/null 2>&1; do sleep 10; done
    for i in {1..3}; do dnf clean all && dnf install -y epel-release && break; sleep 30; done
    dnf -y update upgrade || true
    dnf install -y wget curl git jq htop net-tools chrony || true
    
    # Samsung SDS Cloud NTP configuration
    echo "server 198.19.0.54 iburst" >> /etc/chrony.conf
    systemctl enable chronyd && systemctl restart chronyd
    echo "✅ System updated with NTP"
}

# Module 2: Repository Clone
repo_clone() {
    echo "[2/5] Repository clone..."
    id rocky || (useradd -m rocky && usermod -aG wheel rocky)
    cd /home/rocky
    [ ! -d ceweb ] && sudo -u rocky git clone https://github.com/SCPv2/ceweb.git || true
    echo "✅ Repository ready"
}

# Module 3: Config Injection (Template substitution)
config_inject() {
    echo "[3/5] Config injection..."
    # Master configuration JSON will be injected here by userdata_manager.ps1
    # This contains all environment-specific variables including:
    # - Infrastructure settings (IPs, domains, ports)
    # - Database configuration (VM-based or DBaaS connection strings)
    # - Object storage settings (if applicable)
    # - Application-specific parameters
    cat > /home/rocky/master_config.json << 'CONFIG_EOF'
{"config_metadata":{"template_source":"variables.tf","version":"4.1.0","description":"Samsung Cloud Platform 3-Tier Architecture Master Configuration with DBaaS","created":"2025-10-14 13:22:01","usage":"This file contains all environment-specific settings for the application deployment","generator":"variables_manager.ps1"},"user_input_variables":{"object_storage_access_key_id":"0c75276b96964639a776543eff22eff2","public_domain_name":"creative-energy.net","keypair_name":"mykey","object_storage_secret_access_key":"424527a9-d22e-4321-8025-b8444f837048","_source":"variables.tf USER_INPUT category","private_domain_name":"cesvc.net","object_storage_bucket_string":"89097ddf09b84d96af496aded95dac29","user_public_ip":"14.39.93.74","_comment":"Variables that users input interactively during deployment"},"ceweb_required_variables":{"rollback_enabled":"true","database_host":"db.cesvc.net","nginx_port":"80","_source":"variables.tf CEWEB_REQUIRED category","app_lb_service_ip":"10.1.2.100","timezone":"Asia/Seoul","database_port":"2866","db_max_connections":"100","database_user":"cedbadmin","app_ip":"10.1.2.121","web_lb_service_ip":"10.1.1.100","git_branch":"main","auto_deployment":"true","database_name":"cedb","db_type":"postgresql","app_server_port":"3000","admin_email":"ars4mundus@gmail.com","company_name":"Creative Energy","backup_retention_days":"30","db_ip":"10.1.3.131","bastion_ip":"10.1.1.110","session_secret":"your-secret-key-change-in-production","_comment":"Variables required by ceweb application for business logic and functionality","_database_connection":{"db_ssl_enabled":false,"database_password":"cedbadmin123!","db_pool_idle_timeout":30000,"db_pool_min":20,"db_pool_connection_timeout":60000,"db_pool_max":100},"node_env":"production","web_ip":"10.1.1.111","git_repository":"https://github.com/SCPv2/ceweb.git","ssl_enabled":"false"},"_variable_classification":{"description":"ceweb application variable classification system","categories":{"user_input":"Variables that users input interactively during deployment","terraform_infra":"Variables used by terraform for infrastructure deployment","ceweb_required":"Variables required by ceweb application for business logic and database connections"}},"terraform_infra_variables":{"db_ip2":"10.1.3.33","_source":"variables.tf TERRAFORM_INFRA category","_comment":"Variables used by terraform for infrastructure deployment"}}
CONFIG_EOF
    chown rocky:rocky /home/rocky/master_config.json
    chmod 644 /home/rocky/master_config.json
    sudo -u rocky mkdir -p /home/rocky/ceweb/web-server
    cp /home/rocky/master_config.json /home/rocky/ceweb/web-server/
    chown rocky:rocky /home/rocky/ceweb/web-server/master_config.json
    jq . /home/rocky/master_config.json >/dev/null || exit 1
    echo "✅ Config injected"
}

# Module 4 & 5: Application Install and Verification (Server-specific - will be injected)
# 
# This section will be dynamically replaced by userdata_manager.ps1 with server-specific content:
# - For WEB servers: web_server_module.sh (Nginx, static file serving)
# - For APP servers: app_server_module.sh (Node.js, PM2, API server)
# - For DB servers:  db_server_module.sh (PostgreSQL VM installation)
#                    Note: Only used in VM-based DB scenarios (database_service)
#                    DBaaS scenarios (object_storage) skip DB server installation
#
# Each module contains both app_install() and verify_install() functions
# App Server Application Install Module  
app_install() {
    echo "[4/5] App server install..."
    
    # Install Node.js 20.x
    curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
    dnf install -y nodejs postgresql nmap-ncat
    npm install -g pm2
    
    # Load master config
    MASTER_CONFIG="/home/rocky/ceweb/web-server/master_config.json"
    PRIVATE_DOMAIN=$(jq -r '.user_input_variables.private_domain_name // "cesvc.net"' $MASTER_CONFIG)
    DB_HOST=$(jq -r '.ceweb_required_variables.database_host // "db.'$PRIVATE_DOMAIN'"' $MASTER_CONFIG)
    DB_PORT=$(jq -r '.ceweb_required_variables.database_port // "2866"' $MASTER_CONFIG)
    DB_NAME=$(jq -r '.ceweb_required_variables.database_name // "cedb"' $MASTER_CONFIG)
    DB_USER=$(jq -r '.ceweb_required_variables.database_user // "cedbadmin"' $MASTER_CONFIG)
    DB_PASSWORD=$(jq -r '.ceweb_required_variables.database_password // "cedbadmin123!"' $MASTER_CONFIG)
    
    # Wait for database with timeout
    echo "Waiting for database $DB_HOST:$DB_PORT..."
    for i in {1..30}; do
        if nc -z $DB_HOST $DB_PORT 2>/dev/null; then
            echo "✅ Database connection available"
            break
        elif [ $i -eq 30 ]; then
            echo "⚠️  Database timeout after 5 minutes, proceeding anyway..."
            break
        else
            echo "Attempt $i/30: Database not ready, waiting 10s..."
            sleep 10
        fi
    done
    
    # Create app directories  
    APP_DIR="/home/rocky/ceweb/app-server"
    sudo -u rocky mkdir -p $APP_DIR/logs
    sudo -u rocky mkdir -p /home/rocky/ceweb/files/audition
    
    # Create .env file
    cat > $APP_DIR/.env << EOF
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
PORT=3000
NODE_ENV=production
JWT_SECRET=$(openssl rand -hex 32 2>/dev/null || echo "default-jwt-secret-change-me")
EOF
    chown rocky:rocky $APP_DIR/.env && chmod 600 $APP_DIR/.env
    
    # Create PM2 ecosystem
    cat > $APP_DIR/ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'creative-energy-api',
    script: 'server.js',
    instances: 'max',
    exec_mode: 'cluster',
    env: { NODE_ENV: 'production', PORT: 3000 }
  }]
};
EOF
    chown rocky:rocky $APP_DIR/ecosystem.config.js
    
    # Install dependencies and start app
    cd $APP_DIR
    if [ -f package.json ]; then
        sudo -u rocky npm install
        sudo -u rocky pm2 start ecosystem.config.js
        sudo -u rocky pm2 save
    fi
    
    echo "✅ App server installed"
}

# App Server Verification Module
verify_install() {
    echo "[5/5] App verification..."
    
    # Check Node.js process
    pgrep -f node || exit 1
    
    # Check port 3000
    netstat -tlnp | grep :3000 || exit 1
    
    # Test API health endpoint
    for i in {1..30}; do
        if curl -f http://localhost:3000/health 2>/dev/null; then
            echo "✅ App server health check passed"
            break
        fi
        sleep 2
    done
    
    echo "✅ App server verified"
}

# Module 6: Local DNS Cleanup
local_dns_cleanup() {
    echo "[6/6] Local DNS Resolution cleanup..."
    
    # Remove SCPv2 temporary DNS mappings from /etc/hosts
    sudo sed -i '/# === SCPv2 Temporary DNS Mappings ===/,/# === End SCPv2 Mappings ===/d' /etc/hosts
    
    echo "✅ Local DNS mappings cleaned up from /etc/hosts"
}

# Main execution
main() {
    local_dns_setup
    sys_update
    repo_clone
    config_inject
    app_install
    # Custom web setup for web servers (if function exists)
    if [ "$SERVER_TYPE" = "web" ] && type custom_web_setup >/dev/null 2>&1; then
        custom_web_setup
    fi
    verify_install
    local_dns_cleanup
    echo "${SERVER_TYPE^} ready: $(date)" > /home/rocky/${SERVER_TYPE^}_Ready.log
    echo "=== ${SERVER_TYPE^} Init Complete: $(date) ==="
}

main