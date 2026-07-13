job "e-commerce-suite" {
  region      = "global"
  datacenters = ["us-central1", "us-east1"]
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

  # ---------------------------------------------------------
  # Tier 1: Backend REST API (Mocked with Public Hello-Kubernetes on Port 8080)
  # ---------------------------------------------------------
  group "backend-api" {
    count = 2

    network {
      port "http" {
        to = 8080
      }
    }

    task "api-service" {
      driver = "docker"

      config {
        image = "paulbouwer/hello-kubernetes:1.10"
        ports = ["http"]
      }

      env {
        MESSAGE = "Successfully Modernized Backend API from Nomad to Cloud Run!"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name = "backend-api"
        port = "http"
        tags = ["api", "v2"]

        check {
          name     = "http-health"
          type     = "http"
          path     = "/"
          interval = "15s"
          timeout  = "3s"
        }
      }
    }
  }

  # ---------------------------------------------------------
  # Tier 2: Frontend Client Web Server (Mocked with Public Hello-Kubernetes on Port 8080)
  # ---------------------------------------------------------
  group "frontend" {
    count = 2

    network {
      port "web" {
        to = 8080
      }
    }

    task "web-portal" {
      driver = "docker"

      config {
        image = "paulbouwer/hello-kubernetes:1.10"
        ports = ["web"]
      }

      env {
        MESSAGE = "Successfully Modernized Frontend Web Portal from Nomad to Cloud Run!"
      }

      resources {
        cpu    = 200
        memory = 128
      }

      service {
        name = "frontend"
        port = "web"
        tags = ["frontend", "http"]

        check {
          name     = "web-alive"
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
