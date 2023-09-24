import json
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.dummy_operator import DummyOperator
from airflow.providers.amazon.aws.operators.glue import GlueJobOperator
from airflow.models import Variable
import boto3
import logging

args = {
    'owner': 'kumar',
     'tags': ['e-commerce','users_applications','membership','etl'],
     'retries': 2,
     'retry_delay': timedelta(seconds=15),
     'retry_exponential_backoff': True,
     'max_retry_delay': timedelta(minutes=1),
}


def get_config():
    try:
        s3_client = boto3.client('s3')
        bucket_name = Variable.get("config_s3_bucket")
        object_key = Variable.get("etl_config_step1")
        response = s3_client.get_object(Bucket=bucket_name, Key=object_key)
        file_content = response['Body'].read().decode('utf-8')
        return json.loads(file_content)
    except Exception as e:
        msg = f"Exception Occurred in Config Read Step :- {str(e)}"
        logging.info(msg)
        raise Exception(msg)


with DAG(
    dag_id="datalake_user_applications_etl_dag_step1",
    description="Execute User Applications ETL Glue Job",
    start_date=datetime(2023, 1, 1),
    schedule_interval=None,
    catchup=False,
    default_args=args,
    tags=args['tags']
) as dag:

    start = DummyOperator(task_id="start")

    end = DummyOperator(task_id="end")

    config = get_config()

    datalake_user_application_etl_job = GlueJobOperator(
        task_id="datalake_user_application_etl_job",
        job_name=config['glue_config']['glue_job_name'],
        job_desc=f"AWS Glue Job with Airflow. Triggering glue job {config['glue_config']['glue_job_name']}",
        num_of_dpus=config['glue_config']['glue_dpus'],
        concurrent_run_limit=config['glue_config']['glue_concurrent_run_limit'],
        script_args={'--s3_input': config['s3_application_inp_loc'],
                     '--s3_successful_output': config['s3_success_application_out_loc'],
                     '--s3_unsuccessful_output': config['s3_unsuccess_application_out_loc'],
                     '--s3_archiving_loc': config['s3_archiving_loc']
                     }
    )

    start >> datalake_user_application_etl_job >> end