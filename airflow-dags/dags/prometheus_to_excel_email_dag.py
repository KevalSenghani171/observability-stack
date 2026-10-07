"""
Airflow DAG: Prometheus (hourly MAX / MIN / AVG of CPU & Memory) -> Excel -> Email (attachment only)

Output columns:
  Time | server_ip | Max CPU% | Max Memory % | Min CPU% | Min Memory % | Avg CPU% | Avg Memory %

Params (all optional):
  prometheus_url, job_regex, start, end, step, window, subquery_step,
  label_window_start, ip_label, timezone, verify_ssl, output_dir,
  email_to, email_subject, email_conn_id

Requires: requests, pandas, openpyxl. Airflow 2.4+ / 3.x.
"""
from __future__ import annotations

import logging
import os
import re
from datetime import timedelta
from functools import reduce

import pandas as pd
import pendulum
import requests

try:  # Airflow 3
    from airflow.sdk import Param, dag, task
except ImportError:  # Airflow 2.x
    from airflow.decorators import dag, task
    from airflow.models.param import Param
from airflow.providers.smtp.hooks.smtp import SmtpHook

log = logging.getLogger(__name__)

# Base expressions (0-100 %). {job} is replaced by the job_regex param.
CPU_BASE = (
    '100 * (1 - avg by (instance) '
    '(rate(node_cpu_seconds_total{{mode="idle",job=~"{job}"}}[2m])))'
)
MEM_BASE = (
    '100 * (1 - (node_memory_MemAvailable_bytes{{job=~"{job}"}} '
    '/ node_memory_MemTotal_bytes{{job=~"{job}"}}))'
)

# (output column, base expression, aggregation function) -- order = Excel column order
COLUMNS = [
    ("Max CPU%",     CPU_BASE, "max"),
    ("Max Memory %", MEM_BASE, "max"),
    ("Min CPU%",     CPU_BASE, "min"),
    ("Min Memory %", MEM_BASE, "min"),
    ("Avg CPU%",     CPU_BASE, "avg"),
    ("Avg Memory %", MEM_BASE, "avg"),
]


def _to_seconds(s: str) -> int:
    m = re.fullmatch(r"(\d+)([smhd])", s.strip())
    if not m:
        raise ValueError(f"Invalid duration: {s!r} (use e.g. 1h, 5m)")
    return int(m.group(1)) * {"s": 1, "m": 60, "h": 3600, "d": 86400}[m.group(2)]


def _extract_ip(metric: dict, label: str) -> str:
    value = metric.get(label) or metric.get("instance") or metric.get("ip") or "unknown"
    return re.sub(r":\d+$", "", value)  # strip :port


def _query_range(base_url, query, start_ts, end_ts, step, label, value_col, verify, timeout):
    resp = requests.get(
        f"{base_url.rstrip('/')}/api/v1/query_range",
        params={"query": query, "start": start_ts, "end": end_ts, "step": step},
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
    log.info("%s -> %d rows", value_col, len(df))
    return df


@dag(
    dag_id="prometheus_to_excel_email_report",
    description="Prometheus hourly max/min/avg CPU & Memory -> Excel -> email attachment",
    schedule=None,  # e.g. "0 8 * * *" for a daily 08:00 report
    start_date=pendulum.datetime(2026, 1, 1, tz="Asia/Kolkata"),
    catchup=False,
    tags=["prometheus", "report", "excel", "email"],
    default_args={"retries": 1, "retry_delay": timedelta(minutes=2)},
    params={
        "prometheus_url": Param("https://prometheus-keval.duckdns.org/", type="string"),
        "job_regex": Param(".+", type="string", description="Replaces $job, e.g. node|linux"),
        "start": Param("", type="string", description="ISO datetime; blank = data interval start"),
        "end": Param("", type="string", description="ISO datetime; blank = data interval end"),
        "step": Param("1h", type="string", description="One row per server per step"),
        "window": Param("1h", type="string", description="Subquery range, the [1h:1m] part"),
        "subquery_step": Param("1m", type="string", description="Subquery resolution"),
        "label_window_start": Param(
            True, type="boolean",
            description="True: row 0:00 = stats for 0:00-1:00. False: row 1:00 = stats for 0:00-1:00",
        ),
        "ip_label": Param("instance", type="string"),
        "timezone": Param("Asia/Kolkata", type="string"),
        "verify_ssl": Param(True, type="boolean"),
        "output_dir": Param("/opt/airflow/reports", type="string"),
        "email_to": Param("senghanikeval@gmail.com", type="string", description="Comma separated"),
        "email_subject": Param("Prometheus CPU & Memory hourly report", type="string"),
        "email_conn_id": Param("smtp_default", type="string"),
    },
    render_template_as_native_obj=True,
)
def prometheus_to_excel_email_report():

    @task
    def fetch_metrics(**context) -> list[dict]:
        p = context["params"]
        tz = pendulum.timezone(p["timezone"])

        # A blank/whitespace value in the trigger form counts as "not set"
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

        step_s = _to_seconds(p["step"])
        window_s = _to_seconds(p["window"])

        # Align to the hour so rows land on 0:00, 1:00, 2:00 ...
        start = start.start_of("hour") if step_s >= 3600 else start.start_of("minute")

        # Prometheus returns, at time T, the stats for (T - window, T].
        # label_window_start=True  -> row 0:00 = stats for 0:00-1:00
        #   (query one window later, then shift the labels back in Python)
        # label_window_start=False -> row 1:00 = stats for 0:00-1:00 (raw Prometheus)
        shift = window_s if p["label_window_start"] else 0
        q_start = start.int_timestamp + shift
        q_end = end.int_timestamp
        log.info("Querying %s -> %s (step %s)", start, end, p["step"])

        frames = []
        for col, base, fn in COLUMNS:
            expr = base.format(job=p["job_regex"])
            query = f'{fn}_over_time(({expr})[{p["window"]}:{p["subquery_step"]}])'
            log.info("%s query: %s", col, query)
            frames.append(
                _query_range(
                    p["prometheus_url"], query, q_start, q_end, p["step"],
                    p["ip_label"], col, p["verify_ssl"], 120,
                )
            )

        df = reduce(lambda a, b: pd.merge(a, b, on=["ts", "server_ip"], how="outer"), frames)
        if df.empty:
            raise ValueError("Prometheus returned no data for the given queries/time range")

        df["ts"] = df["ts"] - shift
        df["Time"] = (
            pd.to_datetime(df["ts"], unit="s", utc=True)
            .dt.tz_convert(p["timezone"])
            .dt.tz_localize(None)
        )
        df = df.sort_values(["Time", "server_ip"]).reset_index(drop=True)
        df = df[["Time", "server_ip"] + [c[0] for c in COLUMNS]]

        log.info("Result:\n%s", df.round(1).to_string(index=False))

        out = df.copy()
        out["Time"] = out["Time"].dt.strftime("%Y-%m-%dT%H:%M:%S")
        return out.where(out.notna(), None).to_dict(orient="records")

    @task
    def export_to_excel(records: list[dict], **context) -> str:
        from openpyxl.styles import Alignment, Font, PatternFill

        p = context["params"]
        df = pd.DataFrame(records)
        df["Time"] = pd.to_datetime(df["Time"])
        value_cols = [c[0] for c in COLUMNS]
        df[value_cols] = df[value_cols] / 100.0  # store as ratio, display as %

        os.makedirs(p["output_dir"], exist_ok=True)
        stamp = pendulum.now(p["timezone"]).format("YYYYMMDD_HHmmss")
        path = os.path.join(p["output_dir"], f"prometheus_report_{stamp}.xlsx")

        with pd.ExcelWriter(path, engine="openpyxl") as writer:
            df.to_excel(writer, sheet_name="Report", index=False)
            ws = writer.sheets["Report"]

            for cell in ws[1]:
                cell.font = Font(bold=True, color="FFFFFF")
                cell.fill = PatternFill("solid", fgColor="1F4E78")
                cell.alignment = Alignment(horizontal="center", wrap_text=True)
            for row in range(2, ws.max_row + 1):
                ws.cell(row, 1).number_format = "dd/mm/yyyy h:mm:ss"  # 06/10/2026 0:00:00
                for col in range(3, 3 + len(value_cols)):
                    ws.cell(row, col).number_format = "0%"            # 56%
            ws.column_dimensions["A"].width = 22
            ws.column_dimensions["B"].width = 16
            for col in "CDEFGH":
                ws.column_dimensions[col].width = 14
            ws.freeze_panes = "A2"
            ws.auto_filter.ref = ws.dimensions

        log.info("Excel written to %s (%d rows)", path, len(df))
        return path

    @task
    def send_email_report(excel_path: str, **context) -> None:
        p = context["params"]
        recipients = [e.strip() for e in p["email_to"].split(",") if e.strip()]
        with SmtpHook(smtp_conn_id=p["email_conn_id"]) as smtp:
            smtp.send_email_smtp(
                to=recipients,
                subject=p["email_subject"],
                html_content="",  # no body, attachment only
                files=[excel_path],
            )
        log.info("Email sent to %s with attachment %s", recipients, excel_path)

    data = fetch_metrics()
    xlsx = export_to_excel(data)
    send_email_report(xlsx)


prometheus_to_excel_email_report()