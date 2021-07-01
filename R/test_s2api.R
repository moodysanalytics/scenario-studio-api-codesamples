# Place the s2api.R library (available in this repo) in the same directory as this script
source(paste0(dirname(sys.frame(1)$ofile),"/s2api.R"))

# enter your keys here
# obtain them from: https://economy.com/myeconomy/api-key-info
ACC_KEY <- "your key here"
ENC_KEY <- "your key here"

# instantiate api
s2api <- MA_S2Api$new(acc_key=ACC_KEY,
                      enc_key=ENC_KEY,
                      oauth = TRUE)

# get information on your Scenario Studio projects
projects <- s2api$get_project_list()
toJSON(projects)

# get info on the first project in that list
project_id <- projects[[1]]$id
project_info <- s2api$get_project_info(project_id)
toJSON(project_info)

# get info on the first scenario in the project
scenarios <- s2api$get_project_scenarios(project_id)
toJSON(scenarios)
scenario_id <- scenarios[[1]]$id
scenario_alias <- scenarios[[1]]$alias
scenario_info <- s2api$get_scenario_info(project_id, scenario_id)
toJSON(scenario_info)

# get variable listing for this scenario
series_list <- s2api$search_series(project_id, scenario_ids=c(scenario_id))

# download data
download_list = c()
for (n in 1:5) {
  download_list = append(download_list,paste(scenario_alias,series_list[[n]]$variableId,sep="."))
}
data = s2api$get_series_data(project_id,series_list = download_list)

