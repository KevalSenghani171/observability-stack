"""
Airflow DAG: Prometheus query -> table -> Excel -> email (attachment only, no body)

Trigger with config / params (all optional, defaults provided):
  prometheus_url : Prometheus base URL
  cpu_query      : PromQL returning CPU    (ratio 0-1, one series per server)
  memory_query   : PromQL returning Memory (ratio 0-1, one series per server)
  start / end    : ISO datetime. Blank = DAG run's data interval
  step           : query_range step, e.g. 1h, 5m
  ip_label       : metric label that holds the server IP
  timezone       : timezone used for the "Time" column
  output_dir     : where the .xlsx is written
  email_to       : comma separated recipients
  email_subject  : subject line
  email_conn_id  : Airflow SMTP connection id (default smtp_default)

Excel columns (always in this order):  Time | server_ip | CPU% | Memory %

Requires: requests, pandas, openpyxl. Airflow 2.4+ / 3.x (TaskFlow API).
"""
from __future__ import annotations

import logging
import os
import re
from datetime import timedelta

import pandas as pd
import pendulum
import requests

try:  # Airflow 3
    from airflow.sdk import Param, dag, task
except ImportError:  # Airflow 2.x
    from airflow.decorators import dag, task
    from airflow.models.param import Param
from airflow.providers.smtp.hooks.smtp import SmtpHook

log =logging.getLogger(__name__)

# Final column order of the table / Excel sheet. Everything below uses these
# NAMES (never column positions), so the layout can't get mixed up.
COLUMNS = ["Time", "server_ip", "CPU%", "Memory %"]

# Default PromQL (node_exporter). Replace from the Trigger UI as needed.
DEFAULT_CPU_QUERY = (
    '1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m]))'
)
DEFAULT_MEM_QUERY = (
    "1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)"
)


def _extract_ip(metric: dict, label: str) -> str:
    value = metric.get(label) or metric.get("instance") or metric.get("ip") or "unknown"
    return re.sub(r":\d+$", "", value)  # strip :port


def _query_range(base_url, query, start, end, step, label, value_col, verify, timeout):
    resp = requests.get(
        f"{base_url.rstrip('/')}/api/v1/query_range",
        params={"query": query, "start": start.timestamp(), "end": end.timestamp(), "step": step},
        timeout=timeout,
        verify=verify,
    )
    resp.raise_for_status()
    body = resp.json()
    if body.get("status") != "success":
        raise ValueError(f"Prometheus error: {body}")

    rows = []
    for series in body["data"]["result"]:
        ip = _extract_ip(series["metric"], label)
        for ts, val in series["values"]:
            rows.append({"ts": int(float(ts)), "server_ip": ip, value_col: float(val)})
    df = pd.DataFrame(rows, columns=["ts", "server_ip", value_col])
    log.info("Query returned %d rows for %s", len(df), value_col)
    return df


def _write_excel(df: pd.DataFrame, path: str) -> None:
    """Write the report. Column order and cell formats are set by column NAME."""
    df = df[COLUMNS].copy()  # force order: Time | server_ip | CPU% | Memory %
    df["Time"] = pd.to_datetime(df["Time"])

    formats = {
        "Time": "dd/mm/yyyy h:mm:ss",
        "CPU%": "0%",
        "Memory %": "0%",
    }
    widths = {"Time": 22, "server_ip": 18, "CPU%": 10, "Memory %": 12}

    with pd.ExcelWriter(path, engine="openpyxl") as writer:
        df.to_excel(writer, sheet_name="Report", index=False)
        ws = writer.sheets["Report"]

        from openpyxl.styles import Alignment, Font, PatternFill
        from openpyxl.utils import get_column_letter

        for cell in ws[1]:
            cell.font = Font(bold=True, color="FFFFFF")
            cell.fill = PatternFill("solid", fgColor="1F4E78")
            cell.alignment = Alignment(horizontal="center")

        for idx, name in enumerate(COLUMNS, start=1):
            letter = get_column_letter(idx)
            ws.column_dimensions[letter].width = widths[name]
            if name in formats:
                for row in range(2, ws.max_row + 1):
                    ws.cell(row, idx).number_format = formats[name]

        ws.freeze_panes = "A2"
        ws.auto_filter.ref = ws.dimensions


@dag(
    dag_id="prometheus_to_excel_report",
    description="Prometheus -> Time/server_ip/CPU%/Memory% table -> Excel",
    schedule=None,  # e.g. "0 8 * * *" for a daily 08:00 report
    start_date=pendulum.datetime(2026, 1, 1, tz="Asia/Kolkata"),
    catchup=False,
    tags=["prometheus", "report", "excel"],
    default_args={"retries": 1, "retry_delay": timedelta(minutes=2)},
    params={
        "prometheus_url": Param("https://prometheus-keval.duckdns.org", type="string"),
        "cpu_query": Param(DEFAULT_CPU_QUERY, type="string"),
        "memory_query": Param(DEFAULT_MEM_QUERY, type="string"),
        "start": Param("", type="string", description="ISO datetime; blank = data interval start"),
        "end": Param("", type="string", description="ISO datetime; blank = data interval end"),
        "step": Param("1h", type="string"),
        "ip_label": Param("instance", type="string"),
        "timezone": Param("Asia/Kolkata", type="string"),
        "verify_ssl": Param(True, type="boolean"),
        "output_dir": Param("/opt/airflow/reports", type="string"),
        "email_to": Param("senghanikeval@gmail.com", type="string", description="Comma separated"),
        "email_subject": Param("Prometheus CPU & Memory report", type="string"),
        "email_conn_id": Param("smtp_default", type="string"),
    },
    render_template_as_native_obj=True,
)
def prometheus_to_excel_report():

    @task
    def fetch_metrics(**context) -> list[dict]:
        p = context["params"]
        tz = pendulum.timezone(p["timezone"])

        # A blank/whitespace value in the trigger form (e.g. " ") counts as "not set"
        start_s = str(p.get("start") or "").strip()
        end_s = str(p.get("end") or "").strip()

        if start_s and end_s:
            start, end = pendulum.parse(start_s, tz=tz), pendulum.parse(end_s, tz=tz)
        else:
            d_start = context.get("data_interval_start")
            d_end = context.get("data_interval_end")
            if d_start and d_end and d_end > d_start:
                start, end = d_start.in_timezone(tz), d_end.in_timezone(tz)
            else:  # manual trigger / no interval -> previous full day
                today = pendulum.now(tz).start_of("day")
                start, end = today.subtract(days=1), today
        log.info("Querying Prometheus from %s to %s", start, end)

        common = dict(
            base_url=p["prometheus_url"], start=start, end=end, step=p["step"],
            label=p["ip_label"], verify=p["verify_ssl"], timeout=60,
        )
        cpu = _query_range(query=p["cpu_query"], value_col="CPU%", **common)
        mem = _query_range(query=p["memory_query"], value_col="Memory %", **common)

        df = pd.merge(cpu, mem, on=["ts", "server_ip"], how="outer")
        if df.empty:
            raise ValueError("Prometheus returned no data for the given queries/time range")

        df["Time"] = (
            pd.to_datetime(df["ts"], unit="s", utc=True)
            .dt.tz_convert(p["timezone"])
            .dt.tz_localize(None)
        )
        df = df.sort_values(["Time", "server_ip"]).reset_index(drop=True)
        df = df[COLUMNS]

        # Show the table in the task log
        printable = df.copy()
        printable["Time"] = printable["Time"].apply(lambda t: f"{t:%d/%m/%Y} {t.hour}:{t:%M:%S}")
        for c in ("CPU%", "Memory %"):
            printable[c] = printable[c].map(lambda v: "" if pd.isna(v) else f"{v:.0%}")
        log.info("Result table:\n%s", printable.to_string(index=False))

        # XCom-safe (JSON) payload
        out = df.copy()
        out["Time"] = out["Time"].dt.strftime("%Y-%m-%dT%H:%M:%S")
        return out.where(out.notna(), None).to_dict(orient="records")

    @task
    def export_to_excel(records: list[dict], **context) -> str:
        p = context["params"]
        # XCom does not keep key order, so the order is set again in _write_excel
        df = pd.DataFrame(records)

        os.makedirs(p["output_dir"], exist_ok=True)
        stamp = pendulum.now(p["timezone"]).format("YYYYMMDD_HHmmss")
        path = os.path.join(p["output_dir"], f"prometheus_report_{stamp}.xlsx")

        _write_excel(df, path)
        log.info("Excel report written to %s (%d rows)", path, len(df))
        return path

    export_to_excel(fetch_metrics())


prometheus_to_excel_report()
