#####
# Scenario Studio API
# Code sample: Python
# May 1 2019
# (c)2019 Moody's Analytics
# 
import requests
import hashlib 
import hmac
import datetime
import json
import pandas as pd
from time import sleep
import urllib.parse
import datetime
import calendar
import numpy as np

#####
# Function: Make API request, including a freshly generated signature.
#
# Arguments:
# 1. Part of the endpoint, i.e., the URL after "https://api.economy.com/data/v1/"
# 2. Your access key.
# 3. Your personal encryption key.
# 4. Optional: default GET, but specify POST when requesting action from the API.
#
# Returns:
# HTTP response object.
def api_call(apiCommand, accKey, encKey, call_type="GET"):
  url = "https://api.economy.com/scenario-studio/v1/" + apiCommand
  timeStamp = datetime.datetime.strftime(datetime.datetime.utcnow(), "%Y-%m-%dT%H:%M:%SZ")
  payload = bytes(accKey + timeStamp, "utf-8")
  signature = hmac.new(bytes(encKey, "utf-8"), payload, digestmod=hashlib.sha256)
  head = {"AccessKeyId":accKey, 
          "Signature":signature.hexdigest(), 
          "TimeStamp":timeStamp}
  sleep(1)
  if call_type == "POST":
    response = requests.post(url, headers=head)
  elif call_type =="DELETE":
    response = requests.delete(url, headers=head)
  else:
    response = requests.get(url, headers=head)
  return (response)

#####
# Function: Format the data frame.
#
# Arguments:
# json data file
#
# Returns:
# pandas DataFrame
def json_to_df( main_dict ):
    
    if isinstance( main_dict['data'],dict ):
        d0 = main_dict['startDate']
        d0 = [np.int(x) for x in d0.split('T')[0].split('-')]
        startDate = datetime.date( d0[0],d0[1],d0[2] )
        
        dend = main_dict['endDate']
        dend = [np.int(x) for x in dend.split('T')[0].split('-')]
        endDate = datetime.date( dend[0],dend[1],dend[2] )
        
        periods = main_dict['data']['periods']
        freq = main_dict['data']['freq']
        
        dates = pd.date_range( start=startDate, end=endDate, freq=freq[0])
        try:
            data_df = pd.DataFrame( { 'date':dates, main_dict['mnemonic']:main_dict['data']['data']} )
        except ValueError:
            print( dates )
        
    elif isinstance( main_dict['data'],list ):
        df_i  = [ pd.DataFrame(df_j['data']).set_index('date') for df_j in main_dict['data'] ]
        data_df = pd.concat( df_i, axis=1, sort=False )
        data_df.columns = tuple([ df_j['mnemonic'] for df_j in main_dict['data'] ])
        
    else:
        print("Error !! Unable to recognise the format")
        return
    return data_df

#####
# Function: Format output by adding space
#
# Arguments:
#  NA
#
# Returns:
#  NA
def add_space( ):
    print('\n\n\n')

#####
# Setup:
# 1. Store your access key and encryption key.
# Get your keys at:
# https://www.economy.com/myeconomy/api-key-info
ACC_KEY = "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
ENC_KEY = "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"



#####
# III. PROJECT
add_space()
print( '\t\t III. PROJECT' )
add_space()

#
# Identify a project to extract details:
# 1. Data Frame for project contents
get_project = json.loads( api_call("project/", ACC_KEY, ENC_KEY).text )
meta_data   = [item for item in get_project[0] if item !='contributors' and item !='scenarios' ] 
#
# Format the data frame
df_sc = pd.io.json.json_normalize( get_project, record_path = 'scenarios',
                           meta = meta_data, meta_prefix='meta.' )
df_ctb = pd.io.json.json_normalize( get_project, record_path = 'contributors',
                           meta = meta_data, meta_prefix='meta.' )
df_data = pd.merge(df_sc,df_ctb, how='outer', on=["meta."+item for item in meta_data ])
add_space()
print('Project Content:\n', df_data.T)




# 2. Get information about a specific project.
suffix = "project/"+df_data['projectId'].unique()[0]
json_data = json.loads( api_call(suffix, ACC_KEY, ENC_KEY).text )
add_space()
#
# Format the data frame
print( 'Information about a specific project:' )
print( 'Scenarios:\n', pd.io.json.json_normalize( json_data, 
  record_path='scenarios' ).T )
print( '\nContributors:\n', pd.io.json.json_normalize( json_data, 
  record_path='contributors' ).T )




# 3. Get the scenarios within a project.
suffix = "project/"+df_data['projectId'].unique()[0]+"/scenario"
json_data = json.loads( api_call(suffix, ACC_KEY, ENC_KEY).text )
#
# Format the data frame
df_scn = pd.concat( [ pd.DataFrame(json_data), 
                      pd.io.json.json_normalize( json_data, record_path='permissions', 
                      record_prefix='permissions.')], 
                      axis=1).drop('permissions', 1)
add_space()
print( 'Information about scenarios within a project:' )
print( df_scn.T )




# 4. Get the list of all series within a project.
# Project / Project ID / series
suffix = "project/"+df_data['projectId'].unique()[0]+"/series"
#
# Format the data frame
df_series = pd.io.json.json_normalize( json.loads( api_call(suffix, ACC_KEY, ENC_KEY).text ) )
add_space()
print( 'List of all series within a project:\n', 
  df_series[df_series['variable']=='FLBF_POT_US'].T )




# 5. Get the list of series checked out by the current user
# Project / Project ID / series/checked-out
suffix = "project/"+df_data['projectId'].unique()[0]+"/series/checked-out"
json_data = json.loads( api_call(suffix, ACC_KEY, ENC_KEY).text )
add_space()
print( 'List of series checked out by the current user:\n', json_data )


####
# I. DataSeries
add_space()
print('\t\t I. DataSeries')
add_space()


# Add factor.
# 1. Get the central data for series
proj_id = df_data['projectId'].unique()[0]
sc_id = df_data[ df_data['projectId']==proj_id ]['scenarioId'].unique()[0]
var_id = 'FLBF_POT_US'
suffix  = "project/"  + proj_id
suffix += "/scenario/"+ sc_id
suffix += "/data-series/"  + var_id
#
# Set to true if you are requesting the central add factor
suffix += "/data/central?addFactor=false"
json_data = json.loads( api_call(suffix, ACC_KEY, ENC_KEY).text )
#
# Format the data frame
df_sser = json_to_df( json_data )
add_space()
print( 'Series without the central add factor:\n', df_sser.head() )


# 
# Single Series
# 2. Get the local data for series  
proj_id = df_data['projectId'].unique()[0]
sc_id = df_data[ df_data['projectId']==proj_id ]['scenarioId'].unique()[0]
var_id = 'FLBF_POT_US'
data_loc = 'central'
suffix  = "project/" + proj_id
suffix += "/scenario/" + sc_id
suffix += "/data-series/" + var_id
suffix += "/data/" + data_loc
json_data = json.loads( api_call(suffix, ACC_KEY, ENC_KEY).text )
#
# Format the data frame
df_sser = json_to_df( json_data )
add_space()
print( 'Series Data and Metadata of data series in scenario:\n', df_sser.head() )



#
# Multiple Series
# 3. Get multiple series and/or expressions   
proj_id = df_data['projectId'].unique()[0]
mnemonicList = "A1.FLBF_POT_ICHN;A1.FLBF_POT_US"
suffix  = "project/" + proj_id
suffix += "/data-series?expressions=" + mnemonicList
json_data = json.loads( api_call(suffix, ACC_KEY, ENC_KEY).text )
#
# Format the data frame
df_jdata_arr = [json_to_df( jdata ).set_index('date') for jdata in json_data]
df_sser = pd.concat( df_jdata_arr, axis=1, sort=False )
add_space()
print( 'Multi-Series Data and Metadata of data series in scenario:\n', df_sser.head() )


####
# II. HEALTH
add_space()
print( '\t\t II. HEALTH' )
add_space()

# 1. Get the health of the service.
# /health
suffix = "health/"
print ( '\nHealth of the service:\n', json.loads( api_call(suffix, ACC_KEY, ENC_KEY).text ) )



##### Project / Project ID / scenario ID
# IV. Scenario
add_space()
print( '\t\t IV. SCENARIO' )
add_space()


#
# 1. Get information about a specific scenario.
proj_id = df_data['projectId'].unique()[0]
suffix  = "project/" 
suffix += proj_id +"/scenario/"
suffix += df_data[ df_data['projectId']==proj_id ]['scenarioId'].unique()[0] +"/"
suffix += "series/checked-out"
json_data = json.loads( api_call(suffix, ACC_KEY, ENC_KEY).text )
add_space()
print( 'Information about a specific scenario:\n' )
#
# Format the data frame
# print( pd.io.json.json_normalize( json_data ).T )
print( pd.io.json.json_normalize(json_data).dropna(how='all',axis=1).T[0] )


####
# V. SERIES
add_space()
print( '\t\t V. SERIES' )
add_space()



# 1. Get information about a specific series.
# /project/projectId/scenario/scenarioId/series/variableId
proj_id = df_data['projectId'].unique()[0]
sc_id = df_data[ df_data['projectId']==proj_id ]['scenarioId'].unique()[0]
var_id = 'FLBF_POT_US'
suffix  = "project/" 
suffix += proj_id +"/scenario/"
suffix += sc_id +"/series/"
suffix += var_id
json_data = json.loads( api_call(suffix, ACC_KEY, ENC_KEY).text )
add_space()
print( 'Information about a specific series:' )
#
# Format the data frame
# print( pd.io.json.json_normalize( json_data ).set_index('variable').T )
print( pd.io.json.json_normalize(json_data).dropna(how='all',axis=1).T[0] )



# 2. Get the equation specification for a series
# /project/projectId/scenario/scenarioId/series/variableId/equation
proj_id = df_data['projectId'].unique()[0]
sc_id = df_data[ df_data['projectId']==proj_id ]['scenarioId'].unique()[0]
var_id = 'FLBF_POT_US'
suffix  = "project/" 
suffix += proj_id +"/scenario/"
suffix += sc_id +"/series/"
suffix += var_id+"/equation"
json_data = json.loads( api_call(suffix, ACC_KEY, ENC_KEY).text )
add_space()
#
# Format the data frame
print( 'Information about equation specification for a series:\n', pd.DataFrame(json_data).T )



# 3. Get the equation statistics for a series
# /project/projectId/scenario/scenarioId/series/variableId/equation-stats
proj_id = df_data['projectId'].unique()[0]
sc_id = df_data[ df_data['projectId']==proj_id ]['scenarioId'].unique()[0]
var_id = 'FLBF_POT_US'
suffix  = "project/" 
suffix += proj_id +"/scenario/"
suffix += sc_id +"/series/"
suffix += var_id+"/equation-stats"
json_data = json.loads( api_call(suffix, ACC_KEY, ENC_KEY).text )
add_space()
print( 'Information about equation statistics for a series:' )
#
# Format the data frame
print( pd.io.json.json_normalize( json_data ).T )



# 4. Get the list of series that the current series depends on
# /project/projectId/scenario/scenarioId/series/variableId/dependencies
proj_id = df_data['projectId'].unique()[0]
sc_id = df_data[ df_data['projectId']==proj_id ]['scenarioId'].unique()[0]
var_id = 'FLBF_POT_US'
suffix  = "project/" 
suffix += proj_id +"/scenario/"
suffix += sc_id +"/series/"
suffix += var_id+"/dependencies"
json_data = json.loads( api_call(suffix, ACC_KEY, ENC_KEY).text )
add_space()
print( 'List of series that the current series depends on:' )
#
# Format the data frame
print( pd.io.json.json_normalize( json_data ).T.dropna(how='all') )



# 5. Get the list of series that depend on the current series.
# /project/projectId/scenario/scenarioId/series/variableId/rhs
proj_id = df_data['projectId'].unique()[0]
sc_id = df_data[ df_data['projectId']==proj_id ]['scenarioId'].unique()[0]
var_id = 'FLBF_POT_US'
suffix  = "project/" 
suffix += proj_id +"/scenario/"
suffix += sc_id +"/series/"
suffix += var_id+"/rhs"
json_data = json.loads( api_call(suffix, ACC_KEY, ENC_KEY).text )
add_space()
#
# Format the data frame
df_json_data =  pd.io.json.json_normalize( json_data ).pipe( lambda x: x.T.drop('specEquations') )
df_json_data.dropna(how='all',inplace=True)
print( 'List of series that depend on the current series:' )
print( df_json_data )


# 6. Get the full meta information (Equation Info, Equation Statistics, Dependencies, Rhs, etc)
# /project/projectId/scenario/scenarioId/series/variableId/meta 
proj_id = df_data['projectId'].unique()[0]
sc_id = df_data[ df_data['projectId']==proj_id ]['scenarioId'].unique()[0]
var_id = 'FLBF_POT_US'
suffix  = "project/" 
suffix += proj_id +"/scenario/"
suffix += sc_id +"/series/"
suffix += var_id+"/meta"
json_data = json.loads( api_call(suffix, ACC_KEY, ENC_KEY).text )
add_space()
print( 'Meta information of scenario:\n' )
meta_data = [item for item in json_data if item not in ('dependents',
                                            'rhs', 'otherScenarios',
                                            'historicals', 'specEquations',
                                            'equationStatistics') ]
meta_data +=  [ ['equationStatistics',item] for item in json_data['equationStatistics']]
#
# Format the data frame
df_json_data = pd.io.json.json_normalize( json_data, 
                                         record_path=['rhs'], 
                                         meta=meta_data, 
                                         meta_prefix='meta.' )
print( df_json_data.head() )
print( '\nDependents:' )
#
# Format the data frame
print( pd.io.json.json_normalize(json_data,record_path='dependents').dropna(how='all',axis=1).T[0] )
add_space()