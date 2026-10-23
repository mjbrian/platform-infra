terraform {
  required_version = ">= 1.7"
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
  backend "local" {}
}

provider "github" {
  owner = "mjbrian"
}

locals {
  platform_repos = {
    "platform-bootstrap" = "Sets up the whole lab from one command"
    "platform-infra"     = "Terraform, cluster settings and shared tool settings"
    "platform-gitops"    = "Everything Argo CD runs, on every cluster"
    "platform-tools"     = "Shared pipelines, charts and templates"
  }
}

import {
  for_each = local.platform_repos
  to       = github_repository.platform[each.key]
  id       = each.key
}

resource "github_repository" "platform" {
  for_each               = local.platform_repos
  name                   = each.key
  description            = each.value
  visibility             = "public"
  has_issues             = true
  has_wiki               = false
  has_projects           = false
  allow_merge_commit     = false
  allow_rebase_merge     = false
  allow_squash_merge     = true
  delete_branch_on_merge = true
  vulnerability_alerts   = true
  archive_on_destroy     = true
}

resource "github_repository_ruleset" "protect_main" {
  for_each    = github_repository.platform
  name        = "protect-main"
  repository  = each.value.name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  rules {
    deletion         = true
    non_fast_forward = true
    pull_request {
      required_approving_review_count   = 0
      dismiss_stale_reviews_on_push     = true
      required_review_thread_resolution = true
    }
  }
}
