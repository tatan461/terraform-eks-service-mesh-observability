resource "kubernetes_namespace" "istio_system" {
  metadata {
    name = "istio-system"
  }
}

resource "helm_release" "istio_base" {
  name             = "istio-base"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "base"
  namespace        = kubernetes_namespace.istio_system.metadata[0].name
  timeout          = 900
  atomic           = true
  cleanup_on_fail  = true

  depends_on = [kubernetes_namespace.istio_system]
}

resource "helm_release" "istiod" {
  name             = "istiod"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "istiod"
  namespace        = kubernetes_namespace.istio_system.metadata[0].name
  timeout          = 900
  atomic           = true
  cleanup_on_fail  = true
  wait             = true

  # Forzamos valores seguros para evitar bloqueos en entornos de pruebas pequeños
  set {
    name  = "pilot.resources.requests.cpu"
    value = "10m"
  }

  set {
    name  = "pilot.resources.requests.memory"
    value = "128Mi"
  }

  depends_on = [helm_release.istio_base]
}