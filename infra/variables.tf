variable "project" {
  description = "Kurzname des Projekts, wird als Präfix für Ressourcennamen verwendet."
  type        = string
  default     = "vicc"
}

variable "environment" {
  description = "Umgebungsbezeichnung (z. B. prod, test)."
  type        = string
  default     = "prod"
}

variable "location" {
  description = "Azure-Region. Switzerland North ist die Region mit der geringsten Latenz aus der Schweiz."
  type        = string
  default     = "switzerlandnorth"
}

variable "container_image" {
  description = "Vollständiger Image-Name auf Docker Hub inkl. Tag, z. B. dockerhubuser/vicc-inventory:latest"
  type        = string
}

variable "container_port" {
  description = "Port, auf dem die Applikation im Container lauscht."
  type        = number
  default     = 8000
}

variable "container_cpu" {
  description = "vCPU pro Replica (Container Apps Consumption erlaubt 0.25er-Schritte)."
  type        = number
  default     = 0.25
}

variable "container_memory" {
  description = "Arbeitsspeicher pro Replica, muss zum CPU-Wert passen (0.25 vCPU -> 0.5Gi)."
  type        = string
  default     = "0.5Gi"
}

variable "min_replicas" {
  description = <<-EOT
    Minimale Anzahl Replicas. 0 = Scale-to-Zero (günstigster Betrieb, aber Cold Start
    beim ersten Aufruf). Für die Abgabe- und Bewertungsphase wird 1 empfohlen, damit
    die Applikation beim Aufruf durch den Examinator sofort antwortet.
  EOT
  type        = number
  default     = 1
}

variable "max_replicas" {
  description = "Maximale Anzahl Replicas für das horizontale Autoscaling."
  type        = number
  default     = 5
}

variable "scale_concurrent_requests" {
  description = "HTTP-Scale-Regel: Ab dieser Anzahl gleichzeitiger Requests pro Replica wird eine weitere Replica gestartet."
  type        = number
  default     = 20
}

variable "sql_admin_login" {
  description = "Administrator-Login für den Azure SQL Server."
  type        = string
  default     = "sqladmin"
}

variable "sql_sku_name" {
  description = "SKU der Datenbank. GP_S_Gen5_1 = General Purpose, Serverless, Gen5, max. 1 vCore."
  type        = string
  default     = "GP_S_Gen5_1"
}

variable "sql_min_capacity" {
  description = "Minimale vCores im Serverless-Modus (0.5 ist das Minimum bei GP_S_Gen5_1)."
  type        = number
  default     = 0.5
}

variable "sql_auto_pause_delay" {
  description = <<-EOT
    Minuten ohne Aktivität, bis die Serverless-Datenbank pausiert. -1 = Auto-Pause
    deaktiviert. Minimum 60. Für die Bewertungsphase -1 empfohlen (kein Cold Start),
    danach z. B. 60 zur Kostenreduktion.
  EOT
  type        = number
  default     = -1
}

variable "sql_max_size_gb" {
  description = "Maximale Datenbankgrösse in GB."
  type        = number
  default     = 2
}

variable "tags" {
  description = "Tags für alle Ressourcen."
  type        = map(string)
  default = {
    Projekt = "VICC Praxisarbeit"
    Owner   = "Michael Gomes Monteiro"
    IaC     = "Terraform"
  }
}
