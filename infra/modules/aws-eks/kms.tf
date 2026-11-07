# KMS CMK for EKS Secrets Envelope Encryption

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "eks_secrets" {
  count                   = var.enable_kms_encryption ? 1 : 0
  description             = "KMS CMK for EKS cluster secrets envelope encryption (${var.cluster_name})"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootKeyAdministration"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowEKSServiceToUseKey"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.cluster.arn
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-secrets-kms"
    }
  )
}

resource "aws_kms_alias" "eks_secrets" {
  count         = var.enable_kms_encryption ? 1 : 0
  name          = "alias/${var.cluster_name}-secrets"
  target_key_id = aws_kms_key.eks_secrets[0].key_id
}
