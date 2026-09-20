# Plan-time tests of the bootstrap's owner/service rules. Providers are mocked,
# so this runs without credentials or network (terraform test, in `task tf:test`).

mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws", dns_suffix = "amazonaws.com" }
  }
}

variables {
  github_repository   = "example/platform"
  deploy_environments = ["dev", "prod"]
}

run "refuses_a_service_named_like_the_platform" {
  command = plan
  variables {
    services = [{ name = "platform", github_repository = "example/api" }]
  }
  expect_failures = [var.services]
}

run "refuses_duplicate_service_names" {
  command = plan
  variables {
    services = [
      { name = "todo-api", github_repository = "example/api" },
      { name = "todo-api", github_repository = "example/api-2" },
    ]
  }
  expect_failures = [var.services]
}

run "one_backend_and_role_per_owner_and_env" {
  command = plan
  variables {
    services = [
      { name = "todo-api", github_repository = "example/api" },
      { name = "orders-api", github_repository = "example/orders" },
    ]
  }
  assert {
    condition     = toset(keys(module.backend)) == toset(["platform/dev", "platform/prod", "todo-api/dev", "todo-api/prod", "orders-api/dev", "orders-api/prod"])
    error_message = "every owner must get a backend per environment"
  }
  assert {
    condition     = module.backend["todo-api/dev"].state_bucket == "todo-api-tfstate-dev-123456789012" && module.backend["todo-api/dev"].lock_table == "todo-api-tflock-dev"
    error_message = "service backends must use the derived names the API repo's task tf:plan computes"
  }
  assert {
    condition     = toset(keys(module.github_oidc.role_arns)) == toset(["github-deploy-platform-dev", "github-deploy-platform-prod", "github-deploy-todo-api-dev", "github-deploy-todo-api-prod", "github-deploy-orders-api-dev", "github-deploy-orders-api-prod"])
    error_message = "every owner must get a deploy role per environment"
  }
  assert {
    condition     = length(module.github_oidc.aws_iam_role_policy_attachment.admin) == 2 && length(module.github_oidc.aws_iam_role_policy_attachment.poweruser) == 4
    error_message = "only the platform's roles are administrators; service roles are PowerUser + scoped IAM"
  }
}
