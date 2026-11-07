# Amazon EBS CSI Driver Managed Addon & Pod Identity (Milestone 2.3)

# -----------------------------------------------------------------------------
# 1. IAM Role for Amazon EBS CSI Driver (Pod Identity & IRSA dual compatibility)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "ebs_csi" {
  name = "${var.cluster_name}-ebs-csi-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      },
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-ebs-csi-role"
    }
  )
}

# Attach AWS managed policy for EBS CSI driver
resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi.name
}

# KMS Key usage policy for EBS CSI volume encryption
resource "aws_iam_policy" "ebs_csi_kms" {
  count       = var.enable_kms_encryption ? 1 : 0
  name        = "${var.cluster_name}-ebs-csi-kms-policy"
  description = "Allows EBS CSI Driver to use dedicated KMS key for encrypting persistent volumes"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.eks_secrets[0].arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_kms" {
  count      = var.enable_kms_encryption ? 1 : 0
  policy_arn = aws_iam_policy.ebs_csi_kms[0].arn
  role       = aws_iam_role.ebs_csi.name
}

# -----------------------------------------------------------------------------
# 2. EKS Pod Identity Association
# -----------------------------------------------------------------------------
resource "aws_eks_pod_identity_association" "ebs_csi" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi.arn
}

# -----------------------------------------------------------------------------
# 3. Managed EKS Addon: aws-ebs-csi-driver
# -----------------------------------------------------------------------------
resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.spot,
    aws_eks_pod_identity_association.ebs_csi
  ]

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-ebs-csi"
    }
  )
}
