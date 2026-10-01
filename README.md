# VICC Praxisarbeit – Containerisierte Webapplikation auf Azure (PaaS, DBaaS, IaC)

Praxisarbeit im Fach Virtualisierung und Cloud Computing (VICC), HFINFP 3. Studienjahr, ipso! Bildung.

**Thema:** Bereitstellung einer containerisierten Webapplikation auf Azure mittels PaaS,
DBaaS und Infrastructure as Code.

| Bereich | Technologie |
|---|---|
| Container-Runtime (PaaS) | Azure Container Apps (Consumption) |
| Datenbank (DBaaS) | Azure SQL Database, Serverless (GP_S_Gen5_1) |
| Infrastructure as Code | Terraform (azurerm ~> 4.0) |
| Container Registry | Docker Hub (öffentlich) |
| Logging | Azure Log Analytics |
| CI | GitHub Actions (Build & Push Image) |

Die Applikation (Flask, Inventarliste mit HTML-Ansicht und JSON-API) ist gemäss
Aufgabenstellung **nicht** Bewertungsgegenstand und dient als Testlast für die Infrastruktur.

## Repository-Struktur

```
app/        Applikation, Dockerfile, docker-compose.yml (lokaler Betrieb)
infra/      Terraform-Konfiguration für die gesamte Azure-Infrastruktur
docs/       Architekturzeichnung und Begleitmaterial zur Dokumentation
.github/    Workflow: Image bauen und auf Docker Hub veröffentlichen
```

## Nachbau der Umgebung

Voraussetzungen: Azure-Subscription, [Azure CLI](https://learn.microsoft.com/cli/azure/),
[Terraform ≥ 1.6](https://developer.hashicorp.com/terraform/install).

```bash
az login
az account set --subscription "<SUBSCRIPTION-ID>"

cd infra
cp terraform.tfvars.example terraform.tfvars   # container_image anpassen
terraform init
terraform plan -out tfplan
terraform apply tfplan

terraform output app_url   # Browser
terraform output api_url   # Web-API
```

Das öffentliche Image `cyxeon/vicc-inventory:latest` kann direkt verwendet werden;
ein eigener Build ist für den Nachbau nicht erforderlich.

Abbau der Umgebung: `terraform destroy`.

## Endpunkte

| Zugriff | Pfad | Beschreibung |
|---|---|---|
| Browser | `/` | HTML-Oberfläche (Einträge anzeigen, anlegen, löschen) |
| Web-API | `GET /api/items` | Alle Einträge als JSON |
| Web-API | `POST /api/items` | Eintrag anlegen, Body `{"name": "...", "quantity": 1}` |
| Web-API | `GET /api/items/{id}` | Einzelner Eintrag |
| Web-API | `PUT /api/items/{id}` | Eintrag ändern |
| Web-API | `DELETE /api/items/{id}` | Eintrag löschen |
| Health | `GET /health` | Liveness (ohne Datenbank) |
| Health | `GET /api/health` | Readiness inkl. Datenbank-Roundtrip |

Beispiel:

```bash
APP=$(terraform -chdir=infra output -raw app_url)
curl -s "$APP/api/items"
curl -s -X POST "$APP/api/items" -H "Content-Type: application/json" -d '{"name":"Laptop","quantity":3}'
```

## Lokaler Betrieb (Portierbarkeits-Nachweis)

```bash
cd app
docker compose up --build
# http://localhost:8000
```

## IST / SOLL

| Thema | IST (umgesetzt) | SOLL (geplant, nicht umgesetzt) |
|---|---|---|
| DB-Authentifizierung | SQL-Login, Passwort als Container-App-Secret | Managed Identity mit Entra-ID-Authentifizierung |
| Netzwerk | Öffentlicher SQL-Endpunkt, Firewall «Allow Azure services» | VNet-Integration und Private Endpoint |
| Terraform State | lokal | Remote State in Azure Storage (`backend.tf.example`) |
| Hochverfügbarkeit DB | Lokal redundanter Speicher, Standard-SLA | Zone-redundante Konfiguration |
| Image-Deployment | manuelles `terraform apply` mit neuem Tag | automatisiertes Rollout nach Image-Push |

## Dokumentation

Repository: https://github.com/mogomes/vicc_pa – Image: https://hub.docker.com/r/cyxeon/vicc-inventory

Die schriftliche Arbeit (PDF) wird über die ipso-Campus-Plattform abgegeben. Dieses
Repository enthält sämtliche Scripts und Konfigurationen, die zum Nachbau der Umgebung
benötigt werden.
