
import os
import pyodbc
import pandas

server = 'your--db.database.windows.net'
database = 'AdventureWorks'
username = 'your--user'
password = 'your--pwd'   
driver= '{ODBC Driver 17 for SQL Server}'

# Specifying the ODBC driver, server name, database, etc. directly
cnxn = pyodbc.connect('DRIVER='+driver+';SERVER=tcp:'+server+';PORT=1433;DATABASE='+database+';UID='+username+';PWD='+ password)

# Sample query
sql = "SELECT TOP 3 * FROM SalesLT.Customer"

# Load into Pandas dataframe
DF = pandas.read_sql(sql,cnxn)

# Perform ML Training here with SK Learn etc.
# . 
# .
# .

# File saved in the outputs folder is automatically uploaded into experiment record
os.makedirs('outputs', exist_ok=True)

# Export SQL query to outputs - in reality this would be a PKL file from some trained model
DF.to_csv('outputs/SQL_out.csv')
