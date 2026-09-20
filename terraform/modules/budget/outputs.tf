output "enabled" { value = length(aws_budgets_budget.monthly) == 1 }
