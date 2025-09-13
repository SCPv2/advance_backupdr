# Storage 백업 구성

## 선행 실습

### 선택 '[과정 소개](https://github.com/SCPv2/ce_advance_introduction/blob/main/README.md)'

- Key Pair, 인증키, DNS 등 사전 준비

### 선택 '[Terraform을 이용한 클라우드 자원 배포](https://github.com/SCPv2/advance_iac/blob/main/terraform/README.md)'

- Samsung Cloud Platform v2 기반 Terraform 학습

## 실습 환경 배포

- Terraform 배포

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

## File Storage 생성

- 볼륨명 : `cefs`
- 디스크 유형 : HDD
- 프로토콜 : NFS

## File Storage Mount

```bash
# 스토리지 마이그레이션 준비
mkdir nfs                                      # File Storage를 마운트할 새 폴더(rocky로 실행)
sudo dnf install nfs-utils -y                    # nfs-uil 설치 
sudo systemctl enable rpcbind.service
sudo systemctl start rpcbind.service
sudo vi /etc/fstab                               # vi에디터에서 i를 누르고, 아래 설정 입력

10.10.10.10:/filestorage /home/rocky/ceweb/files nfs defaults,vers=3,_netdev,noresvport 0 0    
# 10.10.10.10:/file_storage는 위에서 기록한 마운트명으로 대체
# vi 에디터에서 빠져 나올 때는 esc를 누르고, :wq! 타이핑 후 엔터

# 마운트 실행
sudo systemctl daemon-reload
sudo mount -t nfs -o vers=3,noresvport 198.19.64.7:/scp_cefs_filestorage nfs

# 마운트 상태 확인
df -h                                            # 마운트 상태 확인 : 마운트명 과 /home/rocky/ceweb/files가 매핑되어 있어야 함.
