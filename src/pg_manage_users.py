import boto3
import json
import logging
import os
import psycopg2
import base64
from botocore.exceptions import ClientError


logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    logger.info("Starting Lambda Handler")
    master_secret_arn = os.environ['MASTER_SECRET_NAME']
    user_secret_arn   = event['UserSecretName']  
    step       = event['Step']

    logger.info("Connecting to Secret Manager...")
    # Setup the client
    service_client = boto3.client('secretsmanager', endpoint_url=os.environ['SECRETS_MANAGER_ENDPOINT'])
    
    #Get sec
    master_secret = get_secret_dict(service_client, master_secret_arn)
    user_secret = get_secret_dict(service_client, user_secret_arn)
    
    logger.info( master_secret )
    logger.info( user_secret )
    
    #Get Master User DB connection
    conn = get_connection(master_secret)
    
    # Call the appropriate step
    if step == "CreateUser":
        create_user(conn, user_secret)
    elif step == "DropUser":
        drop_user(conn, user_secret)
    else:
        logger.error("lambda_handler: Invalid step parameter %s for secret %s" % (step, arn))
        raise ValueError("Invalid step parameter %s for secret %s" % (step, arn))
    return {"body" : "Success", "statusCode" : 200 }

def create_user(conn, user_secret):
    username = user_secret['username']
    password = user_secret['password']
    dbname   = user_secret['dbname']
    try:
        with conn.cursor() as cur:
            create_user = "CREATE USER "+ username +" WITH PASSWORD '" + password +"'"
            logger.info("CreateUser: Started creating user %s in PostgreSQL DB %s." % (username,dbname))
            cur.execute(create_user)
            conn.commit()
    finally:
        conn.close()
    logger.info("CreateUser: Successfully created user %s in PostgreSQL DB %s." % (username,dbname))


def drop_user(conn, user_secret):
    username = user_secret['username']
    dbname   = user_secret['dbname']
    try:
        with conn.cursor() as cur:
            drop_user = "DROP USER IF EXISTS " + username
            logger.info("DropUser: Started dropping user %s in PostgreSQL DB %s." % (username,dbname))
            cur.execute(drop_user)
            conn.commit()
    finally:
        conn.close()
    logger.info("DropUser: Successfully droppped user %s in PostgreSQL DB %s." % (username,dbname))


def get_connection(secret_dict):
    port = int(secret_dict['port']) if 'port' in secret_dict else 5432
    dbname = secret_dict['dbname'] if 'dbname' in secret_dict else "postgres"

    # Try to obtain a connection to the db
    try:
        conn = psycopg2.connect(
            host=secret_dict['host'],
            user=secret_dict['username'],
            password=secret_dict['password'],
            database=dbname,
            port=port,
            connect_timeout=5,
        )
        return conn
    except psycopg2.Error as e:
        logger.exception("Unable to open database connection")
        raise e
    except:
        raise Error("Unknown error opening database connection")


def get_secret_dict(service_client, arn):
    try:
        get_secret_value_response = service_client.get_secret_value(
            SecretId=arn
        )
    except ClientError as e:
        if e.response['Error']['Code'] == 'DecryptionFailureException':
            # Secrets Manager can't decrypt the protected secret text using the provided KMS key.
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
        elif e.response['Error']['Code'] == 'InternalServiceErrorException':
            # An error occurred on the server side.
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
        elif e.response['Error']['Code'] == 'InvalidParameterException':
            # You provided an invalid value for a parameter.
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
        elif e.response['Error']['Code'] == 'InvalidRequestException':
            # You provided a parameter value that is not valid for the current state of the resource.
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
        elif e.response['Error']['Code'] == 'ResourceNotFoundException':
            # We can't find the resource that you asked for.
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
    else:
        secret = service_client.get_secret_value(SecretId=arn,)
        plaintext = secret['SecretString']
        secret_dict = json.loads(plaintext)
    return secret_dict