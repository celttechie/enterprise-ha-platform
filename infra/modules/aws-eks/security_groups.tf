# Security Groups: EKS Control Plane and Worker Nodes (Zero Open Port 22)

# Cluster (Control Plane) Security Group
resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "EKS control plane security group"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Allow all outbound traffic from control plane"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name                                        = "${var.cluster_name}-cluster-sg"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )
}

# Worker Node Security Group
resource "aws_security_group" "node" {
  name        = "${var.cluster_name}-node-sg"
  description = "Security group for all worker nodes in the cluster"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Allow all outbound traffic from nodes"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name                                        = "${var.cluster_name}-node-sg"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )
}

# Node-to-Node Ingress (intra-cluster communication)
resource "aws_security_group_rule" "node_internal" {
  description              = "Allow nodes to communicate with each other"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.node.id
}

# Control Plane to Node Ingress (Kubelet and Pod API callbacks)
resource "aws_security_group_rule" "cluster_to_node_kubelet" {
  description              = "Allow control plane to communicate with kubelet"
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.cluster.id
}

resource "aws_security_group_rule" "cluster_to_node_https" {
  description              = "Allow control plane to communicate with pods running extension API servers"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.cluster.id
}

# Node to Control Plane Ingress (Kube-apiserver communication)
resource "aws_security_group_rule" "node_to_cluster_https" {
  description              = "Allow worker nodes to communicate with cluster API server"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node.id
}
