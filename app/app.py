"""
Minimale CRUD-Webapplikation (Inventarliste) als Testlast für die Infrastruktur.

Die Applikation ist bewusst klein gehalten: Sie dient ausschliesslich dem Nachweis,
dass die bereitgestellte Plattform eine containerisierte Anwendung sowohl über den
Browser (HTML) als auch über eine Web-API (JSON) erreichbar macht.

Umgebungsvariablen (werden von der Container App gesetzt):
    DB_SERVER    FQDN des Azure SQL Servers, z. B. sql-vicc-abc123.database.windows.net
    DB_NAME      Name der Datenbank
    DB_USER      SQL-Login
    DB_PASSWORD  Passwort (Container-App-Secret)
    PORT         HTTP-Port, Standard 8000
"""

import logging
import os
import time
from contextlib import contextmanager

import pymssql
from flask import Flask, abort, jsonify, redirect, render_template, request, url_for

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("inventory")

app = Flask(__name__)

DB_CONFIG = {
    "server": os.environ.get("DB_SERVER", ""),
    "database": os.environ.get("DB_NAME", ""),
    "user": os.environ.get("DB_USER", ""),
    "password": os.environ.get("DB_PASSWORD", ""),
}


# --------------------------------------------------------------------------- #
# Datenbankzugriff
# --------------------------------------------------------------------------- #
@contextmanager
def get_conn():
    """Liefert eine Verbindung zu Azure SQL. Serverless-Datenbanken können nach
    dem Auto-Pause einige Sekunden zum Aufwachen brauchen, daher Retry."""
    last_error = None
    for attempt in range(1, 6):
        try:
            conn = pymssql.connect(
                server=DB_CONFIG["server"],
                user=DB_CONFIG["user"],
                password=DB_CONFIG["password"],
                database=DB_CONFIG["database"],
                port=1433,
                login_timeout=30,
                tds_version="7.4",
                as_dict=True,
            )
            try:
                yield conn
            finally:
                conn.close()
            return
        except pymssql.Error as exc:  # pragma: no cover - nur bei Verbindungsproblemen
            last_error = exc
            wait = min(2 ** attempt, 15)
            log.warning("DB-Verbindung fehlgeschlagen (Versuch %s): %s - warte %ss", attempt, exc, wait)
            time.sleep(wait)
    raise RuntimeError(f"Datenbank nicht erreichbar: {last_error}")


def init_db():
    """Legt die Tabelle an, falls sie noch nicht existiert (idempotent)."""
    ddl = """
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'items')
    CREATE TABLE items (
        id          INT IDENTITY(1,1) PRIMARY KEY,
        name        NVARCHAR(200) NOT NULL,
        quantity    INT NOT NULL DEFAULT 0,
        created_at  DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
    """
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute(ddl)
        conn.commit()
    log.info("Datenbankschema geprüft/angelegt.")


def fetch_items():
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute("SELECT id, name, quantity, created_at FROM items ORDER BY id DESC")
        return [serialize(row) for row in cur.fetchall()]


def fetch_item(item_id: int):
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute("SELECT id, name, quantity, created_at FROM items WHERE id = %s", (item_id,))
        row = cur.fetchone()
        return serialize(row) if row else None


def insert_item(name: str, quantity: int):
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO items (name, quantity) OUTPUT INSERTED.id VALUES (%s, %s)",
            (name, quantity),
        )
        new_id = cur.fetchone()["id"]
        conn.commit()
        return new_id


def update_item(item_id: int, name: str, quantity: int) -> bool:
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute("UPDATE items SET name = %s, quantity = %s WHERE id = %s", (name, quantity, item_id))
        conn.commit()
        return cur.rowcount > 0


def delete_item(item_id: int) -> bool:
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute("DELETE FROM items WHERE id = %s", (item_id,))
        conn.commit()
        return cur.rowcount > 0


def serialize(row: dict) -> dict:
    return {
        "id": row["id"],
        "name": row["name"],
        "quantity": row["quantity"],
        "created_at": row["created_at"].isoformat() if row.get("created_at") else None,
    }


# --------------------------------------------------------------------------- #
# Browser-Oberfläche (HTML)
# --------------------------------------------------------------------------- #
@app.route("/")
def index():
    items = fetch_items()
    return render_template("index.html", items=items, hostname=os.environ.get("HOSTNAME", "n/a"))


@app.route("/items", methods=["POST"])
def create_item_form():
    name = request.form.get("name", "").strip()
    quantity = request.form.get("quantity", "0").strip()
    if name and quantity.isdigit():
        insert_item(name, int(quantity))
    return redirect(url_for("index"))


@app.route("/items/<int:item_id>/delete", methods=["POST"])
def delete_item_form(item_id: int):
    delete_item(item_id)
    return redirect(url_for("index"))


# --------------------------------------------------------------------------- #
# Web-API (JSON)
# --------------------------------------------------------------------------- #
@app.route("/api/items", methods=["GET"])
def api_list():
    return jsonify(fetch_items())


@app.route("/api/items/<int:item_id>", methods=["GET"])
def api_get(item_id: int):
    item = fetch_item(item_id)
    if item is None:
        abort(404)
    return jsonify(item)


@app.route("/api/items", methods=["POST"])
def api_create():
    payload = request.get_json(silent=True) or {}
    name = str(payload.get("name", "")).strip()
    quantity = payload.get("quantity", 0)
    if not name or not isinstance(quantity, int):
        return jsonify({"error": "name (string) und quantity (int) sind erforderlich"}), 400
    new_id = insert_item(name, quantity)
    return jsonify(fetch_item(new_id)), 201


@app.route("/api/items/<int:item_id>", methods=["PUT"])
def api_update(item_id: int):
    payload = request.get_json(silent=True) or {}
    current = fetch_item(item_id)
    if current is None:
        abort(404)
    name = str(payload.get("name", current["name"])).strip()
    quantity = payload.get("quantity", current["quantity"])
    if not name or not isinstance(quantity, int):
        return jsonify({"error": "name (string) und quantity (int) sind erforderlich"}), 400
    update_item(item_id, name, quantity)
    return jsonify(fetch_item(item_id))


@app.route("/api/items/<int:item_id>", methods=["DELETE"])
def api_delete(item_id: int):
    if not delete_item(item_id):
        abort(404)
    return "", 204


# --------------------------------------------------------------------------- #
# Health-Endpunkte (für Container Apps Probes und Nachweis der Erreichbarkeit)
# --------------------------------------------------------------------------- #
@app.route("/health")
def health():
    """Liveness: Prozess läuft. Keine DB-Abhängigkeit, damit ein pausierter
    Serverless-SQL-Server nicht zu einem Container-Neustart führt."""
    return jsonify({"status": "ok", "replica": os.environ.get("HOSTNAME", "n/a")})


@app.route("/api/health")
def api_health():
    """Readiness-Variante inkl. Datenbank-Roundtrip."""
    try:
        with get_conn() as conn:
            cur = conn.cursor()
            cur.execute("SELECT 1 AS ok")
            cur.fetchone()
        return jsonify({"status": "ok", "database": "reachable"})
    except Exception as exc:  # noqa: BLE001
        return jsonify({"status": "degraded", "database": str(exc)}), 503


@app.errorhandler(404)
def not_found(_):
    if request.path.startswith("/api/"):
        return jsonify({"error": "not found"}), 404
    return "Nicht gefunden", 404


# Schema beim Start der Applikation sicherstellen (gunicorn: pro Worker einmal).
if DB_CONFIG["server"]:
    try:
        init_db()
    except Exception as exc:  # noqa: BLE001
        log.error("Schema-Initialisierung fehlgeschlagen, wird beim ersten Request erneut versucht: %s", exc)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8000")), debug=False)
