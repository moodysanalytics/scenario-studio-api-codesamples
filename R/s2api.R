library(digest)
library(jsonlite)
library(httr)
library(R6)

MA_Api <- R6Class("MA_Api", 
  public = list(
    acc_key = NULL,
    enc_key = NULL,
    oauth = FALSE,
    base_uri = "https://api.economy.com",
    token = NULL,
    initialize = function(acc_key,
                          enc_key,
                          oauth=False) {
      stopifnot(is.character(acc_key),length(acc_key) == 1)
      stopifnot(is.character(enc_key),length(enc_key) == 1)
      stopifnot(is.logical(oauth))
      self$acc_key <- acc_key
      self$enc_key <- enc_key
      self$oauth <- oauth
      self$token = "bearer None"
    },
    get_hmac_headers = function() { 
      timeStamp <- format(as.POSIXct(Sys.time()),"%Y-%m-%dT%H:%M:%SZ",tz="UTC")
      hashMsg <- paste0(self$acc_key,timeStamp)
      signature <- hmac(self$enc_key,hashMsg,"sha256")
      print(self$base_uri)
      c("AccessKeyId"=self$acc_key,"Signature"=signature, "TimeStamp"=timeStamp)
    },
    get_oauth_token = function() {
      if (!self$oauth) stop("oauth is false for this api")
      url <- paste0(self$base_uri,"/oauth2/token")
      print("get oauth token")
      access_key <- self$acc_key
      private_key <- self$enc_key
      headers <- c("Content-Type"="application/x-www-form-urlencoded")
      data <- paste0("client_id=",access_key,"&client_secret=",private_key,"&grant_type=client_credentials")
      req <- POST(url, httr::add_headers(headers), body=data)
      oauth_resp <- content(req, "text")
      isvalidjson <- validate(oauth_resp)
      #If valid, assign token
      if (isvalidjson){
        json <- fromJSON(oauth_resp)
        if (exists("access_token",json)) {
          token <- paste(json["token_type"],json["access_token"],sep=" ")
        } else if (exists("error_description",json)) {
          stop(json["error_description"])
        }
        else
        {
          print(oauth_resp)
          stop("Error: Invalid response from oauth")
        }
      } else {
        print(oauth_resp)
        stop("Error: Invalid response from oauth")
      }
      return (token)   
    },
    request = function(method, url, payload=list(), maxTries=5) {
      fullurl <- paste(self$base_uri,url,sep="")
      status <- 0
      tries <- 0
      method <- tolower(method)
      ret = list()
      if (self$oauth && (self$token == "bearer None" || is.null(self$token))) {
        self$token <- self$get_oauth_token()
      }
      finished <- FALSE
      headers <- NULL
      while ((tries < maxTries) && (finished != TRUE)) {
        if (self$oauth) {
          headers <- c("Authorization" = self$token)
        } else {
          headers <- self$get_hmac_headers()
        }
        headers[["Content-Type"]] <- "application/json"
        headers[["Accept"]] <- "application/json"
        if (method == "get") {
          req <- httr::GET(fullurl,httr::add_headers(headers))
        } else if (method == "delete") {
          req <- httr::DELETE(fullurl,httr::add_headers(headers))
        } else if (method == "post") {
          if (is.character(payload) && length(payload) ==1) {
            req <- httr::POST(fullurl,httr::add_headers(headers),body=payload,encode = "raw")
          } else {
            req <- httr::POST(fullurl,httr::add_headers(headers),body=toJSON(payload,auto_unbox=TRUE,null="null",digits=NA),encode = "raw")
          }
        } else if (method == "put") {
          if (is.character(payload) && length(payload) ==1) {
            req <- httr::PUT(fullurl,httr::add_headers(headers),body=payload,encode = "raw")
          } else {
            req <- httr::PUT(fullurl,httr::add_headers(headers),body=toJSON(payload,auto_unbox=TRUE,null="null",digits=NA),encode = "raw")
          }
        } else {
          stop("invalid http method")
        }
        tries <- tries + 1
        status <- req$status_code
        if (status == 429) {
          print("Too many requests, wait 10 seconds and try again...")
          Sys.sleep(10) 
        } else if (self$oauth && status == 401) {
          print("Get a new oauth token")
          self$token <- self$get_oauth_token()
        } else if ((status == 200) || ((status == 304) && (method == "put"))) {
          ret <- content(req,"parsed",encoding = "UTF-8")
          finished <- TRUE
        } else {
          print(paste("Error - Status : ",status,", Msg : ",content(req,"text"),sep = ""))
        }
      }
      return(ret)
    }
  )
)

MA_S2Api <- R6Class("MA_S2Api", 
  inherit = MA_Api,
  public = list(
    initialize = function(acc_key, enc_key, oauth) {
      super$initialize(acc_key = acc_key,
                       enc_key = enc_key,
                       oauth = oauth)
      self$base_uri = "https://api.economy.com/scenario-studio/v2"
    }
  )
)

MA_S2Api$set("public", "get_health", function() { 
  url <- "/health"
  ret <- self$request(method="get",url=url)
  return(ret)
})

MA_S2Api$set("public", "get_project_list", function() { 
  url <- "/project"
  ret <- self$request(method="get",url=url)
  return(ret)
})

MA_S2Api$set("public", "search_projects", function(tags=NULL,
                                                   terms=NULL,
                                                   take=100) {
  stopifnot(is.list(tags) || is.null(tags))
  stopifnot(is.list(terms) || is.null(terms))
  url <- paste0("/project/search?options.sortBy=-created&take=",take)
  if (!is.null(tags)){
    for (tag in tags) {
      url <- paste0(url,"&options.tags=",tag)
    }
  }
  if (!is.null(terms)){
    for (term in terms) {
      url <- paste0(url,"&options.terms=",term)
    }
  }
  ret <- self$request(method="get",url=url)
  return(ret)
})

MA_S2Api$set("public", "get_project_info", function(project_id) {
  stopifnot(is.character(project_id),length(project_id) == 1)
  url <- paste0("/project/",project_id)
  ret <- self$request(method="get",url=url)
  return(ret)
})

MA_S2Api$set("public", "get_scenario_info", function(project_id, scenario_id) {
  stopifnot(is.character(project_id),length(project_id) == 1)
  stopifnot(is.character(scenario_id),length(scenario_id) == 1)
  url <- paste0("/project/",project_id,"/scenario/",scenario_id)
  ret <- self$request(method="get",url=url)
  return(ret)
})

MA_S2Api$set("public", "get_project_scenarios", function(project_id) {
  stopifnot(is.character(project_id),length(project_id) == 1)
  url <- paste0("/project/",project_id,"/scenario")
  ret <- self$request(method="get",url=url)
  return(ret)
})

MA_S2Api$set("public", "get_project_series", function(project_id) {
  stopifnot(is.character(project_id),length(project_id) == 1)
  url <- paste0("/project/",project_id,"/series")
  ret <- self$request(method="get",url=url)
  return(ret)
})

MA_S2Api$set("public", "make_project", function(title, 
                                                tags=list(), 
                                                description="") {
  stopifnot(is.character(title),length(title) == 1)
  stopifnot(is.list(tags))
  stopifnot(is.character(description),length(description) == 1)
  pl <- list(
    title = title,
    tags = tags,
    description = description
  )
  url <- paste0("/project/create")
  ret <- self$request(method ="post",url=url,payload=pl)
  return(ret)
})

MA_S2Api$set("public", "build_project", function(project_id) {
  stopifnot(is.character(project_id),length(project_id) == 1)
  url <- paste0("/project/",project_id,"/build")
  ret <- self$request(method="post",url=url)
  return(ret)
})

MA_S2Api$set("public", "get_base_scenario_list", function(model_types=list(),
                                                          terms=list(), 
                                                          vintages=list(), 
                                                          sortby="-created") {
  stopifnot(is.list(model_types))
  stopifnot(is.list(terms))
  stopifnot(is.list(vintages))
  stopifnot(is.character(sortby),length(sortby) == 1)
  pl <- list()
  if (length(model_types) > 0) pl$modelTypes <- model_types
  if (length(terms) > 0) pl$terms <- terms
  if (length(vintages) > 0) pl$vintages <- as.list(vintages)
  if (nchar(sortby) > 0) pl$sortBy <- sortby
  url <- paste0("/base-scenario/search?take=50")
  ret <- self$request(method ="post",url=url,payload=pl)
  return(ret)
})

MA_S2Api$set("public", "get_base_scenario_count", function(model_types=list(),
                                                           terms=list(), 
                                                           vintages=list()) {
  stopifnot(is.list(model_types))
  stopifnot(is.list(terms))
  stopifnot(is.list(vintages))
  pl <- list()
  if (length(model_types) > 0) pl$modelTypes <- as.list(model_types)
  if (length(terms) > 0) pl$terms <- as.list(terms)
  if (length(vintages) > 0) pl$vintages <- as.list(as.integer(vintages))
  url <- paste0("/base-scenario/search/count")
  ret <- self$request(method ="post",url=url,payload=pl)
  return(ret)
})

MA_S2Api$set("public", "local_solve", function(project_id, scenario_id, partial="") {
  stopifnot(is.character(project_id),length(project_id) == 1)
  stopifnot(is.character(scenario_id),length(scenario_id) == 1)
  stopifnot(is.character(partial),length(partial) == 1)
  url <- paste0("/project/",project_id,"/scenario/",scenario_id,"/solve/local")
  pl <- list()
  if (nchar(partial) > 0) pl$partial <- partial
  ret <- self$request(method="post",url=url,payload=pl)
  return(ret)
})

MA_S2Api$set("public", "central_solve", function(project_id, scenario_id) {
  stopifnot(is.character(project_id),length(project_id) == 1)
  stopifnot(is.character(scenario_id),length(scenario_id) == 1)
  url <- paste0("/project/",project_id,"/scenario/",scenario_id,"/solve/central")
  ret <- self$request(method="post",url=url)
  return(ret)
})

MA_S2Api$set("public", "get_base_scenario_info", function(scenario_id) {
  stopifnot(is.character(scenario_id),length(scenario_id) == 1)
  url <- paste0("/base-scenario/",scenario_id)
  ret <- self$request(method="get",url=url)
})

MA_S2Api$set("public", "clone_scenario", function(project_id, 
                                                  scenario_id, 
                                                  alias, 
                                                  title = NULL, 
                                                  description = NULL, 
                                                  edit_start = NULL, 
                                                  forecast_end = NULL) {
  stopifnot(is.character(project_id),length(project_id) == 1)
  stopifnot(is.character(scenario_id),length(scenario_id) == 1)
  stopifnot(is.character(alias),length(alias) == 1)
  pl <- self$get_base_scenario_info(scenario_id)
  pl$alias = alias
  if (!is.null(title)) {
    stopifnot(is.character(title),length(title) == 1)
    pl$title <- title
  }
  if (!is.null(description)) {
    stopifnot(is.character(description),length(description) == 1)
    pl$description <- description
  }
  if (!is.null(edit_start)) {
    stopifnot(is.numeric(edit_start),length(edit_start) == 1)
    pl$editStart <- as.integer(edit_start)
  }
  if (!is.null(forecast_end)) {
    stopifnot(is.numeric(forecast_end),length(forecast_end) == 1)
    pl$forecastEnd <- as.integer(forecast_end)
    pl$truncate <- TRUE
  }
  url <- paste0("/project/",project_id,"/scenario/clone")
  ret <- self$request(method="post",url=url,payload=pl)  
  return(ret)
})

MA_S2Api$set("public", "add_read_only_scenario", function(project_id,
                                                          scenario_id,
                                                          alias){
  stopifnot(is.character(project_id),length(project_id) == 1)
  stopifnot(is.character(scenario_id),length(scenario_id) == 1)
  stopifnot(is.character(alias),length(alias) == 1)
  url = paste0("/project/",project_id,"/scenario/copy")
  pl <- list(
    alias = alias,
    id = scenario_id
  )
  ret <- self$request(method="post",url=url,payload=pl)  
  return(ret)
})

MA_S2Api$set("public", "get_order_status", function(project_id, 
                                                    order_id, 
                                                    build = FALSE) {
  stopifnot(is.character(project_id),length(project_id) == 1)
  stopifnot(is.character(order_id),length(order_id) == 1)
  stopifnot(is.logical(build),length(build) == 1)
  url <- paste0("/project/",project_id,"/order/",order_id)
  if (build) url <- paste0(url,"/build")
  ret <- self$request(method="get",url=url)
  return(ret)
})

MA_S2Api$set("private", "s2read_to_ts", function(s2_series){
  freqCode <- s2_series$data$freqCode
  start <- s2_series$data$start
  if (freqCode == 172) {
    prds <- 4
  } else if (freqCode == 128) {
    prds <- 12
  } else if (freqCode == 204) {
    prds <- 1
  } else {
    stop("Invalid Frequency")
  }
  year <- 1850 + floor((start - 1) / prds)
  prd <- 1 + (start - 1) %% prds
  values <- s2_series$data$data
  values <- lapply(values,function(v){ if (abs(v) > 1.7e+38) NA else v})
  ts_series <- ts(values, start = c(year,prd), frequency = prds)
  attr(ts_series,"desc") <- s2_series$description
  attr(ts_series, "geo") <- s2_series$geoCode
  attr(ts_series, "last_hist") <- s2_series$lastHistory
  return(ts_series)
})

MA_S2Api$set("public", "get_series_data", function(project_id, 
                                                   series_list = character(),
                                                   transformation = 0,
                                                   freq = 172, 
                                                   batch = 100, 
                                                   dates = NULL) {
  stopifnot(is.character(project_id),length(project_id) == 1)
  stopifnot(is.character(series_list))
  url <- paste0("/project/",project_id,"/data-series?freq=",freq,"&transformation=",transformation)
  
  num_series <- length(series_list)
  ret <- list()
  for (i in 1:ceiling(num_series / batch)) {
    start <- (i-1)*batch
    end <- min(i*batch,num_series)
    pl <- as.list(series_list[start:end])
    series_output <- self$request(method="post",url=url, payload=pl)
    for (series_obj in series_output) {
      ret[[series_obj$mnemonic]] <- private$s2read_to_ts(series_obj)
    }
  }
  return(ret)
})


MA_S2Api$set("public", "wait_for_orders", function(project_id, 
                                                   orders, build = FALSE, 
                                                   sleep = 5) {
  stopifnot(is.character(project_id),length(project_id) == 1)
  stopifnot(is.list(orders))
  stopifnot(is.logical(build),length(build) == 1)
  stopifnot(is.numeric(sleep),length(sleep) == 1)
  wait_one <- function(o) {
    status <- self$get_order_status(project_id, o$orderId, build = build)
    orderDone <- status$finished
    while(!orderDone) {
      Sys.sleep(sleep)
      status <- self$get_order_status(project_id, o$orderId, build = build)
      orderDone <- status$finished
    }
    status
  }
  ret <- lapply(orders, wait_one)
  return(ret)
})

MA_S2Api$set("public", "claim", function(project_id, 
                                         scenario_id, 
                                         variables = character(),
                                         exogenize = FALSE) {
  stopifnot(is.character(project_id),length(project_id) == 1)
  stopifnot(is.character(scenario_id),length(scenario_id) == 1)
  stopifnot(is.character(variables))
  stopifnot(is.logical(exogenize),length(exogenize) == 1)
  url <- paste0("/project/",project_id,"/scenario/",scenario_id,"/series/checkout?exogenize=",exogenize)
  pl <- lapply(variables, toupper)
  ret <- self$request(method="post",url=url,payload=pl)  
  return(ret)
})

MA_S2Api$set("public", "get_claim_list", function(project_id) {
  stopifnot(is.character(project_id),length(project_id) == 1)
  url <- paste0("/project/",project_id,"/series/checked-out")
  ret <- self$request(method="get",url=url)
  return(ret)
})

MA_S2Api$set("public", "release", function(project_id,
                                           scenario_id, 
                                           variables = character()) {
  stopifnot(is.character(project_id),length(project_id) == 1)
  stopifnot(is.character(scenario_id),length(scenario_id) == 1)
  stopifnot(is.character(variables))
  url <- paste0("/project/",project_id,"/scenario/",scenario_id,"/series/checkin")
  pl <- lapply(variables, toupper)
  ret <- self$request(method="post",url=url,payload=pl)  
  return(ret)
})

MA_S2Api$set("public", "push", function(project_id, 
                                        scenario_id, 
                                        variables = character(),
                                        note = "") {
  stopifnot(is.character(project_id),length(project_id) == 1)
  stopifnot(is.character(scenario_id),length(scenario_id) == 1)
  stopifnot(is.character(variables))
  url <- paste0("/project/",project_id,"/scenario/",scenario_id,"/series/commit")
  pl <- list()
  pl$note <- note
  pl$variables <- lapply(variables, toupper)
  ret <- self$request(method="post",url=url,payload=pl)  
  return(ret)
})

MA_S2Api$set("public", "endogenize", function(project_id, 
                                              scenario_id, 
                                              variables = character()) {
  stopifnot(is.character(project_id),length(project_id) == 1)
  stopifnot(is.character(scenario_id),length(scenario_id) == 1)
  stopifnot(is.character(variables))
  url <- paste0("/project/",project_id,"/scenario/",scenario_id,"/series/endogenizeBulk")
  pl <- lapply(variables, toupper)
  ret <- self$request(method="put",url=url,payload=pl)  
  return(ret)
})

MA_S2Api$set("public", "exogenize", function(project_id,
                                             scenario_id,
                                             variables = character()) {
  stopifnot(is.character(project_id),length(project_id) == 1)
  stopifnot(is.character(scenario_id),length(scenario_id) == 1)
  stopifnot(is.character(variables))
  url <- paste0("/project/",project_id,"/scenario/",scenario_id,"/series/exogenize")
  pl <- lapply(variables, toupper)
  ret <- self$request(method="put", url=url, payload=pl)  
  return(ret)
})

MA_S2Api$set("public", "exogenize_through", function(project_id,
                                             scenario_id,
                                             variables = character(),
                                             date) {
  stopifnot(is.character(project_id),length(project_id) == 1)
  stopifnot(is.character(scenario_id),length(scenario_id) == 1)
  stopifnot(is.character(variables))
  stopifnot(is.numeric(date))
  url <- paste0("/project/",project_id,"/scenario/",scenario_id,"/series/exogenize-through")
  pl <- list()
  pl$variables <- lapply(variables, toupper)
  pl$exogenizeThrough <- date
  ret <- self$request(method="put", url=url, payload=pl)  
  return(ret)
})

MA_S2Api$set("private", "ts_to_s2write", function(ts_series){
  tsp <- attr(ts_series, "tsp")
  prds <- tsp[3]
  start <- 1 + (tsp[1] - 1850) * prds 
  if (prds == 4) {
    freq <- 172
  } else if (prds == 12) {
    freq <- 128
  } else if (prds == 1) {
    freq <- 204
  } else {
    stop("Invalid Frequency")
  }
  data_array <- unclass(ts_series)
  data_array[is.na(data_array)] <- -3.4028234663852886E+38
  s2_series <- list(
    startDate = start,
    data = data_array
  )
  return(s2_series)
})

MA_S2Api$set("public", "write_series_data", function(project_id,
                                             scenario_id,
                                             variable,
                                             data,
                                             edit_history=FALSE) {
  stopifnot(is.character(project_id),length(project_id) == 1)
  stopifnot(is.character(scenario_id),length(scenario_id) == 1)
  stopifnot(is.character(variable),length(variable) == 1)
  stopifnot(is.ts(data))
  stopifnot(is.logical(edit_history),length(edit_history) == 1)
  variable <- toupper(variable)
  url <- paste0("/project/",project_id,"/scenario/",scenario_id,"/data-series/",variable,"/data/local")
  pl <- private$ts_to_s2write(data)
  pl$historyModified <- edit_history
  ret <- self$request(method="put",url=url, payload=pl)  
  return(ret)
})

MA_S2Api$set("public", "edit_project_settings", function(project_id, 
                                                         edit_identities = NULL,
                                                         require_comments = NULL,
                                                         edit_equations = NULL,
                                                         databuffet_alias = NULL,
                                                         allow_custom_variables = NULL,
                                                         edit_history = NULL,
                                                         edit_lasthist = NULL) {
  stopifnot(is.character(project_id),length(project_id) == 1)
  pl <- self$get_project_info(project_id)
  if (!is.null(edit_identities)) {
    stopifnot(is.logical(edit_identities), length(edit_identities) == 1)
    pl$varTypesLockStatus$`1` <- !edit_identities
  } 
  if (!is.null(require_comments)) {
    stopifnot(is.logical(require_comments),length(require_comments) == 1)
    pl$commentRequired <- require_comments
  }
  if (!is.null(edit_equations)) {
    stopifnot(is.logical(edit_equations), length(edit_equations) == 1)
    pl$allowEquationEditing <- edit_equations
  } 
  if (!is.null(allow_custom_variables)) {
    stopifnot(is.logical(allow_custom_variables), length(allow_custom_variables) == 1)
    pl$allowCustomSeries <- allow_custom_variables
  } 
  if (!is.null(edit_history)) {
    stopifnot(is.logical(edit_history), length(edit_history) == 1)
    pl$allowHistoryEditing <- edit_history
  } 
  if (!is.null(edit_lasthist)) {
    stopifnot(is.logical(edit_lasthist), length(edit_lasthist) == 1)
    pl$allowLastHistoryChange <- edit_lasthist
  } 
  if (!is.null(databuffet_alias)) {
    stopifnot(is.character(databuffet_alias), length(databuffet_alias) == 1)
    pl$alias <- paste0("S2PRJ_",toupper(databuffet_alias))
  } 
  url <- paste0("/project/",project_id,"/settings")
  ret <- self$request(method ="put",url=url,payload=pl)
  return(ret)
})

MA_S2Api$set("public", "edit_scenario_settings", function(project_id,
                                                          scenario_id,
                                                          title = NULL,
                                                          description = NULL,
                                                          edit_start = NULL,
                                                          forecast_end = NULL) {
  stopifnot(is.character(project_id),length(project_id) == 1)
  stopifnot(is.character(scenario_id),length(scenario_id) == 1)
  pl <- self$get_scenario_info(project_id, scenario_id)
  if (!is.null(title)) {
    stopifnot(is.character(title), length(title) == 1)
    pl$title <- title
  } 
  if (!is.null(description)) {
    stopifnot(is.character(description), length(description) == 1)
    pl$description <- description
  } 
  if (!is.null(edit_start)) {
    stopifnot(is.numeric(edit_start),length(edit_start) == 1)
    pl$editStart <- as.integer(edit_start)
  }
  if (!is.null(forecast_end)) {
    stopifnot(is.numeric(forecast_end), length(forecast_end) == 1)
    pl$forecastEnd <- as.integer(forecast_end)
  } 
  url <- paste0("/project/",project_id,"/scenario/",scenario_id)
  ret <- self$request(method ="put", url=url, payload=pl)
  return(ret)
})

MA_S2Api$set("public", "search_series", function(project_id,
                                                 scenario_ids = NULL,
                                                 geos = NULL,
                                                 state = NULL,
                                                 query = "",
                                                 checked_out = NULL,
                                                 variable_type = NULL,
                                                 sharedown = NULL) {
  stopifnot(is.character(project_id),length(project_id) == 1)
  pl <- list()
  stopifnot(is.character(query),length(query) == 1)
  pl$query <- query
  if (!is.null(state)) {
    # todo type check of state
    pl$state <- state
  }
  if (!is.null(checked_out)) {
    stopifnot(is.numeric(checked_out),length(checked_out) == 1)
    pl$checkedOut <- as.integer(checked_out)
  }
  if (!is.null(variable_type)) {
    # todo type check of variable_type  
    pl$variableType <- variable_type
  }
  if (is.null(scenario_ids)) {
    scensInfo = self$get_project_scenarios(project_id)
    scenario_ids <- lapply(scensInfo,function(s){s$id})
  }
  #todo type check of scenario_ids
  pl$scenarioId <- as.list(scenario_ids)
  if (!is.null(geos)) {
    #todo type check of geos
    pl$geographies <- geos
  }
  if (!is.null(sharedown)) {
    #todo type check of sharedown
    pl$sharedown <- sharedown
  }
  url <- paste0("/project/",project_id,"/search/count")
  count <- self$request(method = "post", url = url, payload = pl)
  if (count > 0) {
    url <- paste0("/project/",project_id,"/search/results?skip=0&take=",count)
    ret <- self$request(method = "post", url = url, payload = pl)
    
  } else {
    ret <- list()    
  }
  return(ret)
})

MA_S2Api$set("public", "get_sharedown_info", function(project_id,
                                                     scenario_id,
                                                     variable) {
  stopifnot(is.character(project_id),length(project_id) == 1)
  stopifnot(is.character(scenario_id),length(scenario_id) == 1)
  stopifnot(is.character(variable),length(variable) == 1)
  variable <- toupper(variable)
  url <- paste0("/project/",project_id,"/scenario/",scenario_id,"/series/",variable,"/sharedown")
  ret <- self$request(method = "get", url = url)  
  return(ret)
})

MA_S2Api$set("public", "sharedown_solve", function(project_id,
                                                   scenario_id,
                                                   variable) {
  stopifnot(is.character(project_id),length(project_id) == 1)
  stopifnot(is.character(scenario_id),length(scenario_id) == 1)
  stopifnot(is.character(variable),length(variable) == 1)
  variable <- toupper(variable)
  url <- paste0("/project/",project_id,"/scenario/",scenario_id,"/series/",variable,"/sharedown")
  ret <- self$request(method = "post", url = url)  
  return(ret)
})

MA_S2Api$set("public", "get_audits", function(project_id,
                                              scenario_ids=NULL,
                                              actions=NULL) {
  stopifnot(is.character(project_id),length(project_id) == 1)
  params <- c()
  if (!is.null(scenario_ids)) {
    for (scenario_id in scenario_ids) {
      params <- append(params,paste0("options.scenarios=",scenario_id))
    }
  }
  if (!is.null(actions)) {
    for (action in actions) {
      params <- append(params,paste0("options.actions=",action))
    }
  }
  url <- paste0("/audit/project/",project_id)
  if (length(params) > 0){
    url <- paste0(url,"?",paste(params,collapse='&'))
  }
  ret <- self$request(method = "get", url = url)  
  return(ret)
})

MA_S2Api$set("public", "get_pushed_series", function(project_id,
                                                      scenario_id) {
  stopifnot(is.character(project_id),length(project_id) == 1)
  stopifnot(is.character(scenario_id),length(scenario_id) == 1)
  url <- paste0("/audit/project/",project_id,"?options.actions=4&options.scenarios=",scenario_id)
  ret <- self$request(method = "get", url = url)  
  return(ret)
})

MA_S2Api$set("public", "set_user_permission", function(project_id,
                                                       emails,
                                                       role) {
  stopifnot(is.character(project_id),length(project_id) == 1)
  stopifnot(is.list(emails))
  stopifnot(is.numeric(role))
  users <- self$get_user_universe()
  user_emails <- sapply(users,function(u) {tolower(u$email)})
  user_sids <- sapply(users,function(u) {u$sid})
  sids <- as.list(user_sids[match(tolower(emails),user_emails)])
  pl <- list()
  for (sid in sids)
  {
    pl[[length(pl)+1]] <- list(sid=sid,role=role)
  }
  url <- paste0("/project/",project_id,"/contributor/",role)
  ret <- self$request(method = "put", url = url, payload = pl)
  return(ret)
})

MA_S2Api$set("public", "get_user_universe", function() {
  url <- paste0("/group/client")
  ret <- self$request(method = "get", url = url)  
  return(ret)
})

MA_S2Api$set("public", "edit_equation", function(project_id,
                                                 scenario_id,
                                                 variable,
                                                 equation) {
  stopifnot(is.character(project_id),length(project_id) == 1)
  stopifnot(is.character(scenario_id),length(scenario_id) == 1)
  stopifnot(is.character(variable),length(variable) == 1)
  stopifnot(is.character(equation),length(equation) == 1)
  variable <- toupper(variable)
  equation <- toupper(equation)
  url <- paste0("/project/",project_id,"/scenario/",scenario_id,"/series/",variable,"/equation")
  pl <- paste("'",URLencode(equation, reserved = TRUE),"'")
  ret <- self$request(method = "put", url = url, payload = pl)  
  return(ret)
})

MA_S2Api$set("public", "clear_add_factors", function(project_id,
                                                     scenario_id,
                                                     variables = character()) {
  stopifnot(is.character(project_id),length(project_id) == 1)
  stopifnot(is.character(scenario_id),length(scenario_id) == 1)
  stopifnot(is.character(variables))
  url <- paste0("/project/",project_id,"/scenario/",scenario_id,"/data-series/add-factor/local")
  pl <- lapply(variables, function(v){paste0(toupper(v),"_A")})
  ret <- self$request(method="put",url=url,payload=pl)  
  return(ret)
})

MA_S2Api$set("public", "get_variable_info", function(project_id,
                                                     scenario_id,
                                                     variable) {
  stopifnot(is.character(project_id),length(project_id) == 1)
  stopifnot(is.character(scenario_id),length(scenario_id) == 1)
  stopifnot(is.character(variable),length(variable) == 1)
  url <- paste0("/project/",project_id,"/scenario/",scenario_id,"/variable/",toupper(variable))
  ret <- self$request(method="get",url=url)  
  return(ret)
})

MA_S2Api$set("public", "add_custom_variable", function(project_id,
                                                       scenario_id,
                                                       variable,
                                                       data, 
                                                       variable_type=0,
                                                       equation=NULL,
                                                       observed="AVERAGED",
                                                       last_hist=NULL,
                                                       title="",
                                                       units="",
                                                       source="",
                                                       add_factor_type=2){
  stopifnot(is.character(project_id),length(project_id) == 1)
  stopifnot(is.character(scenario_id),length(scenario_id) == 1)
  stopifnot(is.character(variable),length(variable) == 1)
  stopifnot(is.ts(data))
  pl <- list()
  pl$variable <- toupper(variable)
  pl$observedAttribute <- toupper(observed)
  pl$title <- title
  pl$units <- units
  pl$source <- source
  if (!is.null(equation)) {
    pl$equation = toupper(equation)
  }
  s2data <- private$ts_to_s2write(data)
  pl$startDate <- s2data$startDate
  pl$data <- s2data$data
  if (is.null(last_hist)) {
    pl$lastHistorical <- s2data$startDate + length(s2data$data) - 1
  } else {
    pl$lastHistorical <- last_hist
  }
  pl$addFactorType <- add_factor_type
  pl$variableType <- variable_type
  url <- paste0("/project/",project_id,"/scenario/",scenario_id,"/series/custom")
  ret <- self$request(method="post",url=url,payload=list(pl))
  return(ret)
})

MA_S2Api$set("public", "remove_scenario", function(project_id, scenario_alias) {
  stopifnot(is.character(project_id),length(project_id) == 1)
  stopifnot(is.character(scenario_alias),length(scenario_alias) == 1)
  url <- paste0("/project/",project_id,"/scenario/alias/",scenario_alias)
  ret <- self$request(method="delete",url=url)
  return(ret)
})

MA_S2Api$set("public", "delete_project", function(project_id) {
  stopifnot(is.character(project_id),length(project_id) == 1)
  url <- paste0("/project/",project_id)
  ret <- self$request(method="delete",url=url)
  return(ret)
})

MA_S2Api$set("public", "get_scenario_checkpoints", function(project_id, scenario_id) {
  stopifnot(is.character(project_id),length(project_id) == 1)
  stopifnot(is.character(scenario_id),length(scenario_id) == 1)
  url <- paste0("/project/",project_id,'/checkpoint/',scenario_id)
  ret <- self$request(method="get",url=url)
  return(ret)
})

MA_S2Api$set("public", "create_checkpoint", function(project_id,
                                                     scenario_id,
                                                     note="") {
  stopifnot(is.character(project_id),length(project_id) == 1)
  stopifnot(is.character(scenario_id),length(scenario_id) == 1)
  stopifnot(is.character(note),length(note) == 1)
  pl <- list(note = note)
  url <- paste0("/project/",project_id,'/scenario/',scenario_id,'/checkpoint')
  ret <- self$request(method="post",url=url,payload=pl)
  return(ret)
})

MA_S2Api$set("public", "create_checkpoint", function(project_id, scenario_id, note="") {
  stopifnot(is.character(project_id),length(project_id) == 1)
  stopifnot(is.character(scenario_id),length(scenario_id) == 1)
  pl <- list()
  pl$note <- note
  url <- paste0("/project/",project_id,"/scenario/",scenario_id,"/checkpoint")
  ret <- self$request(method="post",url=url,payload=pl)
  return(ret)
})  
