job "enterprise-ecommerce-demo" {
  region      = "global"
  datacenters = ["us-central1"]
  type        = "service"

  # Rolling updates strategy
  update {
    max_parallel      = 1
    min_healthy_time  = "10s"
    healthy_deadline  = "3m"
    progress_deadline = "10m"
    auto_revert       = true
    canary            = 0
  }

  # =================================================================
  # TIER 1: E-Commerce Web Storefront (Juice Shop / Port 3000)
  # =================================================================
  group "frontend-store" {
    count = 1

    network {
      port "web" {
        to = 3000 # Juice Shop natively runs on 3000
      }
    }

    task "juice-shop-web" {
      driver = "docker"

      config {
        image = "bkimminich/juice-shop:v16.0.0"
        ports = ["web"]
      }

      # Custom business configuration
      env {
        NODE_ENV = "production"
      }

      resources {
        cpu    = 500
        memory = 512 # Premium specs for smooth storefront operation
      }

      service {
        name = "store-frontend"
        port = "web"
        tags = ["storefront", "v1"]

        check {
          name     = "http-alive"
          type     = "http"
          path     = "/"
          interval = "15s"
          timeout  = "3s"
        }
      }
    }
  }

  # =================================================================
  # TIER 2: Premium Coffee Catalog (HashiCups / Port 80)
  # =================================================================
  group "coffee-catalog" {
    count = 1

    network {
      port "web" {
        to = 80 # HashiCups runs on port 80
      }
    }

    task "hashicups-web" {
      driver = "docker"

      config {
        image = "hashicorp/hashicups-frontend:v0.1.1"
        ports = ["web"]
      }

      resources {
        cpu    = 300
        memory = 256
      }

      service {
        name = "coffee-store"
        port = "web"
        tags = ["coffee", "http"]

        check {
          name     = "coffee-alive"
          type     = "http"
          path     = "/"
          interval = "15s"
          timeout  = "3s"
        }
      }
    }
  }
}
