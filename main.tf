provider "aws" {
  region = "ap-south-1"
}

resource "tls_private_key" "dsa_windows_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_secretsmanager_secret" "key_secret" {
  name = "DSA-windows"
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [name]
  }
}

resource "aws_secretsmanager_secret_version" "key_secret_version" {
  secret_id     = aws_secretsmanager_secret.key_secret.id
  secret_string = tls_private_key.dsa_windows_key.private_key_pem
  depends_on    = [aws_secretsmanager_secret.key_secret]
}

resource "aws_key_pair" "dsa_windows_key_pair" {
  key_name   = "DSA-windows-key"
  public_key = tls_private_key.dsa_windows_key.public_key_openssh

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [key_name]
  }
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-west-1a"
  map_public_ip_on_launch = true
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "ec2_sg" {
  name        = "ec2-dSawindows-sg"
  description = "Allow RDP and SSM"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 3389
    to_port     = 3389
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

resource "aws_iam_role" "ssm_role" {
  name = "ec2_ssm_role-DSA"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "ssm-instance-profile1"
  role = aws_iam_role.ssm_role.name
}

data "aws_ami" "dsa_windows" {
  most_recent = true
  owners      = ["801119661308"]

  filter {
    name   = "name"
    values = ["Windows_Server-2019-English-Full-Base-*"]
  }
}

resource "aws_instance" "windows_ec2" {
  ami                    = data.aws_ami.dsa_windows.id
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.public.id
  key_name               = aws_key_pair.dsa_windows_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name

  tags = {
    Name = "Windows-EC2-Fleet"
  }
}
