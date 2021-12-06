provider "aws" {
  region = "us-east-1"
  access_key = "AKIASAPW6S4RHALJVTG6"
  secret_key = "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"
}

resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.first-vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "prod-subnet"
  }
}


resource "aws_vpc" "first-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "production"
  }
}


#1. Create a VPC.  
resource "aws_vpc" "prod-vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}
#2. Create an Internet Gateway.
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id

  tags = {
    Name = "production vpc"
  }
}

#3. Create a custom route table.
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route = [
    {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.gw.id
    },

    {
      ipv6_cidr_block        = "::/0"
      gateway_id = aws_internet_gateway.gw.id
    }
  ]

  tags = {
    Name = "production route table"
  }
}
#4. Create a subnet.
resource "aws_subnet" "subent-1" {
  vpc_id = aws_vpc.prod-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    "Name" = "prod-subnet"
  }

}

#5. Associate the subnet with the route table.
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subent-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

#6. Create a security group and open ports: 22 (SSH), 80 (HTTP), 443 (HTTPS).
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffice"
  description = "Allow web traffice"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress = [
    {
      description      = "HTTPS"
      from_port        = 443
      to_port          = 443
      protocol         = "TCP"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["0.0.0.0/0"]

      description      = "HTTP"
      from_port        = 80
      to_port          = 80
      protocol         = "TCP"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["0.0.0.0/0"]

      description      = "SSH"
      from_port        = 23
      to_port          = 23
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  ]

  egress = [
    {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  ]

  tags = {
    Name = "allow_web"
  }
}

#7 Create a network interface with an IP addr. in the subnet.
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subent-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

}

#8 Assign an elastic IP to the network interface 
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw]

}

#9 Create an Ubuntu server and install/enable Apache2 (web server)
resource "aws_instance" "web-server-instance" {

  ami = "ami-09e67e426f25ce0d7"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "RHEL8-Demo"
  
  network_interface {
    device_index = 0
    network_interface_id = "web-server-nic"
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -s 'echo your very first web server > /var/www/html/index.html'
              EOF
  tags = {name = "web-server"
  }
}

