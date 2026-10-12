resource "docker_network" "tf_net" {
  name   = "tf_net"
  driver = "bridge"
}

resource "docker_volume" "tf_html" {
  name = "tf_html"
}

resource "docker_image" "nginx" {
  name         = var.nginx_image
  keep_locally = true
}

resource "docker_container" "web" {
  name    = "tf-nginx"
  image   = docker_image.nginx.image_id
  restart = "unless-stopped"

  ports {
    internal = 80
    external = var.external_port
  }

  networks_advanced {
    name = docker_network.tf_net.name
  }

  volumes {
    volume_name    = docker_volume.tf_html.name
    container_path = "/usr/share/nginx/html"
  }

  healthcheck {
    test         = ["CMD", "wget", "-qO-", "http://127.0.0.1/"]
    interval     = "10s"
    timeout      = "3s"
    retries      = 3
    start_period = "3s"
  }

  wait         = true
  wait_timeout = 60
}
