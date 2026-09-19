output "data_key_arn" { value = aws_kms_key.data.arn }
output "data_key_id" { value = aws_kms_key.data.key_id }
output "ops_key_arn" { value = aws_kms_key.ops.arn }
output "ops_key_id" { value = aws_kms_key.ops.key_id }
