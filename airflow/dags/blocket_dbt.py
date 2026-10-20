
from airflow.sdk import Param, dag, task  # type: ignore
from pendulum import datetime  # type: ignore


@dag(
    dag_id="blocket_dbt_dag",
    start_date=datetime(2026, 10, 13, tz="Europe/Stockholm"),
    schedule="0 16 * * *",
    catchup=True,
    max_active_runs=1,
    params={
        "batch_date": Param(None, type=["null", "string"]),
        "batch_window_end": Param(None, type=["null", "string"]),
    },
    tags=["blocket", "dbt"],
)
def blocket_dbt_dag():
    @task
    def run_dbt_pipeline() -> None:
        """Runs the daily dbt-pipeline for the selected or scheduled batch.

        Read batch_date from run configuration or DAG parameters. If omitted,
        scheduled runs use the interval end date in Europe/Stockholm, including
        delayed runs. Manual runs require an explicit date in YYYY-MM-DD format.
        Raise ValueError if no date is available and propagate dbt failures.
        """
        import json
        import subprocess

        from airflow.sdk import get_current_context  # type: ignore

        context = get_current_context()
        conf = context["dag_run"].conf or {}
        batch_date = conf.get("batch_date") or context["params"].get("batch_date")

        if not batch_date and context["dag_run"].run_type == "scheduled": # Scheduled run without batch_date uses scheduled date.
            batch_date = (
                context["data_interval_end"]
                .in_timezone("Europe/Stockholm")
                .strftime("%Y-%m-%d")
            )
        if not batch_date:                                                # Manual run without batch_date is not allowed.
            raise ValueError("Must set batch_date to YYYY-MM-DD for a manual run.")

        dbt_vars = {"batch_date": batch_date}
        # Manual ingestion may end at a different time than the 15:00 schedule.
        window_end = conf.get("batch_window_end") or context["params"].get("batch_window_end")
        if window_end:
            dbt_vars["batch_window_end"] = window_end

        subprocess.run(
            [
                "dbt", "--no-send-anonymous-usage-stats", "build",
                "--profiles-dir", ".",
                "--vars", json.dumps(dbt_vars),
            ],
            cwd="/opt/airflow/project/dbt/blocket_cars_pipeline",
            check=True,
        )

    run_dbt_pipeline()  # Run task

blocket_dbt_dag()   # Run whole DAG
