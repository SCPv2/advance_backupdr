# Storage 백업 구성

## 선행 실습

### 선택 '[과정 소개](https://github.com/SCPv2/ce_advance_introduction/blob/main/README.md)'

- Key Pair, 인증키, DNS 등 사전 준비

### 선택 '[Terraform을 이용한 클라우드 자원 배포](https://github.com/SCPv2/advance_iac/blob/main/terraform/README.md)'

- Samsung Cloud Platform v2 기반 Terraform 학습

## 실습 환경 배포

**&#128906; 사용자 환경 구성 (\advance_backupdr\storage_backup\env_setup.ps1)**

**&#128906; Terraform 자원 배포 템플릿 실행**

```bash
terraform init
terraform validate
terraform plan

terraform apply --auto-approve
```

## 환경 검토

- Architectuer Diagram
- VPC CIDR
- Subnet CIDR
- Virtual Server OS, Public IP, Private IP
- Firewall 규칙
- Security Group 규칙

### Firewall

|Deployment|Firewall|Source|Destination|Service|Action|Direction|Description|
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----|
|Terraform|kr-west1 IGW|10.1.1.0/24|0.0.0.0/0|TCP 80, 443|Allow|Outbound|HTTP/HTTPS outbound from vm to Internet|
|Terraform|kr-west1 IGW|0.0.0.0/0|10.1.1.0/24|TCP 80|Allow|Inbound|HTTP inbound to vm|
|Terraform|kr-east1 IGW|10.1.1.0/24|0.0.0.0/0|TCP 80, 443|Allow|Outbound|HTTP/HTTPS outbound from vm to Internet|
|Terraform|kr-east1 IGW|0.0.0.0/0|10.1.1.0/24|TCP 80|Allow|Inbound|HTTP inbound to vm|

### Security Group

|Deployment|Security Group|Direction|Target Address/Remote SG|Service|Description|
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----|
|Terrafom|kr-west1 webSG|Outbound|0.0.0.0/0|TCP 443|HTTPS outbound to Internet|
|Terrafom|kr-west1 webSG|Outbound|0.0.0.0/0|TCP 80|HTTP outbound to Internet|
|Terrafom|kr-west1 webSG|Inbound|0.0.0.0/0|TCP 80|HTTP inbound from your PC|
|||||||
|Terrafom|kr-east1 webSG|Outbound|0.0.0.0/0|TCP 443|HTTPS outbound to Internet|
|Terrafom|kr-east1 webSG|Outbound|0.0.0.0/0|TCP 80|HTTP outbound to Internet|
|Terrafom|kr-east1 webSG|Inbound|0.0.0.0/0|TCP 80|HTTP inbound from your PC|

## File Storage 생성 및 서버 연결

- 볼륨명 : `cefs`
- 디스크 유형 : HDD
- 프로토콜 : NFS

- 연결자원 : webvm111r

## File Storage Mount Script

```bash
cd /home/rocky
sudo vi mount_file_storage.sh
```

```bash
#!/bin/bash

# File Storage Mount Script
# 스크립트를 홈 디렉토리(/home/rocky/)에서 실행
cd /home/rocky/

echo "========================================="
echo "File Storage Mount Script"
echo "========================================="

# 사용자 입력 받기 (마운트 소스만)
echo -n "Enter File Storage mount source (e.g., 10.10.10.10:/filestorage): "
read MOUNT_SOURCE

# 입력값 확인
if [ -z "$MOUNT_SOURCE" ]; then
    echo "Error: Mount source is required!"
    exit 1
fi

# 고정 경로 설정
MOUNT_PATH="/home/rocky/ceweb/media"
BACKUP_PATH="/home/rocky/ceweb/media1"

echo ""
echo "Mount Configuration:"
echo "  Source: $MOUNT_SOURCE"
echo "  Mount Path: $MOUNT_PATH"
echo ""

# 기존 media 디렉토리를 media1로 백업
echo "Backing up existing media directory..."
if [ -d "$MOUNT_PATH" ]; then
    if [ -d "$BACKUP_PATH" ]; then
        echo "  Warning: Backup directory $BACKUP_PATH already exists!"
        echo -n "  Do you want to remove it? (y/n): "
        read REMOVE_BACKUP
        if [ "$REMOVE_BACKUP" = "y" ]; then
            rm -rf "$BACKUP_PATH"
            echo "  Removed existing backup directory"
        else
            echo "  Please handle the existing backup directory manually"
            exit 1
        fi
    fi
    mv "$MOUNT_PATH" "$BACKUP_PATH"
    echo "  Moved $MOUNT_PATH to $BACKUP_PATH"
else
    echo "  No existing media directory found"
fi

# 새로운 media 디렉토리 생성
echo "Creating mount directory..."
mkdir -p "$MOUNT_PATH"
echo "  Created: $MOUNT_PATH"

# nfs-utils 설치 확인 및 설치
echo ""
echo "Checking nfs-utils..."
if ! rpm -qa | grep -q nfs-utils; then
    echo "Installing nfs-utils..."
    sudo dnf install nfs-utils -y
else
    echo "  nfs-utils already installed"
fi

# rpcbind 서비스 활성화 및 시작
echo ""
echo "Configuring rpcbind service..."
sudo systemctl enable rpcbind.service
sudo systemctl start rpcbind.service
echo "  rpcbind service enabled and started"

# /etc/fstab 백업
echo ""
echo "Backing up /etc/fstab..."
sudo cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d_%H%M%S)
echo "  Backup created"

# /etc/fstab 에 마운트 정보가 이미 있는지 확인
echo ""
echo "Checking /etc/fstab for existing mount..."
if grep -q "$MOUNT_SOURCE" /etc/fstab; then
    echo "  Warning: Mount source already exists in /etc/fstab"
    echo -n "  Do you want to update it? (y/n): "
    read UPDATE_FSTAB
    if [ "$UPDATE_FSTAB" = "y" ]; then
        sudo sed -i "/$MOUNT_SOURCE/d" /etc/fstab
        echo "  Removed existing entry"
    else
        echo "  Skipping fstab update"
        SKIP_FSTAB="true"
    fi
fi

# /etc/fstab에 마운트 정보 추가
if [ "$SKIP_FSTAB" != "true" ]; then
    echo ""
    echo "Adding mount to /etc/fstab..."
    echo "$MOUNT_SOURCE $MOUNT_PATH nfs defaults,vers=3,_netdev,noresvport 0 0" | sudo tee -a /etc/fstab > /dev/null
    echo "  Mount entry added to /etc/fstab"
fi

# 데몬 리로드
echo ""
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload
echo "  Daemon reloaded"

# 마운트 실행
echo ""
echo "Mounting file storage..."
sudo mount -t nfs -o vers=3,noresvport "$MOUNT_SOURCE" "$MOUNT_PATH"

# 마운트 상태 확인
echo ""
echo "Checking mount status..."
if mount | grep -q "$MOUNT_SOURCE"; then
    echo "  SUCCESS: File storage mounted successfully!"
    echo ""
    echo "Mount details:"
    df -h | head -1
    df -h | grep "$MOUNT_SOURCE"

    # 백업된 데이터 이동
    if [ -d "$BACKUP_PATH" ]; then
        echo ""
        echo "Moving backed up data to mounted storage..."

        # rsync 또는 cp를 사용하여 데이터 이동 (권한 유지)
        if command -v rsync &> /dev/null; then
            rsync -av "$BACKUP_PATH/" "$MOUNT_PATH/"
            echo "  Data moved using rsync"
        else
            cp -rpf "$BACKUP_PATH/"* "$MOUNT_PATH/" 2>/dev/null || true
            cp -rpf "$BACKUP_PATH/".* "$MOUNT_PATH/" 2>/dev/null || true
            echo "  Data moved using cp"
        fi

        # 백업 디렉토리 삭제
        echo "Removing backup directory..."
        rm -rf "$BACKUP_PATH"
        echo "  Removed: $BACKUP_PATH"

        echo ""
        echo "Data migration completed successfully!"
    fi
else
    echo "  ERROR: Failed to mount file storage"
    echo "  Please check the mount source and network connectivity"

    # 마운트 실패 시 백업 복원
    if [ -d "$BACKUP_PATH" ] && [ ! -d "$MOUNT_PATH" ]; then
        echo "  Restoring original media directory..."
        mv "$BACKUP_PATH" "$MOUNT_PATH"
        echo "  Restored: $MOUNT_PATH"
    fi
    exit 1
fi

echo ""
echo "========================================="
echo "File Storage Mount Complete!"
echo "========================================="
```

```bash
sudo vi mount_file_storage.sh
```

## Object Storage 생성 및 콘텐츠 업로드

- 버킷명 : `ceweb`

## Object Storage 연결

```bash
cd /home/rocky
sudo vi upload_to_object_storage.sh
```

```bash
#!/bin/bash

# Object Storage Upload Script with Hardcoded Credentials
# Samsung Cloud Platform v2 - Object Storage Integration
# Generated by variables_manager.ps1 on 2025-09-30 20:28:55
# 스크립트를 홈 디렉토리(/home/rocky/)에서 실행
cd /home/rocky/

echo "========================================="
echo "Object Storage Upload Script"
echo "Samsung Cloud Platform v2"
echo "========================================="

# 색상 함수
red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
yellow() { echo -e "\033[33m$1\033[0m"; }
cyan() { echo -e "\033[36m$1\033[0m"; }

# 로깅 함수
log_info() { echo "[INFO] $1"; }
log_success() { echo "$(green "[SUCCESS]") $1"; }
log_error() { echo "$(red "[ERROR]") $1"; }
log_warning() { echo "$(yellow "[WARNING]") $1"; }

# Hardcoded Object Storage credentials
ACCESS_KEY="a6a460c368d84f398c978218e0673af6"
SECRET_KEY="7e9f707c-bccc-451f-b758-6ec16d21f056"
BUCKET_STRING="89097ddf09b84d96af496aded95dac29"

# Object Storage 엔드포인트 설정 (README.md 참조)
ENDPOINT_URL="https://object-store.private.kr-west1.e.samsungsdscloud.com"
BUCKET_NAME="ceweb"
REGION="kr-west1"

log_success "Object Storage configuration loaded (hardcoded):"
echo "  Access Key: ${ACCESS_KEY:0:8}..."
echo "  Bucket String: $BUCKET_STRING"
echo "  Endpoint: $ENDPOINT_URL"
echo "  Bucket Name: $BUCKET_NAME"

# AWS CLI 설치 확인 및 설치 (README.md 참조)
log_info "Checking AWS CLI installation..."

if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version 2>&1 | cut -d' ' -f1 | cut -d'/' -f2)
    log_info "AWS CLI is already installed (version: $AWS_VERSION)"

    # 버전 2.x인지 확인
    if [[ "$AWS_VERSION" < "2.0" ]]; then
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

if [ "$INSTALL_AWSCLI" = true ]; then
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
aws_access_key_id = $ACCESS_KEY
aws_secret_access_key = $SECRET_KEY
EOF

cat > ~/.aws/config << EOF
[default]
region = $REGION
EOF

chmod 600 ~/.aws/credentials ~/.aws/config

log_success "AWS CLI configured successfully"

# 연결 테스트
log_info "Testing Object Storage connection..."
if aws s3 ls s3://$BUCKET_NAME --endpoint-url $ENDPOINT_URL >/dev/null 2>&1; then
    log_success "Object Storage connection successful"
else
    log_warning "Object Storage connection test failed, but proceeding..."
    log_info "This may be normal if the bucket doesn't exist yet"
fi

# 미디어 디렉토리 확인
MEDIA_DIR="./ceweb/media"
if [ ! -d "$MEDIA_DIR" ]; then
    log_error "Media directory not found: $MEDIA_DIR"
    log_error "Please ensure the web application is properly deployed"
    exit 1
fi

# 미디어 파일 현황 확인
log_info "Checking media directory contents..."
TOTAL_FILES=$(find "$MEDIA_DIR" -type f | wc -l)
TOTAL_SIZE=$(du -sh "$MEDIA_DIR" 2>/dev/null | cut -f1)

if [ "$TOTAL_FILES" -eq 0 ]; then
    log_warning "No files found in $MEDIA_DIR"
    echo "Nothing to upload."
    exit 0
fi

log_info "Found $TOTAL_FILES files ($TOTAL_SIZE) in $MEDIA_DIR"

# 사용자 확인 (기본값 Y)
echo ""
yellow "========================================="
yellow "UPLOAD CONFIRMATION"
yellow "========================================="
echo ""
echo "The following will be uploaded to Object Storage:"
echo "  Source: $MEDIA_DIR"
echo "  Destination: s3://$BUCKET_NAME/media"
echo "  Endpoint: $ENDPOINT_URL"
echo "  Files: $TOTAL_FILES files ($TOTAL_SIZE)"
echo ""

# 기본값이 Y인 확인
read -p "$(yellow "Do you want to proceed with the upload? [Y/n]: ")" -n 1 -r
echo

# 기본값 처리 (엔터만 누른 경우 Y로 처리)
if [[ -z "$REPLY" ]]; then
    REPLY="Y"
fi

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Upload cancelled by user"
    exit 0
fi

# Object Storage로 업로드 (README.md의 명령 참조)
log_info "Starting upload to Object Storage..."
echo ""

# README.md 명령: aws s3 cp media s3://{버킷명}/media --recursive --endpoint-url [Private Endpoint명]
cd /home/rocky/ceweb

log_info "Executing: aws s3 cp media s3://$BUCKET_NAME/media --recursive --endpoint-url $ENDPOINT_URL"

aws s3 cp media "s3://$BUCKET_NAME/media" --recursive --endpoint-url "$ENDPOINT_URL"

UPLOAD_RESULT=$?

if [ $UPLOAD_RESULT -eq 0 ]; then
    log_success "Upload completed successfully!"
    echo ""

    # 업로드 확인
    log_info "Verifying upload..."
    UPLOADED_FILES=$(aws s3 ls "s3://$BUCKET_NAME/media" --recursive --endpoint-url "$ENDPOINT_URL" | wc -l)
    log_success "Verified: $UPLOADED_FILES files uploaded"

    # Public URL 정보 제공 (README.md 참조)
    echo ""
    cyan "========================================="
    cyan "OBJECT STORAGE INFORMATION"
    cyan "========================================="
    echo ""
    echo "$(green "Files successfully uploaded to Object Storage")"
    echo ""
    echo "Public URL structure:"
    echo "  https://object-store.kr-west1.e.samsungsdscloud.com/$BUCKET_STRING:$BUCKET_NAME/media/[filename]"
    echo ""
    echo "Private URL structure:"
    echo "  $ENDPOINT_URL/$BUCKET_STRING:$BUCKET_NAME/media/[filename]"
    echo ""
    echo "Web application configuration:"
    echo "  Update your web application to use the Object Storage URLs"
    echo "  for serving static media files."
    echo ""

    # README.md에 언급된 애플리케이션 전환 방법 안내
    echo "$(cyan "Next steps (from README.md):")"
    echo "  1. Update web server paths from './media' to Object Storage URLs"
    echo "  2. Consider switching application files:"
    echo "     mv index.html index_bk.html"
    echo "     mv index_obj.html index.html"
    echo ""

    # Public Access 설정
    log_info "Setting Public Access for all uploaded files..."
    echo ""

    # 모든 업로드된 파일 목록 가져오기
    FILES_LIST=$(aws s3 ls "s3://$BUCKET_NAME/media/" --recursive --endpoint-url "$ENDPOINT_URL" | awk '{print $4}')

    if [ -n "$FILES_LIST" ]; then
        FILE_COUNT=0
        TOTAL_COUNT=$(echo "$FILES_LIST" | wc -l)

        echo "Setting public-read ACL for $TOTAL_COUNT files..."

        # 각 파일에 대해 public-read ACL 설정
        while IFS= read -r FILE_KEY; do
            if [ -n "$FILE_KEY" ]; then
                # ACL을 public-read로 설정
                aws s3api put-object-acl \
                    --bucket "$BUCKET_NAME" \
                    --key "$FILE_KEY" \
                    --acl public-read \
                    --endpoint-url "$ENDPOINT_URL" 2>/dev/null

                if [ $? -eq 0 ]; then
                    ((FILE_COUNT++))
                    echo -ne "\rProgress: $FILE_COUNT/$TOTAL_COUNT files"
                fi
            fi
        done <<< "$FILES_LIST"

        echo ""
        log_success "Public Access enabled for $FILE_COUNT files"

        # Public URL 예시 표시
        echo ""
        cyan "========================================="
        cyan "PUBLIC ACCESS URLS"
        cyan "========================================="
        echo ""
        echo "$(green "All files are now publicly accessible!")"
        echo ""
        echo "Example public URLs:"

        # 첫 3개 파일의 Public URL 예시 표시
        echo "$FILES_LIST" | head -3 | while read FILE_KEY; do
            if [ -n "$FILE_KEY" ]; then
                echo "  • https://object-store.kr-west1.e.samsungsdscloud.com/$BUCKET_STRING:$BUCKET_NAME/$FILE_KEY"
            fi
        done

        if [ $TOTAL_COUNT -gt 3 ]; then
            echo "  ... and $((TOTAL_COUNT - 3)) more files"
        fi
    else
        log_warning "No files found to set Public Access"
    fi

    echo ""
else
    log_error "Upload failed with exit code $UPLOAD_RESULT"
    log_error "Please check your Object Storage configuration and network connectivity"
    exit 1
fi

echo ""
log_success "Object Storage upload script completed successfully!"
echo "========================================="
```

```bash
sudo chmod +x upload_to_object_storage.sh
./upload_to_object_storage.sh
```

```bash
cd /home/rocky/ceweb/artist/
vi cloudy.html
```
