import sys
import s2api
import datetime
import pandas as pd

# enter your keys here
# obtain them from: https://economy.com/myeconomy/api-key-info
access_key = "your key here"
encryption_key = "your key here"

# instantiate api
api = s2api.ScenarioStudioAPI(access_key, encryption_key)

# get information on your Scenario Studio projects
projects = api.get_project_list()

# get info on the first project in that list
project_id = projects[0]['id']
project_info = api.get_project_info(project_id)

# get info on the first scenario in the project
scenarios = api.get_project_scenarios(project_id)
scenario_id = scenarios[0]['id']
scenario_alias = scenarios[0]['alias']
scenario_info = api.get_scenario_info(project_id,scenario_id)

# get variable listing for this scenario
series_list = api.search_series(project_id,scenario_ids=[scenario_id])

# download data
download_list = []
for n in range(0,4):
    download_list.append(scenario_alias+"."+series_list[n]['variableId'])
data = api.get_series_data(project_id,download_list)