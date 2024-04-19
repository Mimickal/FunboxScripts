#!/usr/bin/env python
from pathlib import Path
from sys import argv, exit

import requests

VERSION = '1.0'

password_file = Path.home() / '.config' / 'synadm_password'

try:
	with open(password_file, 'r') as f:
		password = f.read().strip()
except FileNotFoundError:
	print(f'Please paste your admin password in {password_file}')
	print('Remember to set the permissions to 600!')
	exit(1)

username = argv[1]

if not username:
	print(f'Usage: {argv[0]} <username>')
	exit(0)

response = requests.post('http://localhost:8008/_matrix/client/r0/login', json={
	'type': 'm.login.password',
	'identifier': {
		'type': 'm.id.user',
		'user': username,
	},
	'password': password,
	'initial_device_display_name': 'Local CLI',
})

if response.status_code == 200:
	token = response.json().get('access_token')
	print(f'Access Token: {token}')
else:
	print(response.text)

