# Samsung Cloud Platform v2 - Variables Manager (PowerShell)
# Converts variables.tf to variables.json and handles user input
#
# Usage:
#   .\variables_manager.ps1         # Process variables interactively
#   .\variables_manager.ps1 -Debug  # Enable debug output
#   .\variables_manager.ps1 -Reset  # Reset variables to default values
#
# Based on: deploy_with_standardized_userdata.ps1 variable processing logic
# Author: SCPv2 Team

param(
    [switch]$Debug,
    [switch]$Reset
)

$ErrorActionPreference = "Stop"

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
$LogsDir = Join-Path $ProjectDir "lab_logs"
$VariablesTf = Join-Path $ProjectDir "variables.tf"
$VariablesJson = Join-Path $ScriptDir "variables.json"
# Image/Engine cache file removed - values now hardcoded in variables.tf

# Color functions
function Red($text) { Write-Host $text -ForegroundColor Red }
function Green($text) { Write-Host $text -ForegroundColor Green }
function Yellow($text) { Write-Host $text -ForegroundColor Yellow }
function Blue($text) { Write-Host $text -ForegroundColor Blue }
function Cyan($text) { Write-Host $text -ForegroundColor Cyan }

# Logging functions
function Write-Info($message) { Write-Host "[INFO] $message" }
function Write-Success($message) { Write-Host (Green "[SUCCESS] $message") }
function Write-Error($message) { Write-Host (Red "[ERROR] $message") }

# Create directories
function Initialize-Directories {
    if (!(Test-Path $LogsDir)) {
        New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null
    }
    Write-Success "Created lab_logs directory"
}

# Removed scpcli availability check - engine IDs now hardcoded in variables.tf

# Removed Get-ScpImageEngineIds function - engine IDs now hardcoded in variables.tf

# Removed Get-CachedImageEngineData function - engine IDs now hardcoded in variables.tf

# Removed Update-ImageEngineCache function - engine IDs now hardcoded in variables.tf

# Removed Get-ImageId function - images now handled by Terraform data sources

# Removed Get-PostgreSQLEngineId function - engine IDs now hardcoded in variables.tf

# Extract user input variables from variables.tf
function Get-UserInputVariables {
    Write-Info "Extracting USER_INPUT variables from variables.tf..."
    
    $content = Get-Content $VariablesTf -Raw
    $variables = @{}
    
    # Use regex to find variable blocks with [USER_INPUT] tag
    $pattern = 'variable\s+"([^"]+)"\s*{[^}]*description\s*=\s*"[^"]*\[USER_INPUT\][^"]*"[^}]*default\s*=\s*"([^"]*)"[^}]*}'
    $matches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    
    foreach ($match in $matches) {
        $varName = $match.Groups[1].Value
        $defaultValue = $match.Groups[2].Value
        $variables[$varName] = $defaultValue
        Write-Info "Found USER_INPUT variable: $varName = `"$defaultValue`""
    }
    
    return $variables
}

# Show discovered variables preview
function Show-VariablesPreview {
    param([hashtable]$UserVars)

    Write-Host ""
    Cyan "=== Discovered USER_INPUT Variables ==="
    Write-Host "Please check the default values below:" -ForegroundColor White
    Write-Host ""

    # Use the same custom order for preview
    $orderedVarNames = @(
        "user_public_ip",           # 1. Public IP
        "public_domain_name",       # 2. Public Domain Name
        "private_domain_name",      # 3. Private Domain Name
        "object_storage_access_key_id",  # 4. Auth Access Key
        "object_storage_secret_access_key",  # 5. Auth Secret Key
        "object_storage_bucket_string",  # 6. Account ID
        "keypair_name"              # 7. Keypair Name
    )

    # Add any remaining variables not in the ordered list
    $remainingVars = $UserVars.Keys | Where-Object { $_ -notin $orderedVarNames }
    $finalOrder = $orderedVarNames + $remainingVars

    foreach ($varName in $finalOrder) {
        if (-not $UserVars.ContainsKey($varName)) { continue }
        $defaultValue = $UserVars[$varName]

        # Get user-friendly name for display
        $displayName = switch ($varName) {
            "user_public_ip" { "1. Public IP" }
            "public_domain_name" { "2. Public Domain Name" }
            "private_domain_name" { "3. Private Domain Name" }
            "object_storage_access_key_id" { "4. Auth Access Key" }
            "object_storage_secret_access_key" { "5. Auth Secret Key" }
            "object_storage_bucket_string" { "6. Account ID" }
            "keypair_name" { "7. Keypair Name" }
            default { $varName }
        }

        Write-Host "  " -NoNewline
        Write-Host $displayName -ForegroundColor Yellow -NoNewline
        Write-Host ": " -NoNewline
        Write-Host $defaultValue -ForegroundColor Blue
    }

    Write-Host ""
    Write-Host -NoNewline "Do you want to change any values? " -ForegroundColor White
    Write-Host -NoNewline "[Y/n]: " -ForegroundColor Yellow
    $response = Read-Host

    return ($response -match "^[Yy]?$" -and $response -ne "n")
}

# Interactive user input collection
function Get-UserInput {
    param([hashtable]$UserVars)
    
    Write-Info "🔍 Collecting user input variables..."
    
    do {
        # Show preview and ask if user wants to change
        $wantsToChange = Show-VariablesPreview $UserVars
        
        if (-not $wantsToChange) {
            Write-Info "Using all default values"
            $updatedVars = $UserVars
        } else {
            $updatedVars = @{}
            
            Write-Host ""
            Cyan "=== Variable Input Session ==="
            Write-Host "Press Enter to keep default value, or type new value:" -ForegroundColor White

            # Define custom order for user input
            $orderedVarNames = @(
                "user_public_ip",           # 1. Public IP
                "public_domain_name",       # 2. Public Domain Name
                "private_domain_name",      # 3. Private Domain Name
                "object_storage_access_key_id",  # 4. Auth Access Key
                "object_storage_secret_access_key",  # 5. Auth Secret Key
                "object_storage_bucket_string",  # 6. Account ID
                "keypair_name"              # 7. Keypair Name
            )

            # Add any remaining variables not in the ordered list
            $remainingVars = $UserVars.Keys | Where-Object { $_ -notin $orderedVarNames }
            $finalOrder = $orderedVarNames + $remainingVars

            foreach ($varName in $finalOrder) {
                if (-not $UserVars.ContainsKey($varName)) { continue }
                $defaultValue = $UserVars[$varName]

                # Get user-friendly name for display
                $displayName = switch ($varName) {
                    "user_public_ip" { "1. Public IP" }
                    "public_domain_name" { "2. Public Domain Name" }
                    "private_domain_name" { "3. Private Domain Name" }
                    "object_storage_access_key_id" { "4. Auth Access Key" }
                    "object_storage_secret_access_key" { "5. Auth Secret Key" }
                    "object_storage_bucket_string" { "6. Account ID" }
                    "keypair_name" { "7. Keypair Name" }
                    default { $varName }
                }

                Write-Host ""
                Write-Host $displayName -ForegroundColor Yellow -NoNewline
                Write-Host " ?" -ForegroundColor Yellow
                Write-Host "Default(Enter): " -ForegroundColor Cyan -NoNewline
                Write-Host $defaultValue -ForegroundColor Blue
                Write-Host -NoNewline "New Value: " -ForegroundColor White
                $userInput = Read-Host

                $finalValue = if ([string]::IsNullOrWhiteSpace($userInput)) { $defaultValue } else { $userInput }
                $updatedVars[$varName] = $finalValue
            }
        }
        
        # Show final confirmation and handle retry
        $confirmResult = Show-FinalConfirmation $updatedVars
        
        if ($confirmResult -eq "confirmed") {
            return $updatedVars
        }
        # If "retry", loop continues
        
    } while ($true)
}

# Show final confirmation of all values
function Show-FinalConfirmation {
    param([hashtable]$UpdatedVars)
    
    do {
        Write-Host ""
        Cyan "=== Final Configuration Review ==="
        Write-Host "Please review your configuration:" -ForegroundColor White
        Write-Host ""

        # Use the same custom order for final review
        $orderedVarNames = @(
            "user_public_ip",           # 1. Public IP
            "public_domain_name",       # 2. Public Domain Name
            "private_domain_name",      # 3. Private Domain Name
            "object_storage_access_key_id",  # 4. Auth Access Key
            "object_storage_secret_access_key",  # 5. Auth Secret Key
            "object_storage_bucket_string",  # 6. Account ID
            "keypair_name"              # 7. Keypair Name
        )

        # Add any remaining variables not in the ordered list
        $remainingVars = $UpdatedVars.Keys | Where-Object { $_ -notin $orderedVarNames }
        $finalOrder = $orderedVarNames + $remainingVars

        foreach ($varName in $finalOrder) {
            if (-not $UpdatedVars.ContainsKey($varName)) { continue }
            $value = $UpdatedVars[$varName]

            # Get user-friendly name for display
            $displayName = switch ($varName) {
                "user_public_ip" { "1. Public IP" }
                "public_domain_name" { "2. Public Domain Name" }
                "private_domain_name" { "3. Private Domain Name" }
                "object_storage_access_key_id" { "4. Auth Access Key" }
                "object_storage_secret_access_key" { "5. Auth Secret Key" }
                "object_storage_bucket_string" { "6. Account ID" }
                "keypair_name" { "7. Keypair Name" }
                default { $varName }
            }

            Write-Host "  " -NoNewline
            Write-Host $displayName -ForegroundColor Yellow -NoNewline
            Write-Host ": " -NoNewline
            Write-Host $value -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host -NoNewline "Would you like to confirm and proceed? " -ForegroundColor White
        Write-Host -NoNewline "[Y/n/r(retry)]: " -ForegroundColor Yellow
        $confirmation = Read-Host
        
        if ($confirmation -match "^[Nn]$") {
            Write-Host ""
            Yellow "Options:"
            Write-Host "- Press Enter or 'Y' to proceed with current configuration"
            Write-Host "- Type 'r' to modify variables again"
            Write-Host "- Type 'q' to quit"
            Write-Host -NoNewline "Choice: " -ForegroundColor White
            $choice = Read-Host
            
            if ($choice -match "^[Qq]$") {
                Write-Host "Configuration cancelled by user." -ForegroundColor Red
                exit 1
            } elseif ($choice -match "^[Rr]$") {
                return "retry"
            } else {
                Write-Success "Configuration confirmed! Proceeding with deployment..."
                return "confirmed"
            }
        } elseif ($confirmation -match "^[Rr]$") {
            return "retry"
        } else {
            Write-Success "Configuration confirmed! Proceeding with deployment..."
            return "confirmed"
        }
    } while ($true)
}

# Extract CEWEB_REQUIRED variables from variables.tf
function Get-CewebRequiredVariables {
    Write-Info "Extracting CEWEB_REQUIRED variables from variables.tf..."
    
    $content = Get-Content $VariablesTf -Raw
    $variables = @{}
    
    # Use regex to find variable blocks with [CEWEB_REQUIRED] tag
    $patterns = @(
        'variable\s+"([^"]+)"\s*{[^}]*description\s*=\s*"[^"]*\[CEWEB_REQUIRED\][^"]*"[^}]*default\s*=\s*"([^"]*)"[^}]*}',
        'variable\s+"([^"]+)"\s*{[^}]*description\s*=\s*"[^"]*\[CEWEB_REQUIRED\][^"]*"[^}]*default\s*=\s*(\d+)[^}]*}',
        'variable\s+"([^"]+)"\s*{[^}]*description\s*=\s*"[^"]*\[CEWEB_REQUIRED\][^"]*"[^}]*default\s*=\s*(true|false)[^}]*}'
    )
    
    foreach ($pattern in $patterns) {
        $matches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
        foreach ($match in $matches) {
            $varName = $match.Groups[1].Value
            $defaultValue = $match.Groups[2].Value
            $variables[$varName] = $defaultValue
        }
    }
    
    return $variables
}

# Update variables.tf with user input values
function Update-VariablesTf {
    param([hashtable]$UserInputVars)
    
    Write-Info "📝 Updating variables.tf with user input values..."
    
    # Create backup in lab_logs directory
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backupFile = Join-Path $LogsDir "variables.tf.backup.$timestamp"
    
    # Ensure lab_logs directory exists
    if (!(Test-Path $LogsDir)) {
        New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null
    }
    
    Copy-Item $VariablesTf $backupFile
    Write-Info "Backup created: $backupFile"
    
    # Read current content
    $content = Get-Content $VariablesTf -Raw
    
    # Update each user input variable
    foreach ($varName in $UserInputVars.Keys) {
        $varValue = $UserInputVars[$varName]
        Write-Info "Updating $varName = `"$varValue`""
        
        # Pattern to match variable block and update default value
        $pattern = "(variable\s+`"$varName`"[^}]*default\s*=\s*)`"[^`"]*`""
        $replacement = "`${1}`"$varValue`""
        
        $content = $content -replace $pattern, $replacement
    }
    
    # Save updated content
    Set-Content -Path $VariablesTf -Value $content -Encoding UTF8
    
    Write-Success "variables.tf updated with user input values"
    
    # Skip Terraform validation - it will be handled by terraform_manager
    Write-Info "Variables.tf updated successfully (Terraform validation will be done in terraform_manager)"
}

# Generate variables.json from collected data
function New-VariablesJson {
    param(
        [hashtable]$UserInputVars,
        [hashtable]$CewebRequiredVars
    )
    
    Write-Info "📊 Generating variables.json..."
    
    # Create configuration object
    $config = [PSCustomObject]@{
        "_variable_classification" = [PSCustomObject]@{
            "description" = "ceweb application variable classification system"
            "categories" = [PSCustomObject]@{
                "user_input" = "Variables that users input interactively during deployment"
                "ceweb_required" = "Variables required by ceweb application for business logic and database connections"
            }
        }
        "config_metadata" = [PSCustomObject]@{
            "version" = "4.0.0"
            "created" = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            "description" = "Samsung Cloud Platform 3-Tier Architecture Master Configuration"
            "usage" = "This file contains all environment-specific settings for the application deployment"
            "generator" = "variables_manager.ps1"
            "template_source" = "variables.tf"
        }
        "user_input_variables" = [PSCustomObject]@{
            "_comment" = "Variables that users input interactively during deployment"
            "_source" = "variables.tf USER_INPUT category"
        }
        "ceweb_required_variables" = [PSCustomObject]@{
            "_comment" = "Variables required by ceweb application for business logic and functionality"
            "_source" = "variables.tf CEWEB_REQUIRED category"
            "_database_connection" = [PSCustomObject]@{
                "database_password" = "cedbadmin123!"
                "db_ssl_enabled" = $false
                "db_pool_min" = 20
                "db_pool_max" = 100
                "db_pool_idle_timeout" = 30000
                "db_pool_connection_timeout" = 60000
            }
        }
    }
    
    # Add user input variables
    foreach ($varName in $UserInputVars.Keys) {
        $config.user_input_variables | Add-Member -MemberType NoteProperty -Name $varName -Value $UserInputVars[$varName]
    }
    
    # Add CEWEB required variables  
    foreach ($varName in $CewebRequiredVars.Keys) {
        $config.ceweb_required_variables | Add-Member -MemberType NoteProperty -Name $varName -Value $CewebRequiredVars[$varName]
    }
    
    # Convert to JSON and save
    $jsonContent = $config | ConvertTo-Json -Depth 10
    Set-Content -Path $VariablesJson -Value $jsonContent -Encoding UTF8
    
    Write-Success "Variables.json generated successfully"
    
    # Display summary
    Write-Host ""
    Cyan "=== Variables Summary ==="
    Write-Host "$(Green 'User Input Variables:') $($UserInputVars.Count) items"
    Write-Host "$(Green 'CEWEB Required Variables:') $($CewebRequiredVars.Count) items"  
    Write-Host "$(Green 'Output File:') $VariablesJson"
    Write-Host "$(Green 'Updated File:') $VariablesTf"
    Write-Host ""
}

# Reset user input variables to defaults
function Reset-UserInputVariables {
    Write-Info "🔄 Resetting user input variables to default values..."
    
    $defaultValuesFile = Resolve-Path (Join-Path $ProjectDir "..\common-script\default_user_input_values.json")
    
    # Check if default values file exists
    if (!(Test-Path $defaultValuesFile)) {
        Write-Error "Default values file not found: $defaultValuesFile"
        return $false
    }
    
    # Load default values
    try {
        $defaultValues = Get-Content $defaultValuesFile | ConvertFrom-Json
        Write-Info "Loaded default values from: $defaultValuesFile"
    } catch {
        Write-Error "Failed to parse default values file: $($_.Exception.Message)"
        return $false
    }
    
    # Create backup in lab_logs directory
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backupFile = Join-Path $LogsDir "variables.tf.backup.reset.$timestamp"
    
    # Ensure lab_logs directory exists
    if (!(Test-Path $LogsDir)) {
        New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null
    }
    
    Copy-Item $VariablesTf $backupFile
    Write-Info "Backup created: $backupFile"
    
    # Read current variables.tf content
    $content = Get-Content $VariablesTf -Raw
    
    # Reset each user input variable to its default value
    foreach ($varName in $defaultValues.user_input_variables.PSObject.Properties.Name) {
        $defaultValue = $defaultValues.user_input_variables.$varName
        
        # Pattern to match the variable block and replace the default value
        $pattern = '(?s)(variable\s+"' + [regex]::Escape($varName) + '"\s*\{[^}]*?default\s*=\s*)"[^"]*"([^}]*?\})'
        $replacement = '${1}"' + $defaultValue + '"${2}'
        
        if ($content -match $pattern) {
            $content = $content -replace $pattern, $replacement
            Write-Info "Reset $varName to: $defaultValue"
        } else {
            Write-Warning "Could not find variable pattern for: $varName"
        }
    }
    
    # Write updated content back to variables.tf
    Set-Content -Path $VariablesTf -Value $content -Encoding UTF8
    
    Write-Success "✅ User input variables reset to default values"
    Write-Info "Original file backed up as: $(Split-Path -Leaf $backupFile)"
    
    return $true
}

# Update variables.tf with image/engine IDs
# Removed Update-VariablesTfWithImageEngineIds function - IDs now hardcoded in variables.tf
    

# Enhanced JSON generation with image/engine data
function New-VariablesJson {
    param(
        [hashtable]$UserInputVars,
        [hashtable]$CewebRequiredVars
    )

    Write-Info "📄 Generating variables.json..."
    
    # Create comprehensive variables structure
    $variablesData = @{
        "_variable_classification" = @{
            description = "ceweb application variable classification system"
            categories = @{
                user_input = "Variables that users input interactively during deployment"
                ceweb_required = "Variables required by ceweb application for business logic and database connections"
                terraform_infra = "Variables used by terraform for infrastructure deployment"
            }
        }
        "config_metadata" = @{
            version = "4.1.0"
            created = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            description = "Samsung Cloud Platform 3-Tier Architecture Master Configuration with DBaaS"
            usage = "This file contains all environment-specific settings for the application deployment"
            generator = "variables_manager.ps1"
            template_source = "variables.tf"
        }
        "user_input_variables" = @{
            _comment = "Variables that users input interactively during deployment"
            _source = "variables.tf USER_INPUT category"
        }
        "ceweb_required_variables" = @{
            _comment = "Variables required by ceweb application for business logic and functionality"
            _source = "variables.tf CEWEB_REQUIRED category"
            "_database_connection" = @{
                database_password = $CewebRequiredVars["database_password"]
                db_ssl_enabled = $false
                db_pool_min = 20
                db_pool_max = 100
                db_pool_idle_timeout = 30000
                db_pool_connection_timeout = 60000
            }
        }
        "terraform_infra_variables" = @{
            _comment = "Variables used by terraform for infrastructure deployment"
            _source = "variables.tf TERRAFORM_INFRA category"

            # Include db_ip2 for Active-Standby configuration
            db_ip2 = "10.1.3.33"
        }
    }
    
    # Add user input variables
    foreach ($key in $UserInputVars.Keys) {
        $variablesData.user_input_variables[$key] = $UserInputVars[$key]
    }
    
    # Add ceweb required variables with dynamic database_host
    foreach ($key in $CewebRequiredVars.Keys) {
        if ($key -ne "database_password") {  # Already added to _database_connection
            if ($key -eq "database_host") {
                # Dynamically generate database_host from private_domain_name
                $privateDomain = $UserInputVars["private_domain_name"]
                if ($privateDomain) {
                    $variablesData.ceweb_required_variables[$key] = "db.$privateDomain"
                    Write-Info "Generated dynamic database_host: db.$privateDomain"
                } else {
                    # Fallback to default if private_domain_name not found
                    $variablesData.ceweb_required_variables[$key] = "db.internal.local"
                    Write-Warning "private_domain_name not found, using default: db.internal.local"
                }
            } else {
                $variablesData.ceweb_required_variables[$key] = $CewebRequiredVars[$key]
            }
        }
    }
    
    # Save to file
    $variablesData | ConvertTo-Json -Depth 10 | Set-Content $VariablesJson -Encoding UTF8
    
    Write-Success "Generated variables.json"
    Write-Info "File: $VariablesJson"
}

# Generate upload_to_object_storage.sh with hardcoded credentials
function New-UploadToObjectStorageScript {
    param([hashtable]$UserInputVars)

    Write-Info "📝 Generating upload_to_object_storage.sh script with hardcoded credentials..."

    $scriptPath = Join-Path $ScriptDir "upload_to_object_storage.sh"

    # Extract values
    $accessKey = $UserInputVars["object_storage_access_key_id"]
    $secretKey = $UserInputVars["object_storage_secret_access_key"]
    $bucketString = $UserInputVars["object_storage_bucket_string"]

    # Create the script content with hardcoded values
    $scriptContent = @"
#!/bin/bash

# Object Storage Upload Script with Hardcoded Credentials
# Samsung Cloud Platform v2 - Object Storage Integration
# Generated by variables_manager.ps1 on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
# 스크립트를 홈 디렉토리(/home/rocky/)에서 실행
cd /home/rocky/

echo "========================================="
echo "Object Storage Upload Script"
echo "Samsung Cloud Platform v2"
echo "========================================="

# 색상 함수
red() { echo -e "\033[31m`$1\033[0m"; }
green() { echo -e "\033[32m`$1\033[0m"; }
yellow() { echo -e "\033[33m`$1\033[0m"; }
cyan() { echo -e "\033[36m`$1\033[0m"; }

# 로깅 함수
log_info() { echo "[INFO] `$1"; }
log_success() { echo "`$(green "[SUCCESS]") `$1"; }
log_error() { echo "`$(red "[ERROR]") `$1"; }
log_warning() { echo "`$(yellow "[WARNING]") `$1"; }

# Hardcoded Object Storage credentials
ACCESS_KEY="$accessKey"
SECRET_KEY="$secretKey"
BUCKET_STRING="$bucketString"

# Object Storage 엔드포인트 설정 (README.md 참조)
ENDPOINT_URL="https://object-store.private.kr-west1.e.samsungsdscloud.com"
BUCKET_NAME="ceweb"
REGION="kr-west1"

log_success "Object Storage configuration loaded (hardcoded):"
echo "  Access Key: `${ACCESS_KEY:0:8}..."
echo "  Bucket String: `$BUCKET_STRING"
echo "  Endpoint: `$ENDPOINT_URL"
echo "  Bucket Name: `$BUCKET_NAME"

# AWS CLI 설치 확인 및 설치 (README.md 참조)
log_info "Checking AWS CLI installation..."

if command -v aws &> /dev/null; then
    AWS_VERSION=`$(aws --version 2>&1 | cut -d' ' -f1 | cut -d'/' -f2)
    log_info "AWS CLI is already installed (version: `$AWS_VERSION)"

    # 버전 2.x인지 확인
    if [[ "`$AWS_VERSION" < "2.0" ]]; then
        log_warning "AWS CLI version 1.x detected, upgrading to version 2..."
        INSTALL_AWSCLI=true
    else
        log_success "AWS CLI version 2.x is already installed"
        INSTALL_AWSCLI=false
    fi
else
    log_info "AWS CLI not found, installing AWS CLI v2..."
    INSTALL_AWSCLI=true
fi

if [ "`$INSTALL_AWSCLI" = true ]; then
    # README.md에 따른 AWS CLI 설치 과정
    log_info "Installing AWS CLI following README.md instructions..."

    # 기존 설치 삭제
    sudo yum remove -y awscli 2>/dev/null || true

    # Object Storage를 위한 AWS CLI 설치
    sudo dnf install -y unzip
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-2.22.35.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install

    # 정리
    rm -rf aws awscliv2.zip

    log_success "AWS CLI v2 installed successfully"
fi

# AWS CLI 환경 구성 (README.md 참조)
log_info "Configuring AWS CLI for Object Storage..."

# AWS credentials 파일 생성
cd /home/rocky/
mkdir -p ~/.aws

cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = `$ACCESS_KEY
aws_secret_access_key = `$SECRET_KEY
EOF

cat > ~/.aws/config << EOF
[default]
region = `$REGION
EOF

chmod 600 ~/.aws/credentials ~/.aws/config

log_success "AWS CLI configured successfully"

# 연결 테스트
log_info "Testing Object Storage connection..."
if aws s3 ls s3://`$BUCKET_NAME --endpoint-url `$ENDPOINT_URL >/dev/null 2>&1; then
    log_success "Object Storage connection successful"
else
    log_warning "Object Storage connection test failed, but proceeding..."
    log_info "This may be normal if the bucket doesn't exist yet"
fi

# 미디어 디렉토리 확인
MEDIA_DIR="./ceweb/media"
if [ ! -d "`$MEDIA_DIR" ]; then
    log_error "Media directory not found: `$MEDIA_DIR"
    log_error "Please ensure the web application is properly deployed"
    exit 1
fi

# 미디어 파일 현황 확인
log_info "Checking media directory contents..."
TOTAL_FILES=`$(find "`$MEDIA_DIR" -type f | wc -l)
TOTAL_SIZE=`$(du -sh "`$MEDIA_DIR" 2>/dev/null | cut -f1)

if [ "`$TOTAL_FILES" -eq 0 ]; then
    log_warning "No files found in `$MEDIA_DIR"
    echo "Nothing to upload."
    exit 0
fi

log_info "Found `$TOTAL_FILES files (`$TOTAL_SIZE) in `$MEDIA_DIR"

# 사용자 확인 (기본값 Y)
echo ""
yellow "========================================="
yellow "UPLOAD CONFIRMATION"
yellow "========================================="
echo ""
echo "The following will be uploaded to Object Storage:"
echo "  Source: `$MEDIA_DIR"
echo "  Destination: s3://`$BUCKET_NAME/media"
echo "  Endpoint: `$ENDPOINT_URL"
echo "  Files: `$TOTAL_FILES files (`$TOTAL_SIZE)"
echo ""

# 기본값이 Y인 확인
read -p "`$(yellow "Do you want to proceed with the upload? [Y/n]: ")" -n 1 -r
echo

# 기본값 처리 (엔터만 누른 경우 Y로 처리)
if [[ -z "`$REPLY" ]]; then
    REPLY="Y"
fi

if [[ ! `$REPLY =~ ^[Yy]`$ ]]; then
    log_info "Upload cancelled by user"
    exit 0
fi

# Object Storage로 업로드 (README.md의 명령 참조)
log_info "Starting upload to Object Storage..."
echo ""

# README.md 명령: aws s3 cp media s3://{버킷명}/media --recursive --endpoint-url [Private Endpoint명]
cd /home/rocky/ceweb

log_info "Executing: aws s3 cp media s3://`$BUCKET_NAME/media --recursive --endpoint-url `$ENDPOINT_URL"

aws s3 cp media "s3://`$BUCKET_NAME/media" --recursive --endpoint-url "`$ENDPOINT_URL"

UPLOAD_RESULT=`$?

if [ `$UPLOAD_RESULT -eq 0 ]; then
    log_success "Upload completed successfully!"
    echo ""

    # 업로드 확인
    log_info "Verifying upload..."
    UPLOADED_FILES=`$(aws s3 ls "s3://`$BUCKET_NAME/media" --recursive --endpoint-url "`$ENDPOINT_URL" | wc -l)
    log_success "Verified: `$UPLOADED_FILES files uploaded"

    # Public URL 정보 제공 (README.md 참조)
    echo ""
    cyan "========================================="
    cyan "OBJECT STORAGE INFORMATION"
    cyan "========================================="
    echo ""
    echo "`$(green "Files successfully uploaded to Object Storage")"
    echo ""
    echo "Public URL structure:"
    echo "  https://object-store.kr-west1.e.samsungsdscloud.com/`$BUCKET_STRING:`$BUCKET_NAME/media/[filename]"
    echo ""
    echo "Private URL structure:"
    echo "  `$ENDPOINT_URL/`$BUCKET_STRING:`$BUCKET_NAME/media/[filename]"
    echo ""
    echo "Web application configuration:"
    echo "  Update your web application to use the Object Storage URLs"
    echo "  for serving static media files."
    echo ""

    # README.md에 언급된 애플리케이션 전환 방법 안내
    echo "`$(cyan "Next steps (from README.md):")"
    echo "  1. Update web server paths from './media' to Object Storage URLs"
    echo "  2. Consider switching application files:"
    echo "     mv index.html index_bk.html"
    echo "     mv index_obj.html index.html"
    echo ""
else
    log_error "Upload failed with exit code `$UPLOAD_RESULT"
    log_error "Please check your Object Storage configuration and network connectivity"
    exit 1
fi

echo ""
log_success "Object Storage upload script completed successfully!"
echo "========================================="
"@

    # Save the script
    Set-Content -Path $scriptPath -Value $scriptContent -Encoding UTF8

    Write-Success "Generated upload_to_object_storage.sh with hardcoded credentials"
    Write-Info "  Access Key: $($accessKey.Substring(0,8))..."
    Write-Info "  Bucket String: $bucketString"
    Write-Info "  Script saved to: $scriptPath"
}

# Main execution
function Main {
    Write-Info "🚀 Samsung Cloud Platform v2 - Variables Manager"

    # Check prerequisites
    if (!(Test-Path $VariablesTf)) {
        Write-Error "variables.tf not found: $VariablesTf"
        exit 1
    }

    # Setup directories
    Initialize-Directories

    # Extract variables from variables.tf
    $userInputVars = Get-UserInputVariables
    if ($userInputVars.Count -eq 0) {
        Write-Error "No USER_INPUT variables found in variables.tf"
        exit 1
    }

    $cewebRequiredVars = Get-CewebRequiredVariables
    Write-Info "Found $($cewebRequiredVars.Count) CEWEB_REQUIRED variables"

    # Collect user input
    $updatedUserVars = Get-UserInput $userInputVars

    # Update variables.tf with user input
    Update-VariablesTf $updatedUserVars

    # Generate variables.json
    New-VariablesJson $updatedUserVars $cewebRequiredVars

    # Generate upload_to_object_storage.sh with hardcoded values
    New-UploadToObjectStorageScript $updatedUserVars

    Write-Success "✅ Variables processing completed successfully!"
    Write-Info "📁 Generated files:"
    Write-Info "  • variables.json: $VariablesJson"
    Write-Info "  • upload_to_object_storage.sh: $(Join-Path $ScriptDir 'upload_to_object_storage.sh')"
    Write-Info "Next step: Run userdata_manager.ps1 to generate UserData files"
    
    return 0
}

# Set debug mode
if ($Debug) {
    $env:DEBUG_MODE = "true"
}

# Run appropriate function based on parameters
try {
    if ($Reset) {
        # Direct reset without user interaction
        if (Reset-UserInputVariables) {
            Write-Success "✅ Variables reset completed successfully!"
            exit 0
        } else {
            Write-Error "❌ Variables reset failed!"
            exit 1
        }
    } else {
        # Normal interactive mode
        exit (Main)
    }
} catch {
    Write-Error "Variables processing failed: $($_.Exception.Message)"
    exit 1
}