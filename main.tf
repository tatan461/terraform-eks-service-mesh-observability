provider "aws" {
  region = var.aws_region
}

# 1. Módulo VPC
module "vpc" {
  source = "./modules/vpc"

  vpc_name        = "eks-vpc"
  vpc_cidr        = "10.0.0.0/16"
  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

# 2. Módulo EKS (v1.32 con nodos t3.small)
module "eks" {
  source = "./modules/eks"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets
}

# Pausa de sincronización obligatoria para estabilizar los nodos y la API
resource "time_sleep" "wait_for_eks" {
  depends_on      = [module.eks]
  create_duration = "90s"
}

# Proveedores dinámicos para Kubernetes y Helm
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
    }
  }
}

# 3. Complementos de plataforma
module "aws_load_balancer_controller" {
  source       = "./modules/aws-load-balancer-controller"
  cluster_name = module.eks.cluster_name
  vpc_id       = module.vpc.vpc_id
  region       = var.aws_region

  depends_on = [time_sleep.wait_for_eks]
}

module "istio" {
  source     = "./modules/istio"
  depends_on = [time_sleep.wait_for_eks]
}

module "monitoring" {
  source                 = "./modules/monitoring"
  cluster_endpoint       = module.eks.cluster_endpoint
  cluster_ca_certificate = module.eks.cluster_certificate_authority_data
  cluster_name           = var.cluster_name
  aws_region             = var.aws_region

  depends_on = [time_sleep.wait_for_eks]
}