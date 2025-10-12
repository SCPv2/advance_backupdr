# Disaster Recovery 구성

## 선행 실습

### 선택 '[과정 소개](https://github.com/SCPv2/ce_advance_introduction/blob/main/README.md)'

- Key Pair, 인증키, DNS 등 사전 준비

### 선택 '[Terraform을 이용한 클라우드 자원 배포](https://github.com/SCPv2/advance_iac/blob/main/terraform/README.md)'

- Samsung Cloud Platform v2 기반 Terraform 학습

## 실습 환경 배포

**&#128906; 사용자 환경 구성 (\advance_backupdr\dr\env_setup.ps1)**

**&#128906; kr-west1에 실습 환경 배포**

- %USERPROFILE%/.scpconf/config.json에서 default-region 설정 확인 : kr-west1

```json
{
    "auth-url": "https://iam.e.samsungsdscloud.com/v1",
    "default-region": "kr-west1"
}
```

- Terraform 배포 (\advance_backupdr\dr\kr-west1)

```bash
terraform init
terraform validate
terraform plan

terraform apply --auto-approve
```

**&#128906; kr-east1에 실습 환경 배포**

- kr-east1 에서 Keypair 생성

  - keypair 명: `mykey`
  - download 받은 keypair ppk 변환 : mykey_e.ppk

- %USERPROFILE%/.scpconf/config.json에서 default-region 설정 수정: kr-east-1

```json
{
    "auth-url": "https://iam.e.samsungsdscloud.com/v1",
    "default-region": "kr-east1" 
}
```

- Terraform 배포 (\advance_backupdr\dr\kr-east1)

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

## File Storage 생성 및 서버 연결 (kr-west1)

- 볼륨명 : `cefs`
- 디스크 유형 : HDD
- 프로토콜 : NFS

- 연결자원 : webvm111r

## File Storage Mount Script 실행 (kr-west-1)

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

    # 마운트된 디렉토리 소유권을 rocky로 변경
    echo ""
    echo "Changing ownership to rocky user..."
    sudo chown rocky:rocky "$MOUNT_PATH"
    echo "  Ownership changed to rocky:rocky"

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

## GSLB 생성

- 도메인명 : ceweb

- 연결 대상 추가 > IP :
  - kr-west1 Virtual Server의 Public IP, 위치(kr-west1) 입력
  - kr-east1 Virtual Server의 Public IP, 위치(kr-east1) 입력

- Health Check : TCP
- Interval : 5
- Timeout : 6
- Probe Timeout : 5
- Service Port : 80
- 알고리즘 : Round Robin

## 통신 제어 규칙 추가

- GSLB IP 대역(콘솔 참조)을 kr-west1 리전과 kr-east1 리전의 Internet Gateway Firewall, Security Group에 허용 규칙 추가

## File Storage 복제 구성
- 복제 위치 : kr-east1
- 복제 볼륨명 : cefs
- 비밀번호: ceadmin1234
- 복제 주기: 5분

- 연결자원 : webvm111r

## File Storage Mount Script 실행 (kr-east-1) 

- 스크립트 위와 동일
