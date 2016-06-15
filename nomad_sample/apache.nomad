job "apache" {
	datacenters = ["dc1"]

	constraint {
		attribute = "${attr.kernel.name}"
		value = "linux"
	}

	# Configure the job to do rolling updates
	update {
		stagger = "10s"
		max_parallel = 1
	}

	group "nomad" {
		count = 1

		restart {
			attempts = 10
			interval = "5m"
			delay = "25s"
			mode = "delay"
		}

		task "worker" {
			driver = "docker"
			config {
				image = "httpd:latest"
				port_map {
					http = 80
				}
			}

			service {
				name = "job01"
				tags = ["nomad-worker"] #
				port = "http"
				check {
					name = "alive"
					type = "tcp"
					interval = "10s"
					timeout = "2s"
				}
			}

			resources {
				cpu = 100 # 100 Mhz
				memory = 64 # 64MB
				network {
					mbits = 10
					port "http" { }
				}
			}
		}
	}
}
