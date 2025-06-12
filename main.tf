provider "aws" {
  region = "ap-south-1"
}

# S3 backend configuration
terraform {
  backend "s3" {
    bucket = "sfstatefile"
    key    = "terraform/windows2016-server/terraform.tfstate"
    region = "ap-south-1"
  }
}

resource "tls_private_key" "windows_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_secretsmanager_secret" "windows_key_secret" {
  name        = "windows2016-key-secret"
  description = "Private key for Windows 2016 EC2 instance"
}

resource "aws_secretsmanager_secret_version" "windows_key_secret_version" {
  secret_id     = aws_secretsmanager_secret.windows_key_secret.id
  secret_string = tls_private_key.windows_key.private_key_pem
}

resource "aws_key_pair" "windows_key_pair" {
  key_name   = "windows2016-key"
  public_key = tls_private_key.windows_key.public_key_openssh
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
  availability_zone       = "ap-south-1a"
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

resource "aws_security_group" "windows_sg" {
  name        = "windows2016-sg"
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
  name = "ec2_ssm_role"

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
  name = "ssm-instance-profile"
  role = aws_iam_role.ssm_role.name
}

data "aws_ami" "windows2016" {
  most_recent = true
  owners      = ["801119661308"]

  filter {
    name   = "name"
    values = ["Windows_Server-2016-English-Full-Base-*"]
  }
}

resource "aws_instance" "windows2016" {
  ami                    = data.aws_ami.windows2016.id
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.public.id
  key_name               = aws_key_pair.windows_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.windows_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name

  tags = {
    Name = "Windows2016-EC2"
  }
}

output "instance_id" {
  value = aws_instance.windows2016.id
}

output "public_ip" {
  value = aws_instance.windows2016.public_ip
}

output "key_secret_arn" {
  value = aws_secretsmanager_secret.windows_key_secret.arn
}
