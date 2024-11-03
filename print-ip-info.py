#!/usr/bin/env python3
import json
from urllib.request import urlopen

VERSION = '1.1'
ENDPOINT = 'https://wtfismyip.com/json'

try:
	info_json = urlopen('https://wtfismyip.com/json').read()
	info = json.loads(info_json)

	location = info['YourFuckingLocation']
	ip = info['YourFuckingIPAddress']

	print(f'{ip} ({location})')
except:
	print('Failed to fetch IP info. Your network (including VPN) may be disconnected.')

