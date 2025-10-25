########################################################
# Provider : Samsung Cloud Platform V2
########################################################

terraform {
  required_providers {
    samsungcloudplatformv2 = {
      version = "2.0.3"
      source  = "SamsungSDSCloud/samsungcloudplatformv2"
    }
  }
  required_version = ">= 1.11"
}

provider "samsungcloudplatformv2" {
}

########################################################
# VPC 자원 생성
########################################################
resource "samsungcloudplatformv2_vpc_vpc" "vpc" {
  name        = "VPC1"
  cidr        = var.vpc_cidr
  description = "Simple Web VPC"
  tags        = var.common_tags
}

########################################################
# Internet Gateway 생성, VPC 연결
########################################################
resource "samsungcloudplatformv2_vpc_internet_gateway" "igw" {
  type              = "IGW"
  vpc_id            = samsungcloudplatformv2_vpc_vpc.vpc.id
  firewall_enabled  = true
  firewall_loggable = false
  tags              = var.common_tags

  depends_on = [samsungcloudplatformv2_vpc_vpc.vpc]
}

########################################################
# Subnet 자원 생성
########################################################
resource "samsungcloudplatformv2_vpc_subnet" "web_subnet" {
  name        = "WebSubnet"
  cidr        = var.web_subnet_cidr
  type        = "GENERAL"
  description = "Web Server Subnet"
  vpc_id      = samsungcloudplatformv2_vpc_vpc.vpc.id
  tags        = var.common_tags

  depends_on  = [samsungcloudplatformv2_vpc_internet_gateway.igw]
}

########################################################
# 기존 Key Pair 조회
########################################################
data "samsungcloudplatformv2_virtualserver_keypair" "kp" {
  name = var.keypair_name
}

########################################################
# Public IP
########################################################
resource "samsungcloudplatformv2_vpc_publicip" "web_public_ip" {
  type        = "IGW"
  description = "Public IP for Web Server"

  depends_on = [samsungcloudplatformv2_vpc_subnet.web_subnet] 
}

resource "samsungcloudplatformv2_vpc_publicip" "nat_public_ip" {
  type        = "IGW"
  description = "Public IP for NAT Gateway"

  depends_on = [samsungcloudplatformv2_vpc_subnet.web_subnet] 
}

########################################################
# Security Group
########################################################
resource "samsungcloudplatformv2_security_group_security_group" "web_sg" {
  name        = var.security_group_web
  loggable    = false
  tags        = var.common_tags
}

########################################################
# IGW Firewall 기본 통신 규칙
########################################################
data "samsungcloudplatformv2_firewall_firewalls" "fw_igw" {
  product_type = ["IGW"]
  size         = 1
  
  depends_on  = [samsungcloudplatformv2_vpc_internet_gateway.igw]
}

locals {
  igw_firewall_id = try(data.samsungcloudplatformv2_firewall_firewalls.fw_igw.ids, "")
}

resource "samsungcloudplatformv2_firewall_firewall_rule" "web_http_in_fw" {
  firewall_id = local.igw_firewall_id[0]
  firewall_rule_create = {
    action              = "ALLOW"
    direction           = "INBOUND"
    status              = "ENABLE"
    source_address      = ["0.0.0.0/0"]
    destination_address = [var.web_ip]
    description         = "HTTP inbound to web server"
    service = [
      { service_type = "TCP", service_value = "80" }
    ]
  }
  depends_on  = [samsungcloudplatformv2_firewall_firewall_rule.web_ssh_in_fw]
}

resource "samsungcloudplatformv2_firewall_firewall_rule" "web_ssh_in_fw" {
  firewall_id = local.igw_firewall_id[0]
  firewall_rule_create = {
    action              = "ALLOW"
    direction           = "INBOUND"
    status              = "ENABLE"
    source_address      = [var.user_public_ip]
    destination_address = [var.web_ip]
    description         = "SSH inbound to web server"
    service = [
      { service_type = "TCP", service_value = "22" }
    ]
  }
  depends_on  = [samsungcloudplatformv2_firewall_firewall_rule.web_out_fw]
}

resource "samsungcloudplatformv2_firewall_firewall_rule" "web_out_fw" {
  firewall_id = local.igw_firewall_id[0]
  firewall_rule_create = {
    action              = "ALLOW"
    direction           = "OUTBOUND"
    status              = "ENABLE"
    source_address      = [var.web_ip]
    destination_address = ["0.0.0.0/0"]
    description         = "HTTP/HTTPS outbound to Internet"
    service = [
      { service_type = "TCP", service_value = "80" },
      { service_type = "TCP", service_value = "443" }
    ]
  }
  depends_on  = [samsungcloudplatformv2_vpc_internet_gateway.igw]
}

########################################################
# Security Group 기본 통신 규칙
########################################################

# WebSG 규칙들
resource "samsungcloudplatformv2_security_group_security_group_rule" "web_ssh_in_sg" {
  direction         = "ingress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.web_sg.id
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  description       = "SSH inbound"
  remote_ip_prefix  = var.user_public_ip

  depends_on = [samsungcloudplatformv2_security_group_security_group.web_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "web_http_in_sg" {
  direction         = "ingress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.web_sg.id
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  description       = "HTTP inbound"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.web_ssh_in_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "web_http_out_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.web_sg.id
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  description       = "HTTP outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.web_http_in_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "web_https_out_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.web_sg.id
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  description       = "HTTPS outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on  = [samsungcloudplatformv2_security_group_security_group_rule.web_http_out_sg]
}

########################################################
# Subnet에 NAT Gateway 연결
########################################################
resource "samsungcloudplatformv2_vpc_nat_gateway" "web_natgateway" {
    subnet_id = samsungcloudplatformv2_vpc_subnet.web_subnet.id
    publicip_id = samsungcloudplatformv2_vpc_publicip.nat_public_ip.id
    description = "NAT for web"
    tags        = var.common_tags

    depends_on = [
    samsungcloudplatformv2_security_group_security_group.web_sg,
    samsungcloudplatformv2_vpc_subnet.web_subnet,
    samsungcloudplatformv2_vpc_publicip.nat_public_ip
  ]
}

###################################################
# Virtual Server Standard Image ID 조회
########################################################
# Windows 이미지 조회
data "samsungcloudplatformv2_virtualserver_images" "windows" {
  os_distro = var.image_windows_os_distro
  status    = "active"

  filter {
    name      = "os_distro"
    values    = [var.image_windows_os_distro]
    use_regex = false
  }
  filter {
    name      = "scp_os_version"
    values    = [var.image_windows_scp_os_version]
    use_regex = false
  }
}

# Rocky 이미지 조회
data "samsungcloudplatformv2_virtualserver_images" "rocky" {
  os_distro = var.image_rocky_os_distro
  status    = "active"

  filter {
    name      = "os_distro"
    values    = [var.image_rocky_os_distro]
    use_regex = false
  }
  filter {
    name      = "scp_os_version"
    values    = [var.image_rocky_scp_os_version]
    use_regex = false
  }
}

# 이미지 Local 변수 지정
locals {
  windows_ids = try(data.samsungcloudplatformv2_virtualserver_images.windows.ids, [])
  rocky_ids   = try(data.samsungcloudplatformv2_virtualserver_images.rocky.ids, [])

  windows_image_id_first = length(local.windows_ids) > 0 ? local.windows_ids[0] : ""
  rocky_image_id_first   = length(local.rocky_ids)   > 0 ? local.rocky_ids[0]   : ""
}

########################################################
# Virtual Server 자원 생성
########################################################

# Web VM
resource "samsungcloudplatformv2_virtualserver_server" "vm_web" {
  name           = var.vm_web.name
  keypair_name   = data.samsungcloudplatformv2_virtualserver_keypair.kp.name
  server_type_id = var.server_type_id
  state ="ACTIVE"
  tags           = var.common_tags
  boot_volume = {
    size                  = var.boot_volume_rocky.size
    type                  = var.boot_volume_rocky.type
    delete_on_termination = var.boot_volume_rocky.delete_on_termination
  }
  image_id = local.rocky_image_id_first
  networks = {
    nic0 = {
      public_ip_id = samsungcloudplatformv2_vpc_publicip.web_public_ip.id,
      subnet_id = samsungcloudplatformv2_vpc_subnet.web_subnet.id,
      fixed_ip = var.web_ip
    }
  }
  security_groups = [samsungcloudplatformv2_security_group_security_group.web_sg.id] 
  user_data = base64encode(file("${path.module}/../scripts/generated_userdata/userdata_web.sh"))
  depends_on = [
    samsungcloudplatformv2_vpc_subnet.web_subnet,
    samsungcloudplatformv2_security_group_security_group.web_sg,
    samsungcloudplatformv2_vpc_nat_gateway.web_natgateway,
    samsungcloudplatformv2_security_group_security_group_rule.web_https_out_sg
  ]
}
