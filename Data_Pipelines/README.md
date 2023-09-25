1. Overview of this section

To SetUp/ Orchestrate ETL Pipeline Job for User applications 

Overall Here we have 2 components 
       1. Airflow JOb 
	   2. AWS Glue Job
	   
	   

	1. Prerequistes 
	    a. AWS Account
		b. AWS MWAA (Managed Workflow for Apache Airflow)
		c. AWS S3 Bucket
		   c.1 For Input Files
		   c.2 For Output Files
		   c.3 For Archiving Input Data
		   c.4 For Airflow Artefacts ( Dags , Config files etc.. )
		   		   		   
		d. IAM ROLE Setup
            d.1 One For Airflow To Access s3 Dag Bucket and Also To Trigger AWS GLUE Job
			d.2 One for AWS Glue Job , which can access S3 Bucket ( Input, output and archive )
             		

	2. Code Base Structure 
	    
    3. ETL Flow ( Give a Diagram here )
	    a. Input CSV files are placed in s3 Input Bucket ( datasets and dropped into a folder on an hourly basis ).
		b. Airflow Dag will be Scheduled at every 30 min lets say
			b.1 Once Triggered It will Read Config Files to get all the configurations 
			     --> Show config 
			b.2 Then it will trigger a AWS Glue job using GlueOperator
        c. Glue Job will read the Input files from input bucket and Perform ETL 
		    
			c.1 This Glue job will be a Spark(PySpark) Job
            
			c.2 Following Input Dataset columns 
			            --> name, email, date_of_birth, mobileno
			
			c.3 Some assumptions w.r.t to content in the dataset
                        --> name : It can Include Salutations like (Mr. , Mrs., Dr.) OR it can contain designation like (DDS,Phd,....)
						--> date_of_birth : this can come in any format 
						
			c.3 It will Peform Following activity 
                
				c.3.1 Load the Input as Spark Dataframe and Begin processing in spark sql approach.
				
				c.3.2 Clean the Dataset 
                        --> Remove Leading and trailing spaces from each column
                        --> name field : Remove Salutations and Designation 
						--> mobileno filed : Replace inbetween space
					    --> date_of_birth : simplify column data to a unified date datatype
                                          : Here Python Dateutil Library has been used as UDF in Spark Job						
				
				c.3.3 Derive Few Columns
						--> date_of_birth_derived : date_of_birth format YYYYMMDD
						--> First_name : first name of the name column value 
						--> Last_name : last name of the name column value 
						--> above_18 : boolean value with true or false
				
				c.3.3 Flag The Dataset into 2 category ( successful and unsuccessful ) by adding additional Column if any of the below is not true
				        --> If any of the column is NULL or Space 
						--> length of mobileno column is 8
						--> Date Difference in Years Between '2022-01-01' and date_of_birth column is more than 18
						--> Email column has values with expression  XXXX@XXXX.com or XXXXX@XXXX.net
						
				c.3.4 Filter out Dataframe into 2 based on Flag which are marked either successful and unsuccessful 
				c.3.5 Derive Membership_id column of successful dataset with below logic
                        --> <last_name>_<SHA256 hash value of date_of_birth>)
						--> truncated to first 5 digits of hash value 
						
				c.3.6 Load Step
				        --> Load Successful dataframe as CSV to output s3 bucket successful folder with additional folder which has date and timestamp value (i.e.. s3://<out_bucket>/successful/<YYYY_MM_DD_HHMMSS>/part-0000*-.csv)
						--> Load UnSuccessful dataframe as CSV to output s3 bucket unsuccessful folder with additional folder which has date and timestamp value (i.e.. s3://<out_bucket>/unsuccessful/<YYYY_MM_DD_HHMMSS>/part-0000*-.csv)
					
				c.3.7 Archive Step 
                        --> Move The Input files from s3 input bucket location to s3 archive location with additional folder which has date and timestamp value(i.e.. s3://<archive_bucket>/<YYYY_MM_DD_HHMMSS>/)

			d. Logging is setup at Airflow Dag and AWS Glue level.
	
	4.  Input and  Outfiles has been placed in the respective folders in this section.
			
			
          	
