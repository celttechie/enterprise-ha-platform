# IAM Roles, OIDC Provider (IRSA), and Deterministic Key Management

# -----------------------------------------------------------------------------
# 1. EKS Control Plane IAM Role
# -----------------------------------------------------------------------------
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-cluster-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

# -----------------------------------------------------------------------------
# 2. Worker Node IAM Role (with Keyless SSM Session Manager Access)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "node" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-node-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "node_worker_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_ssm_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.node.name
}

# -----------------------------------------------------------------------------
# 3. IAM OIDC Provider for Pod Identity / IRSA (Zero Static Pod Credentials)
# -----------------------------------------------------------------------------
data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-oidc-provider"
    }
  )
}

# -----------------------------------------------------------------------------
# 4. Deterministic KeyPair & AWS Secrets Manager (Zero Workstation Sprawl)
# -----------------------------------------------------------------------------
resource "tls_private_key" "node_ssh" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "node_key" {
  key_name   = "${var.cluster_name}-node-key"
  public_key = tls_private_key.node_ssh.public_key_openssh

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-node-key"
    }
  )
}

resource "aws_secretsmanager_secret" "node_ssh_private_key" {
  name                    = "${var.cluster_name}-node-ssh-key"
  description             = "Deterministic SSH private key for emergency console access on ${var.cluster_name} nodes (Zero disk sprawl)"
  recovery_window_in_days = 0

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-node-ssh-key"
    }
  )
}

resource "aws_secretsmanager_secret_version" "node_ssh_private_key" {
  secret_id     = aws_secretsmanager_secret.node_ssh_private_key.id
  secret_string = tls_private_key.node_ssh.private_key_openssh
}
