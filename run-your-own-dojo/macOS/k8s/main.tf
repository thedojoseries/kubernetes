data "aws_caller_identity" "current" {}

resource "kubernetes_namespace" "namespace" {
  count = var.max_team_number - var.min_team_number + 1

  metadata {
    name = "team${count.index + var.min_team_number}"
  }
}

resource "kubernetes_role" "team_role" {
  count = var.max_team_number - var.min_team_number + 1

  metadata {
    name      = "team${count.index + var.min_team_number}-role"
    namespace = "team${count.index + var.min_team_number}"
  }

  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["*"]
  }

  depends_on = [kubernetes_namespace.namespace]
}

resource "kubernetes_role_binding" "example" {
  count = var.max_team_number - var.min_team_number + 1

  metadata {
    name      = "team${count.index + var.min_team_number}-role-binding"
    namespace = "team${count.index + var.min_team_number}"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "team${count.index + var.min_team_number}-role"
  }

  subject {
    kind      = "User"
    name      = "team${count.index + var.min_team_number}"
    api_group = "rbac.authorization.k8s.io"
  }

  depends_on = [kubernetes_namespace.namespace]
}
