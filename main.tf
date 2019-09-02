# Init Providers
provider "kubernetes" {
  config_path      = data.azurerm_kubernetes_cluster.aksv.kube_admin_config_raw
  load_config_file = false
  host             = data.azurerm_kubernetes_cluster.aksv.kube_admin_config[0].host
  username         = data.azurerm_kubernetes_cluster.aksv.kube_admin_config[0].username
  password         = data.azurerm_kubernetes_cluster.aksv.kube_admin_config[0].password
  client_certificate = base64decode(
    data.azurerm_kubernetes_cluster.aksv.kube_admin_config[0].client_certificate,
  )
  client_key = base64decode(
    data.azurerm_kubernetes_cluster.aksv.kube_admin_config[0].client_key,
  )
  cluster_ca_certificate = base64decode(
    data.azurerm_kubernetes_cluster.aksv.kube_admin_config[0].cluster_ca_certificate,
  )
}

## Apply Helm RBAC
resource "kubernetes_service_account" "tiller_service_account" {
  metadata {
    name      = "tiller"
    namespace = "${local.kube_namespace}"
  }
}

resource "kubernetes_cluster_role_binding" "tiller_cluster_role_binding" {
  metadata {
    name = "tiller"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "${local.cluster_role_binding}"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.tiller_service_account.metadata[0].name
    namespace = "${local.kube_namespace}"
  }
}
# Create project namespace
resource "kubernetes_namespace" "kube_namespace" {
  metadata {
    name = "${lower(var.cod_app)}"
  }
}
# Create Kube TLS Secret
resource "kubernetes_secret" "tls_secret" {
  type = "kubernetes.io/tls" #Opaque
  metadata {
    name      = "${local.azingress_secret_tls}"
    namespace = "${local.default_namespace}"
  }
  data = {
    "tls.crt" = data.local_file.pfx_cert.content
    "tls.key" = data.local_file.pfx_key.content
  }
  depends_on = [
    data.local_file.pfx_cert,
    data.local_file.pfx_key,
  ]
}


# Helm Install
provider "helm" {
  service_account = kubernetes_service_account.tiller_service_account.metadata[0].name
  kubernetes {
    config_path      = data.azurerm_kubernetes_cluster.aksv.kube_admin_config_raw
    load_config_file = false
    host             = data.azurerm_kubernetes_cluster.aksv.kube_admin_config[0].host
    client_certificate = base64decode(
    data.azurerm_kubernetes_cluster.aksv.kube_admin_config[0].client_certificate,
  )
  client_key = base64decode(
    data.azurerm_kubernetes_cluster.aksv.kube_admin_config[0].client_key,
  )
  cluster_ca_certificate = base64decode(
    data.azurerm_kubernetes_cluster.aksv.kube_admin_config[0].cluster_ca_certificate,
  )
  }
}

# Install Cert Manager
resource "helm_release" "cert_manager" {
  name      = "${local.cert_manager_name}"
  chart     = "stable/cert-manager"
  namespace = "${local.kube_namespace}"
  version   = "${local.cert_manager_version}"
  set {
    name  = "rbac.create"
    value = "true"
  }
  depends_on = [kubernetes_cluster_role_binding.tiller_cluster_role_binding]
}

# Install Ingress Controller passthrough
resource "helm_release" "ngix_ingress" {
  name         = "ingress-controller"
  chart        = "stable/nginx-ingress"
  namespace    = "${local.default_namespace}"
  force_update = true

  values = [
    <<EOF
    controller:
      extraArgs:
        default-ssl-certificate: "${local.default_namespace}/${kubernetes_secret.tls_secret.metadata[0].name}"
        enable-ssl-chain-completion: "false"
        enable-ssl-passthrough: ""
      service:
        annotations:
          service.beta.kubernetes.io/azure-load-balancer-internal : "true"
  EOF
  ]
  set {
    name  = "rbac.create"
    value = "true"
  }
  depends_on = [kubernetes_secret.tls_secret]
}
