# Disaster Recovery 구성

## 선행 실습

### 선택 '[과정 소개](https://github.com/SCPv2/ce_advance_introduction/blob/main/README.md)'

- Key Pair, 인증키, DNS 등 사전 준비

### 선택 '[Terraform을 이용한 클라우드 자원 배포](https://github.com/SCPv2/advance_iac/blob/main/terraform/README.md)'

- Samsung Cloud Platform v2 기반 Terraform 학습

## 실습 환경 배포

**&#128906; kr-west1에 실습 환경 배포**

- %USERPROFILE%/.scpconf/config.json에서 default-region 설정 확인 : kr-west1

```config
{
    "auth-url": "https://iam.e.samsungsdscloud.com/v1",
    "default-region": "kr-west1"
}
```
**&#128906; 사용자 환경 구성**  

```powershell
advance_backupdr\dr\env_setup.ps1

# 1. Normalize 를 실행하여 환경 변수 설정
```

- Terraform 배포

```bash
terraform init
terraform validate
terraform plan

terraform apply --auto-approve
```

**&#128906; kr-east1에 실습 환경 배포**

- kr-east1 에서 Keypair 생성
  - keypair 명: `mykey`
  - download 후 ppk 변환 : mykey_e.ppk

**&#128906; 기존 Terraform 환경 삭제 및 새로운 사용자 환경 구성**  
```powershell
advance_backupdr\dr\env_setup.ps1
# 2. RESET     - Reset to initial values and clean the logs 를 실행하여 기존 환경 모두 제거
```

- %USERPROFILE%/.scpconf/config.json에서 설정 수정

```json
{
    "auth-url": "https://iam.e.samsungsdscloud.com/v1",
    "default-region": "kr-east1"       # kr-east1 리전으로 수정
}
```json

- variables.tf 수정 : kr-east1이 활성화되도록 kr-west1 항목에 마스크(#) 처리

```hcl
variable "rocky_image_id" {
  type        = string
  description = "[TERRAFORM_INFRA] Rocky Linux image ID"
#  default     = "253a91ea-1221-49d7-af53-a45c389e7e1a" # kr-west1
  default     = "99b329ad-14e1-4741-b3ef-2a330ef81074" # kr-east1
}

# Virtual Server 변수 정의
variable "server_type_id" {
  type        = string
  description = "[TERRAFORM_INFRA] Server type ID (instance type)"
#  default     = "s2v1m2" # for kr-west1
  default     = "s2v1m2" # for kr-east1
}

```

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
