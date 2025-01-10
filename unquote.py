#!/bin/python3

#!/bin/python3
# Converts URL-encoded strings back into human-readable strings.
from urllib.parse import unquote
import sys

# URLs sometimes have multiple layers of encoding, so run until it's all gone.
def fullUnquote(value):
	modded = unquote(value)
	while modded != unquote(modded):
		modded = unquote(modded)
	return modded

# Handle args or stdin
if len(sys.argv) > 1:
	for value in sys.argv[1:]:
		print(fullUnquote(value))
else:
	value = sys.stdin.read()
	print(fullUnquote(value))

