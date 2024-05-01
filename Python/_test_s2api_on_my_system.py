import sys
import os
try:
    import s2api
except Exception as ex:
    print(ex)
    print('Make sure s2api.py is downloaded to the same directory as this program, and run again')
    print('Get it here: https://github.com/moodysanalytics/scenario-studio-api-codesamples/blob/master/Python/s2api.py')
    sys.exit()

def prompt(prompt_text:str):
    ret = None
    while ret is None:
        ret = input(f'{prompt_text} : ').strip()
    return ret

print('\nGet your API heys here: https://economy.com/myeconomy/api-key-info\n')
access_key = prompt('Please enter your access key')
encryption_key = prompt('Please enter your encryption key')

try:
    # instantiate the api class
    print("Instantiating API ...")
    api = s2api.ScenarioStudioAPI(access_key,encryption_key)

    # check that you are properly connected to API
    print("Testing connection ...")
    health = api.health()
    print(f'API status: {health}')
    if ('HEALTHY' in health.upper()):
        print('[PASS] API successfully accessed')
    else:
        print('[FAIL] Connection health check failed')
except Exception as ex:
    print('[FAIL] Something did not work, see exception below:')
    print(f'Exception : {ex}')