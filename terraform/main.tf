############### Instance ###############
# Create provider to setup into AWS
provider "aws" {
  region = "${var.region}"
}

# Create SSH Key Pair
resource "aws_key_pair" "keypair" {
  key_name   = "${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}

# Load the script to start nginx
data "template_file" "start_nginx" {
  template = "${file("${path.module}/start_nginx.sh")}"
}

# Define which AMI to use
data "aws_ami" "nginx_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["nginx-server_*"]
  }
}

# Create nginx server
resource "aws_instance" "nginx" {
  ami           = "${data.aws_ami.nginx_ami.image_id}"
  instance_type = "${var.instance_type}"
  subnet_id     = "${aws_subnet.public-subnet.id}"
  key_name      = "${aws_key_pair.keypair.key_name}"
  user_data     = "${data.template_file.start_nginx.rendered}"

  vpc_security_group_ids = [
    "${aws_security_group.nginx-vpc.id}",
    "${aws_security_group.nginx-public-ingress.id}",
    "${aws_security_group.nginx-public-egress.id}",
  ]

  tags {
    Name = "nginx"
  }
}

############### Instance ###############
############### VPC ###############

# Define the VPC.
resource "aws_vpc" "nginx" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_hostnames = true

  tags {
    Name = "Nginx VPC"
  }
}

# Create an Internet Gateway for the VPC.
resource "aws_internet_gateway" "nginx" {
  vpc_id = "${aws_vpc.nginx.id}"

  tags {
    Name = "Nginx IGW"
  }
}

# Create a public subnet.
resource "aws_subnet" "public-subnet" {
  vpc_id                  = "${aws_vpc.nginx.id}"
  cidr_block              = "${var.subnet_cidr}"
  availability_zone       = "${var.subnet_az}"
  map_public_ip_on_launch = true
  depends_on              = ["aws_internet_gateway.nginx"]

  tags {
    Name = "Nginx Public Subnet"
  }
}

# Create a route table allowing all addresses access to the IGW.
resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.nginx.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.nginx.id}"
  }

  tags {
    Name = "Nginx Public Route Table"
  }
}

# Now associate the route table with the public subnet - giving
# all public subnet instances access to the internet.
resource "aws_route_table_association" "public-subnet" {
  subnet_id      = "${aws_subnet.public-subnet.id}"
  route_table_id = "${aws_route_table.public.id}"
}

############### VPC ###############
############### Security ###############

# This security group allows intra-node communication on all ports with all
# protocols.
resource "aws_security_group" "nginx-vpc" {
  name        = "nginx-vpc"
  description = "Default security group that allows all instances in the VPC to talk to each other over any port and protocol."
  vpc_id      = "${aws_vpc.nginx.id}"

  ingress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = true
  }

  tags {
    Name    = "Nginx Internal VPC"
    Project = "nginx"
  }
}

# This security group allows public ingress to the instances for HTTP, HTTPS
# and common HTTP/S proxy ports.
resource "aws_security_group" "nginx-public-ingress" {
  name        = "nginx-public-ingress"
  description = "Security group that allows public ingress to instances, HTTP, HTTPS and more."
  vpc_id      = "${aws_vpc.nginx.id}"

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP Proxy
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS Proxy
  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name    = "Nginx Public Access"
    Project = "nginx"
  }
}

# This security group allows public egress from the instances for HTTP and
# HTTPS, which is needed for yum updates, git access etc etc.
resource "aws_security_group" "nginx-public-egress" {
  name        = "nginx-public-egress"
  description = "Security group that allows egress to the internet for instances over HTTP and HTTPS."
  vpc_id      = "${aws_vpc.nginx.id}"

  # HTTP
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name    = "Nginx Public Access"
    Project = "nginx"
  }
}

############### Security ###############

