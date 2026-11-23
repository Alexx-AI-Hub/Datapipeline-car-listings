from airflow.providers.standard.operators.trigger_dagrun import TriggerDagRunOperator  # type: ignore
from airflow.sdk import dag, get_current_context, task  # type: ignore
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
        """Fetch listings in a 24-hour window and return the path to the stored gzip JSONL file.

        Scheduled runs use data_interval_end as the window end, including catchup
        runs. Manual runs use the current time. The filename uses the window end
        date in Europe/Stockholm.
        """

        context = get_current_context()

        import sys
        sys.path.insert(0, "/opt/airflow/project/src")

        end_time = (
            # Use scheduled time even if execution is delayed.
            # For manual runs, None makes ingestion use the current time.
            context["data_interval_end"] 
            if context["dag_run"].run_type == "scheduled" else None
        )
        from run_ingestion import run
        return str(run(end=end_time))

    @task.short_circuit()
    def should_trigger_dbt() -> bool:
        return get_current_context()["dag_run"].run_type == "scheduled"

    trigger_dbt = TriggerDagRunOperator(
        task_id="trigger_dbt",
        trigger_dag_id="blocket_dbt_dag", # Must match dag_id!
        conf={"batch_date": "{{ ds }}"},
        wait_for_completion=False
    )
    fetch_listed_cars() >> should_trigger_dbt() >> trigger_dbt

blocket_daily_dag()
