resource "aws_vpc" "demo_vpc" {
  cidr_block = var.cidr

}

resource "aws_subnet" "sub1" {
  vpc_id                  = aws_vpc.demo_vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "sub2" {
  vpc_id                  = aws_vpc.demo_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.demo_vpc.id

}

resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.demo_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

}

resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.RT.id

}

resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.sub2.id
  route_table_id = aws_route_table.RT.id

}

resource "aws_security_group" "mysg" {
  name   = "websg"
  vpc_id = aws_vpc.demo_vpc.id

  ingress {
    description = "Defines range and port of ip address that can access the instances on this vpc"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  egress {
    description = "defines ip addresses that instances/resources in this vpc can access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }

  tags = {
    Name = "web-sg"
  }

}

resource "aws_s3_bucket" "tf-s3-bucket" {
  bucket = "sandeepterraforms3"

}

resource "aws_instance" "webServer1" {
  ami                    = "ami-0e86e20dae9224db8"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.mysg.id]
  subnet_id              = aws_subnet.sub1.id
  user_data              = base64encode(file("userdata.sh"))

}

resource "aws_instance" "webServer2" {
  ami                    = "ami-0e86e20dae9224db8"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.mysg.id]
  subnet_id              = aws_subnet.sub2.id
  user_data              = base64encode(file("userdata1.sh"))

}

resource "aws_lb" "mylb" {
  name               = "myalb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.mysg.id]
  subnets         = [aws_subnet.sub1.id, aws_subnet.sub2.id]

  tags = {
    name = "web-loadbalancer"
  }

}

resource "aws_lb_target_group" "lb-TG" {
  name     = "web-lb-TG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.demo_vpc.id


  health_check {
    path = "/"
    port = "traffic-port"
  }

}

resource "aws_lb_target_group_attachment" "lb-TG-attach1" {
  target_group_arn = aws_lb_target_group.lb-TG.arn
  target_id        = aws_instance.webServer1.id
  port             = 80

}

resource "aws_lb_target_group_attachment" "lb-TG-attach2" {
  target_group_arn = aws_lb_target_group.lb-TG.arn
  target_id        = aws_instance.webServer2.id
  port             = 80

}

resource "aws_lb_listener" "lb-listener" {
  load_balancer_arn = aws_lb.mylb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.lb-TG.arn
    type             = "forward"
  }

}

output "loadbalancerdns" {

  value = aws_lb.mylb.dns_name
}

