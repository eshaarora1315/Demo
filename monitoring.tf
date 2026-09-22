resource "helm_release" "prometheus_operator" {
  count      = var.enable_monitoring ? 1 : 0
  name       = "prometheus-operator"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  version    = "57.0.0"

  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "30d"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.accessModes[0]"
    value = "ReadWriteOnce"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = "50Gi"
  }

  set {
    name  = "grafana.adminPassword"
    value = random_password.grafana_password[0].result
  }

  set {
    name  = "grafana.persistence.enabled"
    value = "true"
  }

  set {
    name  = "grafana.persistence.size"
    value = "10Gi"
  }

  set {
    name  = "alertmanager.enabled"
    value = "true"
  }

  set {
    name  = "alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage"
    value = "10Gi"
  }

  depends_on = [
    module.eks
  ]

  timeout = 600

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-prometheus-operator"
    }
  )
}

resource "random_password" "grafana_password" {
  count   = var.enable_monitoring ? 1 : 0
  length  = 16
  special = true
}

resource "kubernetes_service" "prometheus" {
  count = var.enable_monitoring ? 1 : 0
  metadata {
    name      = "prometheus-service"
    namespace = "monitoring"
  }

  spec {
    selector = {
      app = "prometheus"
    }

    port {
      port        = 9090
      target_port = 9090
      protocol    = "TCP"
    }

    type = "LoadBalancer"
  }

  depends_on = [helm_release.prometheus_operator]
}

resource "kubernetes_service" "grafana" {
  count = var.enable_monitoring ? 1 : 0
  metadata {
    name      = "grafana-service"
    namespace = "monitoring"
  }

  spec {
    selector = {
      app = "grafana"
    }

    port {
      port        = 3000
      target_port = 3000
      protocol    = "TCP"
    }

    type = "LoadBalancer"
  }

  depends_on = [helm_release.prometheus_operator]
}

resource "helm_release" "fluent_bit" {
  count      = var.enable_monitoring ? 1 : 0
  name       = "fluent-bit"
  repository = "https://fluent.github.io/helm-charts"
  chart      = "fluent-bit"
  namespace  = "logging"
  version    = "0.21.0"

  set {
    name  = "config.outputs.cloudwatch.enabled"
    value = "true"
  }

  set {
    name  = "config.outputs.cloudwatch.log_group_name"
    value = "/aws/eks/${module.eks.cluster_id}/application-logs"
  }

  set {
    name  = "config.outputs.cloudwatch.log_stream_prefix"
    value = "from-fluent-bit-"
  }

  set {
    name  = "config.outputs.cloudwatch.auto_create_group"
    value = "true"
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "fluent-bit"
  }

  depends_on = [
    module.eks,
    kubernetes_namespace.logging
  ]

  timeout = 600

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-fluent-bit"
    }
  )
}

resource "helm_release" "metrics_server" {
  count      = var.enable_monitoring ? 1 : 0
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.14.0"

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }

  set {
    name  = "args[1]"
    value = "--kubelet-preferred-address-types=InternalIP"
  }

  depends_on = [module.eks]

  timeout = 600

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-metrics-server"
    }
  )
}
