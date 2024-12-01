provider "aws" {
  region = "ap-southeast-1"
}

# VPC and Networking
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "Main VPC"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_subnet" "public_1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-southeast-1a"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "Public Subnet 1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-southeast-1b"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "Public Subnet 2"
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "docker_sg" {
  name        = "docker-server-sg"
  description = "Allow HTTP, HTTPS, and SSH traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer" {
  key_name   = "docker-key"
  public_key = tls_private_key.ec2_key.public_key_openssh
}

resource "local_file" "private_key" {
  content  = tls_private_key.ec2_key.private_key_pem
  filename = "${path.module}/docker-key.pem"
  file_permission = "0400"
}

# EC2 Instances
resource "aws_instance" "docker_server_1" {
  ami           = "ami-047126e50991d067b"  # Ubuntu 22.04 LTS AMI 
  instance_type = "t2.medium"  # Increased to support Docker
  subnet_id     = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.docker_sg.id]
  key_name      = aws_key_pair.deployer.key_name  # Replace with your EC2 key pair
  
  user_data = <<-EOF
              #!/bin/bash
              # Update system
              apt-get update -y
              apt-get upgrade -y

              # Install required packages
              apt-get install -y apt-transport-https ca-certificates curl software-properties-common

              # Install Docker
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
              add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
              apt-get update -y
              apt-get install -y docker-ce docker-ce-cli containerd.io

              # Install Docker Compose
              DOCKER_COMPOSE_VERSION="v2.24.5"
              curl -L "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
              chmod +x /usr/local/bin/docker-compose

              # Add ubuntu user to docker group
              usermod -aG docker ubuntu

              # Start Docker service
              systemctl start docker
              systemctl enable docker

              
              EOF

  tags = {
    Name = "Docker Server 1"
  }
}

resource "aws_instance" "docker_server_2" {
  ami           = "ami-047126e50991d067b"  # Ubuntu 22.04 LTS AMI 
  instance_type = "t2.medium"  # Increased to support Docker
  subnet_id     = aws_subnet.public_2.id
  vpc_security_group_ids = [aws_security_group.docker_sg.id]
  key_name      = aws_key_pair.deployer.key_name  # Replace with your EC2 key pair
  
  user_data = <<-EOF
              #!/bin/bash
              # Update system
              apt-get update -y
              apt-get upgrade -y

              # Install required packages
              apt-get install -y apt-transport-https ca-certificates curl software-properties-common

              # Install Docker
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
              add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
              apt-get update -y
              apt-get install -y docker-ce docker-ce-cli containerd.io

              # Install Docker Compose
              DOCKER_COMPOSE_VERSION="v2.24.5"
              curl -L "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
              chmod +x /usr/local/bin/docker-compose

              # Add ubuntu user to docker group
              usermod -aG docker ubuntu

              # Start Docker service
              systemctl start docker
              systemctl enable docker

              
              EOF

  tags = {
    Name = "Docker Server 2"
  }
}

# Application Load Balancer
resource "aws_lb" "docker_alb" {
  name               = "docker-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.docker_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

resource "aws_lb_target_group" "docker_tg" {
  name     = "docker-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 10
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.docker_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.docker_tg.arn
  }
}

resource "aws_lb_target_group_attachment" "server_1" {
  target_group_arn = aws_lb_target_group.docker_tg.arn
  target_id        = aws_instance.docker_server_1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "server_2" {
  target_group_arn = aws_lb_target_group.docker_tg.arn
  target_id        = aws_instance.docker_server_2.id
  port             = 80
}

# Outputs
output "load_balancer_dns" {
  value = aws_lb.docker_alb.dns_name
}

output "server_1_public_ip" {
  value = aws_instance.docker_server_1.public_ip
}

output "server_2_public_ip" {
  value = aws_instance.docker_server_2.public_ip
}