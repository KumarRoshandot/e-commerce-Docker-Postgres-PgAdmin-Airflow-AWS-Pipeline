"""
This is a Glue Spark job.

1. It perform ETL for the user application use case.
2. Tt recieve parameters from airflow job.
3. It Load the CSV files from s3 input location , clean & transform the data.
4. It Split the data into 2 , successful and unsuccessful category based on validation checks.
5. Load it onto s3 output locations as per the category.
6. once the ETL is successful , the job will archive the input data to archive s3 location.
"""
import sys
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext,SparkConf
from pyspark.sql.functions import regexp_replace,row_number,lit,current_date,udf
from pyspark.sql.types import StringType
from awsglue.context import GlueContext
from awsglue.job import Job
from datetime import datetime
import logging
import boto3
from dateutil import parser as dateutil_parser

date_time_now = datetime.now()
current_date_py = date_time_now.strftime('%d_%m_%Y')
current_datetime_py = date_time_now.strftime('%d_%m_%Y_%H%M%S')

MSG_FORMAT = '%(asctime)s %(levelname)s %(name)s: %(message)s'
DATETIME_FORMAT = '%Y-%m-%d %H:%M:%S'
logging.basicConfig(format=MSG_FORMAT, datefmt=DATETIME_FORMAT)
logger = logging.getLogger()
logger.setLevel(logging.INFO)

## @params: [JOB_NAME]
args = getResolvedOptions(sys.argv, ['JOB_NAME',
                                     's3_input',
                                     's3_successful_output',
                                     's3_unsuccessful_output',
                                     's3_archiving_loc'
                                     ])

conf = SparkConf().setAppName("USER_APPLICATION_ETL")\
                  .set("spark.sql.broadcastTimeout", "3600")\
                  .set("spark.sql.legacy.timeParserPolicy", "LEGACY")

# Initialise Glue and spark session
sc = SparkContext(conf=conf)
glueContext = GlueContext(assc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# For Date Format Handling , Taking the help of python dateutil and registering as UDF
dateutil_parser_udf = udf(lambda x: dateutil_parser.parse(x).strftime('%Y-%m-%d'), StringType())
spark.udf.register("dateutil_parser_udf", dateutil_parser_udf)

def extract(s3_path):
    """Extract the input data from a CSV File placed on s3 location

    :type s3_path: String
    :param s3_path: The S3 Path from which data has to be read

    :rtype: spark dataframe
    :returns: Input Data
    """
    try:
        input_df = spark.read.format('csv') \
            .option('sep', ',') \
            .option('header', 'true') \
            .option('multiline', 'true') \
            .option("escape", "\"") \
            .load(s3_path)
        return input_df
    except Exception as e:
        logger.info(f"Exception Occurred during Extract Step : {e}")
        raise Exception(str(e))
    finally:
        logger.info(f"---Extraction Step Completed : {s3_path}---")


def transform(df):
    """Perform Transformation on the data provided

    :type df: Spark Dataframe
    :param df: Data on which transformation is expected

    :rtype: spark dataframe
    :returns: Transformed Data
    """
    try:
        # ----------------- Clean Up Data
        # Remove Leading and trailing spaces from each column
        # name field : Remove Salutations and Designation
        # mobileno filed : Replace inbetween space
        # date_of_birth : simplify column data to a unified date datatype
        df.createOrReplaceTempView("USER_APPLICATIONS_TBL")
        sql = f'''            
        select
            trim(name) as name
            ,trim(email) as email
            ,trim(date_of_birth) as date_of_birth
            ,trim(regexp_replace(mobile_no,'\\\\s+','')) as mobile_no
            ,to_date(dateutil_parser_udf(trim(date_of_birth)),'yyyy-MM-dd') as date_of_birth_derived
            ,trim(regexp_replace(regexp_replace(trim(name), r'^(Mr[s]?|Dr)[\\\\.]',''), r' (MD|PhD|DDS|DVM)$','')) as name_derived
        from USER_APPLICATIONS_TBL
        '''
        logger.info(sql)
        df_main = spark.sql(sql)
        df_main.createOrReplaceTempView("USER_APPLICATIONS_TBL")

        # --------------- Derive columns
        # date_of_birth_derived : date_of_birth format YYYYMMDD
        # First_name : first name of the name column value
        # Last_name : last name of the name column value
        # above_18 : boolean value with true or false

        # -----------------Success/UnSuccess Flagging
        # If any of the column is NULL or Space
        # length of mobileno column is 8
        # Date Difference in Years Between '2022-01-01' and date_of_birth column is more than 18
        # Email column has values with expression  XXXX@XXXX.com or XXXXX@XXXX.net

        sql = '''
        select
            element_at(split(name_derived,'\\\\s+'),-2) as first_name,
            element_at(split(name_derived,'\\\\s+'),-1) as last_name,
            DATE_FORMAT(date_of_birth_derived,'yyyyMMdd') as birthday,
            mobile_no,
            email,
            case when round(months_between(to_date('2022-01-01','yyyy-MM-dd'),date_of_birth_derived)/12,2) <= 18.00 then false 
                 else true end as above_18,             
            case 
                 when (
                        nvl(name,'na') = 'na' or name = '' 
                      ) then 1
                 when ( 
                        nvl(mobile_no,'na') = 'na' or 
                        mobile_no = '' or
                        length(mobile_no) <> 8 
                        ) then 1 
                 when (
                       nvl(date_of_birth_derived,'na') = 'na' or 
                       date_of_birth_derived = '' or
                       round(months_between(to_date('2022-01-01','yyyy-MM-dd'),date_of_birth_derived)/12,2) <= 18.00 
                       ) then 1 
                 when (
                      nvl(email,'na') = 'na' or 
                      email = '' or
                      not rlike(email,'^(.*@.*[\\\\.com$|\\\\.net])$')  
                      ) then 1 

             else 0 end as application_flag
        from USER_APPLICATIONS_TBL
        '''
        logger.info(sql)
        df_main = spark.sql(sql)
        df_main.cache()

        # Filter Out UnSuccessful Application
        unsuccess_df = df_main.where("application_flag = 1").na.fill("").drop("application_flag")

        # Filter Out Successful Application
        success_df = df_main.where("application_flag = 0")
        success_df.createOrReplaceTempView("USER_APPLICATIONS_TBL")

        # ----------------------Prepare Dataset for Successful Application
        # Derive membership_id value truncated to first 5 digits of hash value in <last_name>_<SHA256 hash value of date_of_birth>)
        sql = '''
        select 
            first_name,
            last_name,
            birthday,
            mobile_no,
            email,
            above_18,
            last_name||'_'||substr(sha2(birthday,256),1,5) as membership_id
        from USER_APPLICATIONS_TBL
        '''
        logger.info(sql)
        success_df = spark.sql(sql)

        return unsuccess_df, success_df

    except Exception as e:
        logger.info(f"Exception Occurred during Transform Step: {e}")
        raise Exception(str(e))
    finally:
        logger.info(f"---Completed Step Transform---")


def load(df, s3_path):
    """Load the Data to s3 location as CSV files

    :type df: Spark Dataframe
    :param df: Data to be written on s3

    :type s3_path: String
    :param s3_path: s3 location where data will be written to

    :rtype: None
    :returns: None
    """
    try:
        df.coalesce(1).write \
            .option('sep', ',') \
            .option('header', 'true') \
            .option('multiline', 'true') \
            .option("escape", "\"")\
            .csv(s3_path)

    except Exception as e:
        logger.info(f"Exception Occurred during Load Step {s3_path}: {e}")
        raise Exception(str(e))
    finally:
        logger.info(f"---Step Load Completed : {s3_path}---")


def archive(s3_path,s3_archive_path):
    """Archive the Data from one location to another
       Taking the help of boto3 s3 client to perform COPY and DELETE Operation

    :type s3_archive_path: String
    :param s3_archive_path: The TO location on which data to be moved

    :type s3_path: String
    :param s3_path: The FROM location from which data will be moved

    :rtype: None
    :returns: None
    """
    try:
        import boto3
        s3_client = boto3.client('s3')

        s3_input_bucket = s3_path.split('/')[2]
        s3_input_folder = "/".join(s3_path.split('/')[3:])
        s3_archive_bucket = s3_archive_path.split('/')[2]
        s3_archive_folder = "/".join(s3_archive_path.split('/')[3:])

        s3_client.put_object(Bucket=s3_input_bucket, Key=s3_input_folder + '_SUCCESS', Body='')

        response = s3_client.list_objects_v2(Bucket=s3_input_bucket,Prefix=s3_input_folder)
        for content in response.get('Contents', []):
            print(content)
            source_key = content['Key']
            if not str(source_key).endswith('.csv'):
                continue
            file_name = source_key.split('/')[-1]
            copy_source = {'Bucket': s3_input_bucket, 'Key': source_key}

            s3_client.copy_object(Bucket=s3_archive_bucket,
                                  CopySource=copy_source, Key=s3_archive_folder + file_name)

            s3_client.delete_object(Bucket=s3_input_bucket, Key=source_key)

    except Exception as e:
        logger.info(f"Exception Occurred during Archive Step : {e}")
        raise Exception(str(e))
    finally:
        logger.info(f"---Completed Step Archive {s3_path} , {s3_archive_path}---")


def main():
    try:
        main_start = datetime.now()

        # Perform ETL
        unsuccessful_df, success_df = transform(extract(args['s3_input']))

        # If there are any successful record to be written
        if len(success_df.head(1)) != 0:
            load(success_df, args['s3_successful_output'] + current_datetime_py + '/')

        # If there are any unsuccessful records to be written
        if len(unsuccessful_df.head(1)) != 0:
            load(unsuccessful_df, args['s3_unsuccessful_output'] + current_datetime_py + '/')

        # IF there are no records both in successful and unsuccessful dataframe , then there is some issue with processing
        elif len(success_df.head(1)) == 0:
            msg = "Issue in Deriving Successful and Unsuccessful User Applications, Both doesnt have Records to Save"
            logger.info(msg)
            raise Exception(msg)

        # Archive Input Data, Only When the ETL is successful
        s3_archive_path = args['s3_archiving_loc'] + current_datetime_py +'/'
        archive(args['s3_input'],s3_archive_path)

        print(f'\nOverall Time taken For the Job is :- ', datetime.now() - main_start)

    except Exception as e:
        logger.info(f"Exception Occurred : {e}")
        raise e
    finally:
        logger.info("--- Job Completed ---")


if __name__ == "__main__":
    main()
