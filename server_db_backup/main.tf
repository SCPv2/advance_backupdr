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
# VPC 
########################################################
resource "samsungcloudplatformv2_vpc_vpc" "vpc" {
  name        = "VPC1"
  cidr        = var.vpc_cidr
  description = "Simple Web VPC"
  tags        = var.common_tags
}

########################################################
# Internet Gateway 
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
# Subnet 
########################################################
resource "samsungcloudplatformv2_vpc_subnet" "subnet11" {
  name        = "Subnet11"
  cidr        = var.web_subnet_cidr
  type        = "GENERAL"
  description = "Bastion Subnet"
  vpc_id      = samsungcloudplatformv2_vpc_vpc.vpc.id
  tags        = var.common_tags

  depends_on  = [samsungcloudplatformv2_vpc_internet_gateway.igw]
}

resource "samsungcloudplatformv2_vpc_subnet" "subnet12" {
  name        = "Subnet12"
  cidr        = var.app_subnet_cidr
  type        = "GENERAL"
  description = "App Subnet"
  vpc_id      = samsungcloudplatformv2_vpc_vpc.vpc.id
  tags        = var.common_tags

  depends_on  = [samsungcloudplatformv2_vpc_internet_gateway.igw]
}

resource "samsungcloudplatformv2_vpc_subnet" "subnet13" {
  name        = "Subnet13"
  cidr        = var.db_subnet_cidr
  type        = "GENERAL"
  description = "DB Subnet"
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
resource "samsungcloudplatformv2_vpc_publicip" "pip1" {
  type        = "IGW"
  description = "Public IP for Bastion VM"
  tags        = var.common_tags

  depends_on = [samsungcloudplatformv2_vpc_subnet.subnet11, samsungcloudplatformv2_vpc_subnet.subnet12, samsungcloudplatformv2_vpc_subnet.subnet13]
}

resource "samsungcloudplatformv2_vpc_publicip" "pip2" {
  type        = "IGW"
  description = "Public IP for App NAT Gateway"
  tags        = var.common_tags

  depends_on = [samsungcloudplatformv2_vpc_subnet.subnet11, samsungcloudplatformv2_vpc_subnet.subnet12, samsungcloudplatformv2_vpc_subnet.subnet13]
}

########################################################
# Security Group
########################################################
resource "samsungcloudplatformv2_security_group_security_group" "bastion_sg" {
  name     = var.security_group_bastion
  loggable = false
  tags     = var.common_tags
}

resource "samsungcloudplatformv2_security_group_security_group" "app_sg" {
  name     = var.security_group_app
  loggable = false
  tags     = var.common_tags
}

########################################################
# IGW Firewall
########################################################
data "samsungcloudplatformv2_firewall_firewalls" "fw_igw" {
  product_type = ["IGW"]
  size         = 1

  depends_on  = [samsungcloudplatformv2_vpc_internet_gateway.igw]
}

locals {
  igw_firewall_id = try(data.samsungcloudplatformv2_firewall_firewalls.fw_igw.ids, "")
}

resource "samsungcloudplatformv2_firewall_firewall_rule" "bastion_rdp_in_fw" {
  firewall_id = local.igw_firewall_id[0]
  firewall_rule_create = {
    action              = "ALLOW"
    direction           = "INBOUND"
    status              = "ENABLE"
    source_address      = [var.user_public_ip]
    destination_address = [var.bastion_ip]
    description         = "RDP inbound to bastion"
    service = [
      { service_type = "TCP", service_value = "3389" }
    ]
  }
  depends_on  = [samsungcloudplatformv2_firewall_firewall_rule.app_out_fw]
}

resource "samsungcloudplatformv2_firewall_firewall_rule" "app_out_fw" {
  firewall_id = local.igw_firewall_id[0]
  firewall_rule_create = {
    action              = "ALLOW"
    direction           = "OUTBOUND"
    status              = "ENABLE"
    source_address      = [var.bastion_ip, var.app_subnet_cidr]
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

resource "samsungcloudplatformv2_security_group_security_group_rule" "bastion_rdp_in_sg" {
  direction         = "ingress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.bastion_sg.id
  protocol          = "tcp"
  port_range_min    = 3389
  port_range_max    = 3389
  description       = "RDP inbound to bastion VM"
  remote_ip_prefix  = var.user_public_ip

  depends_on = [samsungcloudplatformv2_security_group_security_group.bastion_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "bastion_http_out_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.bastion_sg.id
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  description       = "HTTP outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.bastion_rdp_in_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "bastion_https_out_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.bastion_sg.id
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  description       = "HTTPS outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.bastion_http_out_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "bastion_ssh_to_app_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.bastion_sg.id
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  description       = "SSH outbound to app vm"
  remote_group_id   = samsungcloudplatformv2_security_group_security_group.app_sg.id

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.bastion_https_out_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "app_ssh_from_bastion_sg" {
  direction         = "ingress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.app_sg.id
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  description       = "SSH inbound from bastion"
  remote_group_id   = samsungcloudplatformv2_security_group_security_group.bastion_sg.id

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.bastion_ssh_to_app_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "app_http_out_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.app_sg.id
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  description       = "HTTP outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.app_ssh_from_bastion_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "app_https_out_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.app_sg.id
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  description       = "HTTPS outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.app_http_out_sg]
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "app_db_to_dbaas_sg" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.app_sg.id
  protocol          = "tcp"
  port_range_min    = 2866
  port_range_max    = 2866
  description       = "PostgreSQL connection outbound to DBaaS"
  remote_ip_prefix  = "${var.db_ip}/32"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.app_https_out_sg]
}

########################################################
# Subnet에 NAT Gateway 연결
########################################################
resource "samsungcloudplatformv2_vpc_nat_gateway" "app_natgateway" {
  subnet_id   = samsungcloudplatformv2_vpc_subnet.subnet12.id
  publicip_id = samsungcloudplatformv2_vpc_publicip.pip2.id
  description = "NAT for app"
  tags        = var.common_tags

  depends_on = [
    samsungcloudplatformv2_security_group_security_group.bastion_sg,
    samsungcloudplatformv2_security_group_security_group.app_sg,
    samsungcloudplatformv2_vpc_subnet.subnet11,
    samsungcloudplatformv2_vpc_subnet.subnet12,
    samsungcloudplatformv2_vpc_subnet.subnet13,
    samsungcloudplatformv2_vpc_publicip.pip1,
    samsungcloudplatformv2_vpc_publicip.pip2
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
# PostgreSQL DBaaS 
########################################################
resource "samsungcloudplatformv2_postgresql_cluster" "dbaas_cluster" {
  allowable_ip_addresses  = [var.app_subnet_cidr, "${var.bastion_ip}/32"]
  dbaas_engine_version_id = var.postgresql_engine_id
  nat_enabled             = false
  ha_enabled              = false
  instance_name_prefix    = "cedbserver"
  name                    = "cedbcluster"
  subnet_id               = samsungcloudplatformv2_vpc_subnet.subnet13.id
  tags                    = var.common_tags
  service_state           = "RUNNING"
  timezone                = var.timezone

  init_config_option = {
    audit_enabled          = false
    database_encoding      = "UTF-8"
    database_locale        = "C"
    database_name          = var.database_name
    database_port          = var.database_port
    database_user_name     = var.database_user
    database_user_password = var.database_password
    backup_option = {
      retention_period_day     = "7"
      starting_time_hour       = "12"
      archive_frequency_minute = "60"
    }
  }

  instance_groups = [
    {
      role_type        = "ACTIVE"
      server_type_name = "db1v2m4"
      block_storage_groups = [
        {
          role_type   = "OS"
          volume_type = "SSD"
          size_gb     = 104
        },
        {
          role_type   = "DATA"
          volume_type = "SSD"
          size_gb     = 16
        }
      ]
      instances = [
        {
          role_type          = "ACTIVE"
          service_ip_address = var.db_ip
        }
      ]
    }
  ]

  maintenance_option = {
    period_hour            = "1"
    starting_day_of_week   = "SUN"
    starting_time          = "0200"
    use_maintenance_option = true
  }

  depends_on = [
    samsungcloudplatformv2_vpc_subnet.subnet13
  ]
}

########################################################
# Virtual Server
########################################################

# App VM (vm121r)
resource "samsungcloudplatformv2_virtualserver_server" "vm_app" {
  name           = var.vm_app.name
  keypair_name   = data.samsungcloudplatformv2_virtualserver_keypair.kp.name
  server_type_id = var.server_type_id
  state          = "ACTIVE"
  tags           = var.common_tags

  boot_volume = {
    size                  = var.boot_volume_rocky.size
    type                  = var.boot_volume_rocky.type
    delete_on_termination = var.boot_volume_rocky.delete_on_termination
  }
  image_id = local.rocky_image_id_first
  networks = {
    nic0 = {
      subnet_id = samsungcloudplatformv2_vpc_subnet.subnet12.id
      fixed_ip  = var.app_ip
    }
  }
  security_groups = [samsungcloudplatformv2_security_group_security_group.app_sg.id]
  depends_on = [
    samsungcloudplatformv2_postgresql_cluster.dbaas_cluster,
    samsungcloudplatformv2_vpc_subnet.subnet12,
    samsungcloudplatformv2_security_group_security_group.app_sg,
    samsungcloudplatformv2_vpc_nat_gateway.app_natgateway
  ]
}

# Bastion VM (vm110w)
resource "samsungcloudplatformv2_virtualserver_server" "vm_bastion" {
  name           = var.vm_bastion.name
  keypair_name   = data.samsungcloudplatformv2_virtualserver_keypair.kp.name
  server_type_id = var.server_type_id
  state          = "ACTIVE"
  tags           = var.common_tags

  boot_volume = {
    size                  = var.boot_volume_windows.size
    type                  = var.boot_volume_windows.type
    delete_on_termination = var.boot_volume_windows.delete_on_termination
  }
  image_id = local.windows_image_id_first
  networks = {
    nic0 = {
      subnet_id    = samsungcloudplatformv2_vpc_subnet.subnet11.id
      fixed_ip     = var.bastion_ip
      public_ip_id = samsungcloudplatformv2_vpc_publicip.pip1.id
    }
  }
  security_groups = [samsungcloudplatformv2_security_group_security_group.bastion_sg.id]
  depends_on = [
    samsungcloudplatformv2_vpc_subnet.subnet11,
    samsungcloudplatformv2_security_group_security_group.bastion_sg,
    samsungcloudplatformv2_vpc_publicip.pip1
  ]
}
