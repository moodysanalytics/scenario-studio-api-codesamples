# Scenario Studio API v1 user guide

Scenario Studio API provides easy access to your project space in Scenario Studio (i.e. web-application for time-series models).  The API uses HMAC authentication and JSON responses, and the API doesn’t depend on client's operating system and programming language. [Here!](https://api.economy.com/scenario-studio/v1/swagger/ui/index#/) is the main website to access the API. For curl and request URL, go to the relevant tab and fill-in the details. To access the API, ```R``` and ```python``` codes are available in our GitHub page. Various data fields, that can be accessed from existing workspace, are mentioned below. To get project content, the client may have to provide few project details (depending on the data field) that are mentioned in curl brackets. The corresponding text indicates the project content that can be accessed using the API.

## DataSeries
- To get the central data for series
    - */project/{projectId}/scenario/{scenarioId}/data-series/{variableId}/data/central*


- To get the local data for series
    - */project/{projectId}/scenario/{scenarioId}/data-series/{variableId}/data/local*


- To get multiple series and/or expressions
    - */project/{projectId}/data-series*

## Health
- To get the health of the service
    - */health*

## Project
- To get the list of projects the user has access to
    - */project*


- To get information about a specific project
    - */project/{projectId}*


- To get the scenarios within a project
    - */project/{projectId}/scenario*


- To get the list of all series within a project
    - */project/{projectId}/series*


- To get the list of series checked out by the current user
    - */project/{projectId}/series/checked-out*


## Scenario
- To get information about a specific scenario
    - */project/{projectId}/scenario/{scenarioId}*


## Series
- To get information about a specific series
    - */project/{projectId}/scenario/{scenarioId}/series/{variableId}*


- To get the equation specification for a series
    - */project/{projectId}/scenario/{scenarioId}/series/{variableId}/equation*


- To get the equation statistics for a series
    - */project/{projectId}/scenario/{scenarioId}/series/{variableId}/equation-stats*
    

- To get the list of series that the current series depends on
    - */project/{projectId}/scenario/{scenarioId}/series/{variableId}/dependencies*
    

- To get the list of series that depend on the current series
    - */project/{projectId}/scenario/{scenarioId}/series/{variableId}/rhs*
    

- To get the full meta information (Equation Info, Equation Statistics, Dependencies, Rhs, etc)
    - */project/{projectId}/scenario/{scenarioId}/series/{variableId}/meta*
    

# Support

Please contact the Scenario Studio API team at Moody's Analytics by email at [help@economy.com](mailto:help@economy.com), with a subject line of "Scenario Studio API technical inquiry"

# License

This project is licensed under (c) 2019 Moody's Analytics, Inc. All rights reserved.