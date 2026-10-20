"""Fetch and save a daily batch independently of the dbt DAG."""

from airflow.sdk import dag, task  # type: ignore
from pendulum import datetime  # type: ignore


@dag(
    dag_id="blocket_daily_dag",
    start_date=datetime(2026, 10, 13, tz="Europe/Stockholm"),
    schedule="0 15 * * *",  # Daily at 15:00      -->  * * * * * => Min, Hour, Day, Month, Day of Week
    catchup=True,           # Catch up for missed runs
    max_active_runs=1,
    tags=["blocket", "scraping"],
)
def blocket_daily_dag():
    """Fetch listings at scheduled time in Europe/Stockholm without triggering dbt."""

    @task
    def fetch_listed_cars() -> str:
        """Fetch listings in a 24-hour window and save a daily JSONL gzip file.

        Scheduled runs use [data_interval_end] as the window end, preserving the
        intended window for delayed and catchup runs. Manual runs use the current
        time. Name the file using the window end date in Europe/Stockholm and
        return its path as a string. Propagate fetching and saving failures.
        """
        import sys

        from airflow.sdk import get_current_context  # type: ignore
        context = get_current_context()

        sys.path.insert(0, "/opt/airflow/project/src")
        from run_ingestion import run

        end_time = (
            # Use scheduled time even if execution is delayed.
            # For manual runs, None makes ingestion use the current time.
            context["data_interval_end"]
            if context["dag_run"].run_type == "scheduled"
            else None
        )
        return str(run(end=end_time))

    fetch_listed_cars()


blocket_daily_dag()
