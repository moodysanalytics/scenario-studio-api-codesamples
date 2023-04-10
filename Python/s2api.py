# -*- coding: utf-8 -*-
"""
Library for executing commands via Scenario Studio v2 API
https://api.economy.com/scenario-studio/v2/swagger/ui/index
"""

import os
import json
import datetime
import hmac
import hashlib
import requests
import time
import pandas as pd
import urllib.parse

class BaseAPI:
    def __init__(self,acc_key:str,enc_key:str,oauth:bool = True, proxies={}, debug:bool=False):
        self._base_uri = 'https://api.economy.com'
        self._acc_key = acc_key
        self._enc_key = enc_key
        self._token = 'bearer None'
        self._oauth = oauth
        self._proxies = proxies
        self._debug = debug
        
    def get_oauth_token(self):
        access_key = self._acc_key
        private_key = self._enc_key
        url = f'{self._base_uri}/oauth2/token'
        head = {'Content-Type':'application/x-www-form-urlencoded'}
        data = f'client_id={access_key}&client_secret={private_key}&grant_type=client_credentials'
        r = requests.post(url=url,headers=head,data=data)
        status = r.status_code
        response = r.text
        jobj = json.loads(response)
        if status == 200:
            return f'{jobj["token_type"]} {jobj["access_token"]}'
        else:
            raise Exception(f'Error - Status : {status}, Msg: {response}')
            
    def get_hmac_header(self):
        timeStamp = datetime.datetime.strftime(
            datetime.datetime.utcnow(), "%Y-%m-%dT%H:%M:%SZ")
        payload = bytes(self._acc_key + timeStamp, "utf-8")
        signature = hmac.new(bytes(self._enc_key,"utf-8"), payload, digestmod=hashlib.sha256)    
        head = {'AccessKeyId':self._acc_key,'Signature':signature.hexdigest(),
                'Content-Type':'application/json','timestamp':timeStamp}
        return head

    def request(self, method:str, url:str, payload={}, max_tries:int=5):
        status = 0
        tries = 0
        ret = {}
        if self._oauth:
            if self._token == 'bearer None':
                self._token = self.get_oauth_token()
        while (not ((status == 200) or ((status == 304) and (method.lower().strip() == "put")))) and (tries < max_tries+1):
            if self._oauth:
                head = {'Authorization':self._token}
            else:
                head = self.get_hmac_header()
            head['Content-Type'] = 'application/json'
            head['Accept'] = 'application/json'
            if method.lower().strip() == "get":
                r = requests.get(url=url,headers=head,proxies=self._proxies)
            elif method.lower().strip() == "post": 
                if type(payload) is list or type(payload) is dict:
                    r = requests.post(url=url,headers=head,json=payload,proxies=self._proxies)
                else:
                    r = requests.post(url=url,headers=head,data=payload,proxies=self._proxies)
            elif method.lower().strip() == "put": 
                if type(payload) is list or type(payload) is dict:
                    r = requests.put(url=url,headers=head,json=payload,proxies=self._proxies)
                else:
                    r = requests.put(url=url,headers=head,data=payload,proxies=self._proxies)
            else:
                print(f'Error - method {method} not recognized')
                return {}
            tries = tries + 1
            status = r.status_code
            response = r.text
            if status == 429:
                print("Too many requests, wait 10 seconds and try again...")
                time.sleep(10)
            elif self._oauth and (status == 401):
                print(self._token,status,response)
                print("Get a new oauth token")
                self._token = self.get_oauth_token()
            elif (status == 200) or ((status == 304) and (method.lower().strip() == "put")):
                if len(response)>0:
                    ret = json.loads(response)
                else:
                    ret = response
            else:
                print(f'Error - Status : {status}, Msg : {response}')
                print(f'   URL: {url}')
            if self._debug:
                print(f'{status} : {url}')
        return ret

class ScenarioStudioAPI(BaseAPI):
    def __init__(self,acc_key:str,enc_key:str,oauth:bool = True,proxies={},debug:bool=False):
        super().__init__(acc_key,enc_key,oauth,proxies,debug)
        self._base_uri = 'https://api.economy.com/scenario-studio/v2'

    def get_pandas_freq(self, freq:int):
        pandas_freq = 'Q-DEC'
        if freq == 172:
            pandas_freq = 'Q-DEC'
        if freq == 204:
            pandas_freq = 'A-DEC'
        elif freq == 128:
            pandas_freq = 'M'
        return pandas_freq

    def get_project_list(self):
        url = f'{self._base_uri}/project'
        ret = self.request(url=url,method="get")
        return ret
    
    def search_projects(self,tags:list=None,terms:list=None):
        url = f'{self._base_uri}/project/search?options.sortBy=-created'
        if tags is not None:
            for tag in tags:
                url = f'{url}&options.tags={tag}'
        if terms is not None:
            for term in terms:
                url = f'{url}&options.terms={term}'
        ret = self.request(url=url,method="get")
        return ret
    
    def get_project_info(self, project_id:str):
        url = f'{self._base_uri}/project/{project_id}'
        ret = self.request(url=url,method="get")
        return ret

    def get_scenario_info(self, project_id:str, scenario_id:str):
        url = f'{self._base_uri}/project/{project_id}/scenario/{scenario_id}'
        ret = self.request(url=url,method="get")
        return ret

    def get_project_scenarios(self, project_id:str):
        url = f'{self._base_uri}/project/{project_id}/scenario'
        ret = self.request(url=url,method="get")
        return ret

    def get_project_series(self, project_id:str):
        url = f'{self._base_uri}/project/{project_id}/series'
        ret = self.request(url=url,method="get")
        return ret

    def make_project(self, title:str, tags:list=[], description:str=""):
        url = f'{self._base_uri}/project/create'
        pl = {'title': title, 'tags': tags, 'description': description}
        ret = self.request(url=url,method="post",payload=pl)
        return ret

    def build_project(self, project_id:str):
        url = f'{self._base_uri}/project/{project_id}/build'
        ret = self.request(url=url,method="post")
        return ret

    def get_base_scenario_list(self, model_types:list=[], terms:list=[], vintages:list=[], sort_by:str=""):
        url = f'{self._base_uri}/base-scenario/search'
        pl = {}
        if len(model_types) > 0:
            pl['modelTypes'] = model_types
        if len(terms) > 0:
            pl['terms'] = terms
        if len(vintages) > 0:
            pl['vintages'] = vintages
        if len(sort_by) > 0:
            pl['sortBy'] = sort_by
        ret = self.request(url=url,method="post",payload=pl)
        return ret

    def get_base_scenario_count(self, model_types:list=[], terms:list=[], vintages:list=[]):
        url = f'{self._base_uri}/base-scenario/search/count'
        pl = {}
        if len(model_types) > 0:
            pl['modelTypes'] = model_types
        if len(terms) > 0:
            pl['terms'] = terms
        if len(vintages) > 0:
            pl['vintages'] = vintages
        ret = self.request(url=url,method="post",payload=pl)
        return ret

    def local_solve(self, project_id:str, scenario_id, partial:str=None):
        if type(scenario_id) is str:
            ids = [scenario_id]
        else:
            ids = scenario_id
        ret = []
        for id in ids:
            url = f'{self._base_uri}/project/{project_id}/scenario/{id}/solve/local'
            if partial is not None:
                pl = {'partial':partial}
                ret.append(self.request(url=url,method="post",payload=pl))
            else:
                ret.append(self.request(url=url,method="post"))
        return ret

    def central_solve(self, project_id:str, scenario_id):
        if type(scenario_id) is str:
            ids = [scenario_id]
        else:
            ids = scenario_id
        ret = []
        for id in ids:
            url = f'{self._base_uri}/project/{project_id}/scenario/{id}/solve/central'
            ret.append(self.request(url=url,method="post"))
        return ret

    def get_base_scenario_info(self, scenario_id:str):
        url = f'{self._base_uri}/base-scenario/{scenario_id}'
        ret = self.request(url=url,method="get")
        return ret

    def clone_scenario(self, project_id: str, scenario_id: str, alias:str, title:str=None, description:str=None, edit_start:int=None, forecast_end:int=None):
        pl = self.get_base_scenario_info(scenario_id)
        url = f'{self._base_uri}/project/{project_id}/scenario/clone'
        pl['alias'] = alias
        if title is not None:
            pl['title'] = title
        if description is not None:
            pl['description'] = description
        if edit_start is not None:
            pl['editStart'] = edit_start
        if forecast_end is not None:
            pl['forecastEnd'] = forecast_end
        ret = self.request(url=url,method="post",payload=pl)
        return ret
    
    def add_read_only_scenario(self, project_id: str, scenario_id: str, alias: str):
        url = f'{self._base_uri}/project/{project_id}/scenario/copy'
        pl = {'alias':alias,'id':scenario_id}
        ret = self.request(url=url,method="post",payload=pl)
        return ret
    
    def order_status(self, project_id:str, orderId:str, build:bool=False):
        url = f'{self._base_uri}/project/{project_id}/order/{orderId}'
        if build:
            url = f'{url}/build'
        ret = self.request(url=url,method="get")
        return ret

    def get_series_data(self, project_id:str, series_list:list, freq:int=172, transformation:int=None, batch:int=100, start:int=None, end:int=None, dates=None):
        url = f'{self._base_uri}/project/{project_id}/data-series?frequency={freq}'
        if transformation is not None:
            url = f'{url}&transformation={transformation}'
        if start is not None:
            url = f'{url}&start={start}'
        if end is not None:
            url = f'{url}&end={end}'
        ret = {}
        for i in range(0,len(series_list),batch):
            pl = series_list[i:i+batch]
            series_objs = self.request(url=url,method="post",payload=pl)
            for series_obj in series_objs:
                if series_obj['status'].upper().strip() == 'OK':
                    pandas_freq = self.get_pandas_freq(series_obj['data']['freqCode'])
                    index = pd.period_range(pd.Period(series_obj['data']['startDate'],pandas_freq),periods=series_obj['data']['periods'])
                    series = pd.Series(series_obj['data']['data'],index)
                    series[abs(series) > 1.7e+38] = None
                    if dates is not None:
                        series = series.reindex(dates)
                    if series_obj['lastHistory'] != "N/A":
                        series.last_hist = pd.Period(series_obj['lastHistory'],pandas_freq)
                    series.description = series_obj['description']
                    series.geo = series_obj['geoCode']
                    ret[series_obj['mnemonic']] = series
        return ret

    def wait_for_orders(self, project_id:str, orders:list, build:bool=False, sleep:int=5):
        ret = []
        for o in orders:
            status = self.order_status(project_id, o['orderId'], build)
            orderDone = status['finished']
            while not orderDone:
                time.sleep(sleep)
                status = self.order_status(project_id, o['orderId'], build)
                orderDone = status['finished']
            ret.append(status)
        return ret

    def claim(self, project_id:str, scenario_id:str, variables:list, exogenize:bool=False):
        url = f'{self._base_uri}/project/{project_id}/scenario/{scenario_id}/series/checkout?exogenize={exogenize}'
        pl = [x.upper() for x in variables]
        ret = self.request(url=url,method="post",payload=pl)
        return ret
    
    def get_claim_list(self, project_id:str):
        url = f'{self._base_uri}/project/{project_id}/series/checked-out'
        ret = self.request(url=url,method="get")
        return ret

    def release(self, project_id:str, scenario_id:str, variables:list):
        url = f'{self._base_uri}/project/{project_id}/scenario/{scenario_id}/series/checkin'
        pl = [x.upper() for x in variables]
        ret = self.request(url=url,method="post",payload=pl)
        return ret

    def push(self, project_id:str, scenario_id:str, variables:list, note:str=None):
        url = f'{self._base_uri}/project/{project_id}/scenario/{scenario_id}/series/commit'
        pl = {'variables': [x.upper() for x in variables]}
        if note is not None:
            pl['note'] = note
        ret = self.request(url=url,method="post",payload=pl)
        return ret

    def endogenize(self, project_id:str, scenario_id:str, variables:list):
        url = f'{self._base_uri}/project/{project_id}/scenario/{scenario_id}/series/endogenizeBulk'
        pl = [x.upper() for x in variables]
        ret = self.request(url=url,method="put",payload=pl)
        return ret

    def exogenize(self, project_id:str, scenario_id:str, variables:list):
        url = f'{self._base_uri}/project/{project_id}/scenario/{scenario_id}/series/exogenize'
        pl = [x.upper() for x in variables]
        ret = self.request(url=url,method="put",payload=pl)
        return ret

    def exogenize_through(self, project_id:str, scenario_id:str, variables:list, date:int):
        url = f'{self._base_uri}/project/{project_id}/scenario/{scenario_id}/series/exogenize-through'
        pl = {'variables': [x.upper() for x in variables], 'exogenizeThrough': date}
        ret = self.request(url=url,method="put",payload=pl)
        return ret

    def write_series_data(self, project_id:str, scenario_id:str, variable:str, data):
        url = f'{self._base_uri}/project/{project_id}/scenario/{scenario_id}/data-series/{variable.upper()}/data/local'
        pl = {}
        pl['startDate'] = (data.index[0]-pd.Period('1849-12-31',data.index.freq)).n
        pl['data'] = [x for x in data]
        ret = self.request(url=url,method="put",payload=pl)
        return ret

    def edit_project_settings(self, project_id:str, edit_identities:bool=None, require_comments:bool=None, edit_equations:bool=None, allow_custom_variables:bool=None, databuffet_alias:str=None):
        pl = self.get_project_info(project_id)
        url = f'{self._base_uri}/project/{project_id}/settings'
        if edit_identities is not None:
            pl['varTypesLockStatus']['1'] = not edit_identities
        if require_comments is not None:
            pl['commentRequired'] = require_comments
        if edit_equations is not None:
            pl['allowEquationEditing'] = edit_equations
        if allow_custom_variables is not None:
            pl['allowCustomSeries'] = allow_custom_variables
        if databuffet_alias is not None:
            pl['alias'] = f'S2PRJ_{databuffet_alias}'
        ret = self.request(url=url,method="put",payload=pl)
        return ret

    def edit_scenario_settings(self, project_id:str, scenario_id:str, description:str=None, edit_start:int=None, forecast_end=None):
        pl = self.get_base_scenario_info(project_id, scenario_id)
        if description is not None:
            pl['description'] = description
        if edit_start is not None:
            pl['editStart'] = edit_start
        if forecast_end is not None:
            pl['forecastEnd'] = forecast_end
        url = f'{self._base_uri}/project/{project_id}/scenario/{scenario_id}'
        ret = self.request(url=url,method="put",payload=pl)
        return ret

    def search_series(self, project_id:str, scenario_ids:list=None, geos:list=None, state=None, query:str="", checked_out:int=None, variable_type:list=None, sharedown=None):
        pl = {}
        pl['query'] = query
        pl['state'] = state
        pl['checkedOut'] = checked_out
        pl['variableType'] = variable_type
        if scenario_ids is None:
            scensInfo = self.get_project_scenarios(project_id)
            pl['scenarioId'] = [x['id'] for x in scensInfo]
        else:
            pl['scenarioId'] = scenario_ids
        if geos is not None:
            pl['geographies'] = geos
        if sharedown is not None:
            pl['sharedown'] = sharedown
        url = f'{self._base_uri}/project/{project_id}/search/count'
        count = self.request(url=url,method="post",payload=pl)
        if count > 0:
            url = f'{self._base_uri}/project/{project_id}/search/results?skip=0&take={count}'
            ret = self.request(url=url,method="post",payload=pl)
        else:
            ret = []
        return ret

    def get_sharedown_info(self, project_id:str, scenario_id:str, variable:str):
        url = f'{self._base_uri}/project/{project_id}/scenario/{scenario_id}/series/{variable}/sharedown'
        ret = self.request(url=url,method="get")
        return ret

    def sharedown_solve(self, project_id:str, scenario_id:str, variable:str):
        url = f'{self._base_uri}/project/{project_id}/scenario/{scenario_id}/series/{variable}/sharedown'
        ret = [self.request(url=url,method="post")]
        return ret

    def get_pushed_series(self, project_id:str, scenario_id:str):
        url = f'{self._base_uri}/audit/project/{project_id}?options.actions=4&options.scenarios={scenario_id}'
        ret = self.request(url=url,method="get")
        return ret

    def set_user_permission(self, project_id:str, emails:list, role:int):
        users = self.get_user_universe()
        url = f'{self._base_uri}/project/{project_id}/contributor/{role}'
        pl = []
        for email in emails:
            sids = [x['sid'] for x in users if email.lower() == x['email'].lower()]
            if len(sids) > 0:
                pl.append({'sid':sids[0], 'role':role})
        ret = self.request(url=url,method="put",payload=pl)
        return ret

    def get_user_universe(self):
        url = f'{self._base_uri}/group/client'
        ret = self.request(url=url,method="get")
        return ret

    def edit_equation(self,project_id:str, scenario_id:str, variable:str, equation:str):
        url = f'{self._base_uri}/project/{project_id}/scenario/{scenario_id}/series/{variable}/equation'
        pl = "'"+urllib.parse.quote(equation)+"'"
        ret = self.request(url=url,method="put",payload=pl)
        return ret

    def clear_add_factors(self, project_id:str, scenario_id:str, variables:list):
        url = f'{self._base_uri}/project/{project_id}/scenario/{scenario_id}/data-series/add-factor/local'
        pl = [x.upper()+"_A" for x in variables]
        ret = self.request(url=url,method="put",payload=pl)
        return ret

    def add_custom_variable(self, project_id:str, scenario_id:str, variable:str, data, variable_type:int=0, equation:str=None, observed:str="AVERAGED", last_hist:int=None, title:str="", units:str="", source:str="", add_factor_type:int=2):
        url = f'{self._base_uri}/project/{project_id}/scenario/{scenario_id}/series/custom'
        pl = {}
        pl['variable'] = variable
        pl['observedAttribute'] = observed
        pl['title'] = title
        pl['units'] = units
        pl['source'] = source
        pl['startDate'] = (data.index[0]-pd.Period('1849-12-31',data.index.freq)).n
        if last_hist is None:
            pl['lastHistorical'] = (data.index[-1]-pd.Period('1849-12-31',data.index.freq)).n
        else:
            pl['lastHistorical'] = last_hist
        pl['equation'] = equation
        pl['data'] = [x for x in data]
        pl['addFactorType'] = add_factor_type
        pl['variableType'] = variable_type
        ret = self.request(url=url,method="post",payload=[pl])
        return ret

    def set_lasthist(self, project_id:str, scenario_id:str, variable:str, lasthist: int):
        url = f'{self._base_uri}/project/{project_id}/scenario/{scenario_id}/series/{variable}/historical/{lasthist}'
        ret = self.request(url=url,method="put")
        return ret