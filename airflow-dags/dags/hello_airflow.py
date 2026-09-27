from datetime import datetime

from airflow.sdk import DAG, task


with DAG(
    dag_id="test_dag",
    start_date=datetime(2026, 9, 27),
    schedule=None,
    catchup=False,
) as dag:

    @task
    def test():
        print("Hello! Airflow DAG is working.")

    test()