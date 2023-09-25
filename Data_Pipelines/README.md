# Overview of this section
To SetUp/ Orchestrate ETL Pipeline Job for User applications 

 Overall Here we have 2 components | 
|:----------------------------------|
| AWS Airflow                       |
| AWS Glue                          |

---
## Prerequistes

- AWS Account
- AWS MWAA (Managed Workflow for Apache Airflow)
- AWS S3 Bucket
-     For Input Files
      For Output Files
      For Archiving Input Data
      For Airflow Artefacts ( Dags , Config files etc.. )	
- IAM ROLE Setup
-     One For Airflow To Access s3 Dag Bucket and Also To Trigger AWS GLUE Job
      One for AWS Glue Job , which can access S3 Bucket ( Input, output and archive )
---	    
             		

## Code Base Structure 
```bash
├───airflow
│   ├───config_files
│   └───dags
├───glue
├───input
├───output
│   ├───successfull_application
│   │   └───23_09_2023_201926
│   └───unsuccessfull_application
│       └───23_09_2023_201926
└───screenshots
    ├───airflow
    ├───glue
    └───s3_bucket
```
---

##  ETL Flow ( Give a Diagram here )
![airflow_glue.drawio.png](..%2F..%2F..%2Fairflow_glue.drawio.png)

### ETL Steps Walkthrough
- Input CSV files are placed in s3 Input Bucket ( datasets and dropped into a folder on an hourly basis ).
- Airflow Dag will be Scheduled at every 30 min lets say
- Once Triggered It will Read Config Files to get all the configurations
- 
		{
           "s3_application_inp_loc": "s3://datalake-in-ecommerce-sg/test1/input/",
           "s3_success_application_out_loc": "s3://datalake-out-ecommerce-sg/output/successfull_application/",
           "s3_unsuccess_application_out_loc": "s3://datalake-out-ecommerce-sg/output/unsuccessfull_application/",
           "s3_archiving_loc": "s3://datalake-archive-ecommerce-sg/archive/",
           "glue_config" : {
                           "glue_job_name": "datalake-user-application-etl-job",
                           "glue_dpus": 5,
                           "glue_concurrent_run_limit" : 1
                           }
        } 
- Then it will trigger a AWS Glue job using GlueOperator
- Glue Job will read the Input files from input bucket and Perform ETL
-     1. This Glue job will be a Spark(PySpark) Job
      
      2. Following Input Dataset columns 
             --> name, email, date_of_birth, mobileno

      3. Some assumptions w.r.t to content in the dataset
             --> name : It can Include Salutations like (Mr. , Mrs., Dr.) OR it can contain designation like (DDS,Phd,....)
             --> date_of_birth : this can come in any format 
						
      4. It will Peform Following activity 
          4.1 Load the Input as Spark Dataframe and Begin processing in spark sql approach.
		  
          4.2 Clean the Dataset 
              --> Remove Leading and trailing spaces from each column
              --> name field : Remove Salutations and Designation 
              --> mobileno filed : Replace inbetween space
              --> date_of_birth : simplify column data to a unified date datatype
                                   (Here Python Dateutil Library has been used as UDF in Spark Job)						

          4.3 Derive Few Columns
              --> date_of_birth_derived : date_of_birth format YYYYMMDD
              --> First_name : first name of the name column value 
              --> Last_name : last name of the name column value 
              --> above_18 : boolean value with true or false

         4.4 Flag The Dataset into 2 category ( successful and unsuccessful ) by adding additional Column if any of the below is not true
              --> If any of the column is NULL or Space 
              --> length of mobileno column is 8
              --> Date Difference in Years Between '2022-01-01' and date_of_birth column is more than 18
              --> Email column has values with expression  XXXX@XXXX.com or XXXXX@XXXX.net

          4.5 Filter out Dataframe into 2 based on Flag which are marked either successful and unsuccessful 

          4.6 Derive Membership_id column of successful dataset with below logic
               --> <last_name>_<SHA256 hash value of date_of_birth>)
               --> truncated to first 5 digits of hash value 
						
		  4.7 Load Step
               --> Load Successful dataframe as CSV to output s3 bucket successful folder with additional folder which has date and timestamp value (i.e.. s3://<out_bucket>/successful/<YYYY_MM_DD_HHMMSS>/part-0000*-.csv)
               --> Load UnSuccessful dataframe as CSV to output s3 bucket unsuccessful folder with additional folder which has date and timestamp value (i.e.. s3://<out_bucket>/unsuccessful/<YYYY_MM_DD_HHMMSS>/part-0000*-.csv)
					
		  4.8 Archive Step 
               --> Move The Input files from s3 input bucket location to s3 archive location with additional folder which has date and timestamp value(i.e.. s3://<archive_bucket>/<YYYY_MM_DD_HHMMSS>/)
	
- Input and  Outfiles has been placed in the respective folders in this section.
- Logging is setup at Airflow Dag and AWS Glue level.
- ScreenShots at each level is supplied with the scripts
			
          	
