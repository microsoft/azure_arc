#
# VPC Resources
#  * VPC
#  * Subnets
#  * Internet Gateway
#  * Route Table
#

resource "aws_vpc" "arcdemo" {
  cidr_block = "10.0.0.0/16"

  tags = map(
    "Name", "terraform-eks-arcdemo-node",
    "kubernetes.io/cluster/${var.cluster-name}", "shared",
  )
}

resource "aws_subnet" "arcdemo" {
  count = 2

  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = "10.0.${count.index}.0/24"
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.arcdemo.id

  tags = map(
    "Name", "terraform-eks-arcdemo-node",
    "kubernetes.io/cluster/${var.cluster-name}", "shared",
  )
}

resource "aws_internet_gateway" "arcdemo" {
  vpc_id = aws_vpc.arcdemo.id

  tags = {
    Name = "terraform-eks-arcdemo"
  }
}

resource "aws_route_table" "arcdemo" {
  vpc_id = aws_vpc.arcdemo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.arcdemo.id
  }
}

resource "aws_route_table_association" "arcdemo" {
  count = 2

  subnet_id      = aws_subnet.arcdemo.*.id[count.index]
  route_table_id = aws_route_table.arcdemo.id
}
