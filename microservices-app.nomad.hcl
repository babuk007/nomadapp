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
  # Tier 1: Backend REST API (Java Spring Boot App)
  # ---------------------------------------------------------
  group "backend-api" {
    count = 2 # Scales out to 2 instances across nodes

    # Ensure instances are placed on different physical nodes if possible
    constraint {
      attribute = "${node.unique.name}"
      operator  = "distinct_property"
    }

    network {
      port "http" {
        to = 8080 # Container internal port mapped to dynamic host port
      }
    }

    task "api-service" {
      driver = "docker"

      config {
        image = "myorg/backend-api:v2.1.0"
        ports = ["http"]
      }

      # Inject environment variables dynamically
      env {
        SPRING_PROFILES_ACTIVE = "prod"
        JVM_OPTS               = "-Xms256m -Xmx512m"
      }

      # Dynamically discover Redis using Nomad/Consul DNS or templates
      template {
        destination = "local/application.properties"
        change_mode = "restart"
        data        = <<EOH
# Spring Data Redis Configuration
{{ range service "app-redis" }}
spring.data.redis.host={{ .Address }}
spring.data.redis.port={{ .Port }}
{{ else }}
spring.data.redis.host=localhost
spring.data.redis.port=6379
{{ end }}

# Database password from Vault (securely injected)
# spring.datasource.password = "{{ with secret "secret/data/db" }}{{ .Data.data.password }}{{ end }}"
EOH
      }

      resources {
        cpu    = 800  # MHz
        memory = 512  # MB
      }

      service {
        name = "backend-api"
        port = "http"
        tags = ["api", "v2"]

        check {
          name     = "http-health-endpoint"
          type     = "http"
          path     = "/actuator/health"
          interval = "15s"
          timeout  = "3s"

          check_restart {
            limit           = 3
            grace           = "60s"
            ignore_warnings = false
          }
        }
      }
    }
  }

  # ---------------------------------------------------------
  # Tier 2: Frontend Client Web Server (React & Nginx)
  # ---------------------------------------------------------
  group "frontend" {
    count = 2

    network {
      port "web" {
        to = 80
      }
    }

    task "web-portal" {
      driver = "docker"

      config {
        image = "myorg/frontend-portal:v1.3.0"
        ports = ["web"]
      }

      # Render custom Nginx reverse proxy configuration to route /api traffic to our dynamic backend-api service
      template {
        destination = "local/nginx.conf"
        change_mode = "signal"
        change_signal = "SIGHUP" # Reloads Nginx gracefully without container restart
        data        = <<EOH
server {
    listen 80;
    server_name localhost;

    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        # Reverse Proxy to backend-api dynamically resolved from Nomad's Consul registry
        {{ range service "backend-api" }}
        proxy_pass http://{{ .Address }}:{{ .Port }}/;
        {{ else }}
        return 502 "No healthy backend instances found";
        {{ end }}
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOH
      }

      resources {
        cpu    = 200  # MHz
        memory = 128  # MB
      }

      service {
        name = "frontend"
        port = "web"
        tags = ["frontend", "http"]

        check {
          name     = "web-portal-alive"
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
