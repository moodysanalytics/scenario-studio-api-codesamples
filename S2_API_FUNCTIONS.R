#####
# Scenario Studio API
# Code sample: R
# May 9 2019
# (c)2019 Moody's Analytics
#

library(digest)
library(jsonlite)
library(httr)
library(magrittr)
library(dplyr)
library(xts)


############## STORE ACCESS AND ENCRYPTION KEYS #################
ACC_KEY  <- "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
ENC_KEY  <- "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"



### Function to get List of projects on account ###
myProjectList <- function(accKey, encKey){
  url <- paste("https://api.economy.com/scenario-studio/v1/project/", sep="") 
  print(url)
  timeStamp <- format(as.POSIXct(Sys.time()), "%Y-%m-%dT%H:%M:%SZ", tz="UTC")
  hashMsg   <- paste(accKey, timeStamp, sep="")
  signature <- hmac(encKey, hashMsg, "sha256")
  
  Sys.sleep(1)

    GET(url, httr::add_headers("AccessKeyId" = accKey,
                               "Signature" = signature,
                               "TimeStamp" = timeStamp)) %>%

    content(.,as="text") %>%
    fromJSON() %>%
  return()
}
        myProjectList(ACC_KEY,ENC_KEY) %>% 
          View()


### Function to get project Id using project name ###
getProjId <- function(accKey, encKey, projName){
  url <- paste("https://api.economy.com/scenario-studio/v1/project/", sep="")
  
  print(url)
  timeStamp <- format(as.POSIXct(Sys.time()), "%Y-%m-%dT%H:%M:%SZ", tz="UTC")
  hashMsg   <- paste(accKey, timeStamp, sep="")
  signature <- hmac(encKey, hashMsg, "sha256")
  
  Sys.sleep(1)

  GET(url, httr::add_headers("AccessKeyId" = accKey,
                             "Signature" = signature,
                             "TimeStamp" = timeStamp)) %>%
    content(.,as="text") %>%
    fromJSON() %>%
    filter(title == projName) %>%
    select(id) %>%
    as.character() %>%
  return()
}
        getProjId(ACC_KEY,ENC_KEY, 
                  projName = "API dev") %>% 
          View()


### Function to get info about contents of specific project (by name of Project) ###
getProjInfo <- function(accKey, encKey, projName, infoPiece=""){

  
  url <- paste("https://api.economy.com/scenario-studio/v1/project/", sep="")
  print(url)
  
  timeStamp <- format(as.POSIXct(Sys.time()), "%Y-%m-%dT%H:%M:%SZ", tz="UTC")
  hashMsg   <- paste(accKey, timeStamp, sep="")
  signature <- hmac(encKey, hashMsg, "sha256")
  
  Sys.sleep(1)
  GET(url, httr::add_headers("AccessKeyId" = accKey,
                             "Signature" = signature,
                             "TimeStamp" = timeStamp)) %>%
    content(.,as="text") %>%
    fromJSON() %>%
    filter(title == projName) %>%
    select(id) %>%
    as.character() -> projId
    
  infoPiece <- ifelse(infoPiece =="series checked out", "series/checked-out",infoPiece)
  url <- paste("https://api.economy.com/scenario-studio/v1/project/",projId,"/",infoPiece, sep="")
  print(url)
  
  timeStamp <- format(as.POSIXct(Sys.time()), "%Y-%m-%dT%H:%M:%SZ", tz="UTC")
  hashMsg   <- paste(accKey, timeStamp, sep="")
  signature <- hmac(encKey, hashMsg, "sha256")
  Sys.sleep(1)
  
  GET(url, httr::add_headers("AccessKeyId" = accKey,
                             "Signature" = signature,
                             "TimeStamp" = timeStamp)) %>%
  
    content(.,as="text") %>%
    fromJSON() %>%
    return()
  
  
}
    fullProj <- getProjInfo(ACC_KEY, ENC_KEY,
                            projName="API dev") 
    
    # Example: Get scenarios in project from getProjInfo() function
          getProjInfo(ACC_KEY,ENC_KEY, 
                      projName = "API dev", 
                      infoPiece = "scenario") %>% 
            View()
        
    
    # Example: Get series in project from getProjInfo() function
          getProjInfo(ACC_KEY,ENC_KEY, 
                      projName = "API dev",
                      infoPiece = "series") %>% 
            View()
        
    # Example: Get series checked out in project from getProjInfo() function
          getProjInfo(ACC_KEY, ENC_KEY, 
                      projName = "API dev", 
                      infoPiece = "series checked out") %>% 
            View()


          
          
          
### function to get info about specific scenario (by name of project and scenario) ###
getScenInfo <- function(accKey, encKey, projName, scenName, infoPiece=""){
  url <- paste("https://api.economy.com/scenario-studio/v1/project/", sep="")
  print(url)
  
  timeStamp <- format(as.POSIXct(Sys.time()), "%Y-%m-%dT%H:%M:%SZ", tz="UTC")
  hashMsg   <- paste(accKey, timeStamp, sep="")
  signature <- hmac(encKey, hashMsg, "sha256")
  Sys.sleep(1)
  GET(url, httr::add_headers("AccessKeyId" = accKey,
                             "Signature" = signature,
                             "TimeStamp" = timeStamp)) %>%
    content(.,as="text") %>%
    fromJSON() %>%
    filter(title == projName) %>%
    select(id) %>%
    as.character() -> projId
  

  url <- paste("https://api.economy.com/scenario-studio/v1/project/",projId,"/scenario", sep="")
  print(url)
  
  timeStamp <- format(as.POSIXct(Sys.time()), "%Y-%m-%dT%H:%M:%SZ", tz="UTC")
  hashMsg   <- paste(accKey, timeStamp, sep="")
  signature <- hmac(encKey, hashMsg, "sha256")

  GET(url, httr::add_headers("AccessKeyId" = accKey,
                             "Signature" = signature,
                             "TimeStamp" = timeStamp)) %>%
    content(.,as="text") %>%
    fromJSON() %>%
    filter(title == scenName | alias == scenName) %>%
    select(id) %>%
    as.character() -> scenId  
  
  infoPiece <- ifelse(infoPiece =="series checked out", "series/checked-out",infoPiece)
  url <- paste("https://api.economy.com/scenario-studio/v1/project/",projId,"/scenario/", scenId,"/",infoPiece, sep="")
  print(url)
  
  timeStamp <- format(as.POSIXct(Sys.time()), "%Y-%m-%dT%H:%M:%SZ", tz="UTC")
  hashMsg   <- paste(accKey, timeStamp, sep="")
  signature <- hmac(encKey, hashMsg, "sha256")
  Sys.sleep(1)
  GET(url, httr::add_headers("AccessKeyId" = accKey,
                             "Signature" = signature,
                             "TimeStamp" = timeStamp)) %>%
    content(.,as="text") %>%
    fromJSON() %>%
    data.frame() %>% 
    return()
  
  
}
          getScenInfo(ACC_KEY,ENC_KEY,
                      projName = "API dev",
                      scenName = "a2") %>% 
            View()




### Function to get particular series within a particular project and scenario 
###     (by name of project and scenario and variable) ###
getSeriesInfo <- function(accKey, encKey, projName, scenName, variable, infoPiece=""){
  url <- paste("https://api.economy.com/scenario-studio/v1/project/", sep="")
  
  print(url)
  timeStamp <- format(as.POSIXct(Sys.time()), "%Y-%m-%dT%H:%M:%SZ", tz="UTC")
  hashMsg   <- paste(accKey, timeStamp, sep="")
  signature <- hmac(encKey, hashMsg, "sha256")
  
  Sys.sleep(1)
  GET(url, httr::add_headers("AccessKeyId" = accKey,
                             "Signature" = signature,
                             "TimeStamp" = timeStamp)) %>%
    content(.,as="text") %>%
    fromJSON() %>%
    filter(title == projName) %>%
    select(id) %>%
    as.character() -> projId
  
  url <- paste("https://api.economy.com/scenario-studio/v1/project/",projId,"/scenario", sep="")
  print(url)
  
  timeStamp <- format(as.POSIXct(Sys.time()), "%Y-%m-%dT%H:%M:%SZ", tz="UTC")
  hashMsg   <- paste(accKey, timeStamp, sep="")
  signature <- hmac(encKey, hashMsg, "sha256")
  Sys.sleep(1)
  GET(url, httr::add_headers("AccessKeyId" = accKey,
                             "Signature" = signature,
                             "TimeStamp" = timeStamp)) %>%
    content(.,as="text") %>%
    fromJSON() %>%
    filter(title == scenName | alias == scenName) %>%
    select(id) %>%
    as.character() -> scenId  
  
  infoPiece <- ifelse(infoPiece =="series checked out", "series/checked-out",infoPiece)
  url <- paste("https://api.economy.com/scenario-studio/v1/project/",projId,"/scenario/", scenId,"/series/", variable,"/",infoPiece, sep="")
  print(url)

  timeStamp <- format(as.POSIXct(Sys.time()), "%Y-%m-%dT%H:%M:%SZ", tz="UTC")
  hashMsg   <- paste(accKey, timeStamp, sep="")
  signature <- hmac(encKey, hashMsg, "sha256")
  Sys.sleep(1)
  GET(url, httr::add_headers("AccessKeyId" = accKey,
                                            "Signature" = signature,
                                            "TimeStamp" = timeStamp)) %>%
    content(.,as="text") %>%
    fromJSON() %>%
    return()
  
  
}
          getSeriesInfo(ACC_KEY,ENC_KEY,
                        projName = "API dev",
                        scenName = "a2", 
                        variable="FIP_IEST")  -> fip_iest_a2
        
          ### Example to get equation specs of specific series in scenario (by name of project, scenario, var)
            getSeriesInfo(ACC_KEY,ENC_KEY,
                          projName = "API dev",
                          scenName = "a2", 
                          variable="FIP_IEST", 
                          infoPiece = "equation") %>%
              View()
        ### Example to get equation stats of specific series in scenario (by name of project, scenario, var)
            getSeriesInfo(ACC_KEY,ENC_KEY,
                          projName = "API dev",
                          scenName = "a2", 
                          variable="FIP_IEST", 
                          infoPiece = "equation-stats") %>%
              View()
        ### Example to get dependencies of specific series in scenario (by name of project, scenario, var)
            getSeriesInfo(ACC_KEY,ENC_KEY,
                          projName = "API dev",
                          scenName = "a2", 
                          variable="FIP_IEST", 
                          infoPiece = "dependencies") %>%
              View()        
        ### Example to get rhs of specific series in scenario (by name of project, scenario, var)
            getSeriesInfo(ACC_KEY,ENC_KEY,
                          projName = "API dev",
                          scenName = "a2", 
                          variable="FIP_IEST", 
                          infoPiece = "rhs") %>%
              View() 
        ### Example to get full metadata of specific series in scenario (by name of project, scenario, var)
            getSeriesInfo(ACC_KEY,ENC_KEY,
                          projName = "API dev",
                          scenName = "a2", 
                          variable="FIP_IEST", 
                          infoPiece = "meta") %>%
              View() 
        
     
        
##### Function to get Series Data (as xts object) and Metadata of data series in scenario 
###     (by proj name, scen name, variable name)        
###     output is list of two objects: xts time series data, metadata

getSeriesData <- function(accKey, encKey, projName, scenName, variable, dataLocation = "central"){
    url <- paste("https://api.economy.com/scenario-studio/v1/project/", sep="")
    print(url)
    
    timeStamp <- format(as.POSIXct(Sys.time()), "%Y-%m-%dT%H:%M:%SZ", tz="UTC")
    hashMsg   <- paste(accKey, timeStamp, sep="")
    signature <- hmac(encKey, hashMsg, "sha256")
    Sys.sleep(1)
    GET(url, httr::add_headers("AccessKeyId" = accKey,
                               "Signature" = signature,
                               "TimeStamp" = timeStamp)) %>%
    content(.,as="text") %>%
    fromJSON() %>%
    filter(title == projName) %>%
    select(id) %>%
    as.character() -> projId
          
    url <- paste("https://api.economy.com/scenario-studio/v1/project/",projId,"/scenario", sep="")
    print(url)
          
    timeStamp <- format(as.POSIXct(Sys.time()), "%Y-%m-%dT%H:%M:%SZ", tz="UTC")
    hashMsg   <- paste(accKey, timeStamp, sep="")
    signature <- hmac(encKey, hashMsg, "sha256")
    Sys.sleep(1)
    GET(url, httr::add_headers("AccessKeyId" = accKey,
                               "Signature" = signature,
                               "TimeStamp" = timeStamp)) %>%
    content(.,as="text") %>%
    fromJSON() %>%
    filter(title == scenName | alias == scenName) %>%
    select(id) %>%
    as.character() -> scenId  
          

   url <- paste("https://api.economy.com/scenario-studio/v1/project/",projId,"/scenario/",
                scenId,"/data-series/", variable,"/data/", dataLocation ,sep="")
   print(url)
          
   timeStamp <- format(as.POSIXct(Sys.time()), "%Y-%m-%dT%H:%M:%SZ", tz="UTC")
   hashMsg   <- paste(accKey, timeStamp, sep="")
   signature <- hmac(encKey, hashMsg, "sha256")
   Sys.sleep(1)
   GET(url, httr::add_headers("AccessKeyId" = accKey,
                              "Signature" = signature,
                              "TimeStamp" = timeStamp)) %>%
   content(.,as="text") %>%
   fromJSON() -> seriesMetadata
   
   dates =   seq(from=as.Date(seriesMetadata$startDate), 
                 to=as.Date(seriesMetadata$endDate),
                 length.out = seriesMetadata$data$periods)
   
   xts_data = xts(as.numeric(seriesMetadata$data$data),dates) 
   outputList = list(seriesMetadata,xts_data) 
                     
   
    names(outputList) <- c(paste(variable, "_MetaData", sep=""),
                         paste(variable,"_xtsData", sep=""))
   
     
    return(outputList)
          
 }        
                      
      ### Example showing how to return time series data from series in scenario
        getSeriesData(ACC_KEY,ENC_KEY,
                      projName = "API dev",
                      scenName = "a2",
                      variable = "FIP_IEST") -> fip_iest_a2_data
        
        fip_iest_a2_data$FIP_IEST_xtsData %>% 
          View()
            
      ### Example showing how to return metadata of series in scenario
        getSeriesData(ACC_KEY,ENC_KEY,
                      projName = "API dev",
                      scenName = "a2",
                      variable = "FIP_IEST") -> fip_iest_a2_data 
        
        fip_iest_a2_data$FIP_IEST_MetaData %>% 
          View()

        
        
        
        
        
#### Get Multi-Series Data from project (by project name and Mnemonic List #########
 getMultiSeriesData <- function(accKey, encKey, projName, mnemonicList, dataLocation = "central"){
   
   
    url <- paste("https://api.economy.com/scenario-studio/v1/project/", sep="")
    print(url)
          
    timeStamp <- format(as.POSIXct(Sys.time()), "%Y-%m-%dT%H:%M:%SZ", tz="UTC")
    hashMsg   <- paste(accKey, timeStamp, sep="")
    signature <- hmac(encKey, hashMsg, "sha256")
    Sys.sleep(1)
    GET(url, httr::add_headers("AccessKeyId" = accKey,
                               "Signature" = signature,
                               "TimeStamp" = timeStamp)) %>%
    content(.,as="text") %>%
    fromJSON() %>%
    filter(title == projName) %>%
    select(id) %>%
    as.character() -> projId
          
    url <- paste("https://api.economy.com/scenario-studio/v1/project/",projId,
                 "/data-series?expressions=",mnemonicList,sep="")
    
    
    print(url)
          
    timeStamp <- format(as.POSIXct(Sys.time()), "%Y-%m-%dT%H:%M:%SZ", tz="UTC")
    hashMsg   <- paste(accKey, timeStamp, sep="")
    signature <- hmac(encKey, hashMsg, "sha256")
    Sys.sleep(1)
    GET(url, httr::add_headers("AccessKeyId" = accKey,
                               "Signature" = signature,
                               "TimeStamp" = timeStamp)) %>%
    content(.,as="text") %>%
    fromJSON() -> multiSeriesResponse
          
    
    
    multiSeriesMetadata <- list(multiSeriesResponse)
    outputList <- list()
    outputList <- c(outputList,list(multiSeriesMetadata))
    
    for(series in seq(1:length(multiSeriesResponse$mnemonic))){
      
      multiSeriesResponse$data$data[[series]] 
      multiSeriesResponse$startDate[[series]]
      multiSeriesResponse$endDate[[series]]
      multiSeriesResponse$data$periods[[series]]
                                    
      
      dates =   seq(from=as.Date(multiSeriesResponse$startDate[[series]]),
                    to=as.Date(multiSeriesResponse$endDate[[series]]),
                    length.out = multiSeriesResponse$data$periods[[series]])
      values =  multiSeriesResponse$data$data[[series]]
      
      
      xts_data =  xts(as.numeric(values),dates) 
      outputList <- c(outputList,list(xts_data))
      

      
      
    }    
    names(outputList) <-   c("MetaData", multiSeriesResponse$mnemonic)
    
          
    return(outputList)
          
}        
    
        
      ### Example to pull multiple series from project
      getMultiSeriesData(ACC_KEY, ENC_KEY,
                         projName="API dev",
                         mnemonicList="a1.FIP_IEST;a1.FABAAIVOL_I_US;a2.FRGT10Y_IJPN")-> multiSeriesPull
        
        ### Extract Metadata from multiSeriesPull
              multiSeriesPull$MetaData %>% .[[1]] %>% View()
        ### Extract series from multiSeriesPull
              multiSeriesPull$a1.FIP_IEST %>% View()
        ### Extract another series from multiSeriesPull
              multiSeriesPull$a1.FABAAIVOL_I_US %>% View()
              