# Scenario Studio v2 API Use Cases

## Introduction
Contained here are a collection of use cases, and how tos based on the Postman files found in the `./Postman` directory. Postman can be downloaded for free [from here](https://www.postman.com/).

Within the `./Postman` directory, you can find the file `S2.API-Examples.postman_collection.json`. This file contains a number of API endpoints, which can be imported into Postman as a collection.

`S2-api-examples.postman_environment.json` contains set of environment variables have been set up, but will need to be configured before making requests. To start, import this file as a new environment, and fill in `accessKeyId` and `privateKeyId` within the environment variables. Access key and private key values can be found under your [account settings on Economy.com](https://www.economy.com/myeconomy/api-key-info).

Authorization has also been configured for these requests. You will occassionally need to refresh your the bearer token by clicking Get New Access Token within the Authorization section of a Postman tab.

## Project Setup

### Create a New Project
Use the `create-project` end point. Note the options within the body. After project is created, note the value of the `id` field in the return JSON. This is the newly created `projectId`. It will be used in future requests. You can store it within the environment variables provided with the sames.

### Add a Moody's Scenario
You can pull the entire list of Moody's scenarios using the `base-scenarios` script. You can also you use the `base-scenarios-search`, and `base-scenario-search-count` endpoints. Once you've found the Id base scenario you want to add to a project, add it to the `baseScenarioId` environment variables, and then use the `base-scenario-details` endpoint to pull all information about the base scenario. Once this information is gathered, use the `scenario-clone` endpoint.

### Add an Existing Scenario
Search for a scenario within your projects using the `project-search` and `project-search-count` endpoints. Once you find the `scenarioId` you would like to add to your project, use the `base-scenarios-detail` endpoint to pull all information about the scenario. Once this information is gathered, use the `scenario-clone` endpoint. To add the scenario as a read reference scenario, use the `scenario-copy` endpoint.

### Build The Project
The build process is a server process and requires a number of steps to run in order for the build to complete. To start the build, use the `project-build` endpoint. Note the response from the `project-build` call, it should contain an array of orders. You will need to continue to query for the status of these orders until all of them have completed. You can use the `project-build-status` endpoint to find the status of a single order. You will know an order has completed once `finished` is `true`, `message` is `Success` and the `error` property is an empty string. Once the project is build, you should be able to use the `project` endpoint to pull information about the project.
