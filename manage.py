# Let's just import EVERYTHING!
import sqlite3
from requests    import get
from requests.utils import quote as urlencode
from requests.exceptions import RequestException
import re
from unicodedata import normalize
import logging
import sys
from glob        import glob
from time        import sleep
from time        import time as now

__version__ = '1.0.2'

API_KEY = open('apikey', 'r').read().rstrip()
LOG_NAME = 'watch_manage.log'
DB_NAME = 'funboxmedia.db'
OMDB_URL = 'https://www.omdbapi.com?apikey=%s&t=%s&y=%s'

# Configure logging. There's probably a better way to do this, but bite me.
logging.getLogger('urllib3').setLevel(logging.WARNING)
logging.basicConfig(
	filename=LOG_NAME,
	level=logging.INFO,
	format='%(asctime)s %(levelname)-8s %(message)s',
	datefmt='%Y-%m-%d %H:%M:%S'
)

def log(message):
	logging.info(message)
	if len(sys.argv) > 1 and sys.argv[1] == '-v':
		print(message)
	
def warn(message):
	logging.warn(message)
	print(message, file=sys.stderr)


# Get database handle
db_conn = sqlite3.connect(DB_NAME)
dbh = db_conn.cursor()

# Verify that the database has the proper tables
# (Well, table -- there's only one)
dbh.execute('''CREATE TABLE IF NOT EXISTS media (
	filename        TEXT UNIQUE,
	filenameyear    INTEGER,
	imdbid          TEXT,
	title           TEXT,
	titlenormalized TEXT,
	year            TEXT,
	runtime         TEXT,
	genre           TEXT,
	director        TEXT,
	actors          TEXT,
	shortplot       TEXT,
	fullplot        TEXT,
	poster          TEXT,
	metascore       INTEGER,
	imdbrating      REAL,
	type            TEXT,
	dateadded       INTEGER
)''')

# Get list of movies and shows not in the database, filtering out
# subtitles and old converted files.
# Note: Our filenames include the relative path ('TV' or 'movies').
dbh.execute('SELECT filename FROM media order by titlenormalized')
db_entries = set([x[0] for x in dbh.fetchall()]) # Unpack the row tuples

media_files = set(glob(u'TV/*') + glob(u'movies/*'))
ignore_list = {'movies/subtitles', 'movies/old'}

unmatched_media = list(media_files - db_entries - ignore_list)


# Extracts title and year. See https://regex101.com/r/v0WgQY/3
extractor = re.compile(r'(?:\w*)\/(.+) \((\d+)\)', re.UNICODE)

# Selects all non-word, non-space chars. See https://regex101.com/r/LLUotS/1
normalizer = re.compile(r'([^\w\s])')

# Selects all groups of spaces
space_collapser = re.compile(r'\s+')

# Query OMDB for info on the unmatched media, then add new records.
for path in unmatched_media:
	try:
		title, year = extractor.search(path).groups()
	except:
		warn('%s is formatted wrong. Skipping.' % path)
		continue

	url = OMDB_URL % (API_KEY, urlencode(title), year)
	log('Fetching ' + url)

	try:
		# We need to make a second request to get the long version of the plot.
		# Don't ask me why, that's just how OMDB is.
		req1 = get(url, timeout=5)
		req2 = get(url + '&plot=full', timeout=5)
	except RequestException as e:
		# OMDB isn't working for some reason, so we'll try again next time.
		warn('OMDB error while looking up %s (%s). Skipping...\n\t %s'
			% (title, year, str(e)))
		continue
	except Exception as e:
		warn('Something went wrong, skipping... ' + str(e))
		continue

	# Create a limited record if OMDB doesn't have an entry.
	# Infuratingly, OMDB returns not-found errors in a 200, so our only
	# indication that the movie is not found is to check for 'Error'.
	if req1.json().get('Error'):
		# Create the record with OMDB fields nulled
		info = {}
		warn('No OMDB entry found for %s (%s)' % (title, year))
	else:
		info = req1.json()
		info['Fullplot'] = req2.json()['Plot']


	# Normalize title to only contain ascii word characters.
	# Ripped off from https://www.peterbe.com/plog/unicode-to-ascii
	title_normalized = normalize('NFKD', title).encode('ascii', 'ignore')
	title_normalized = title_normalized.decode('ascii')
	title_normalized = normalizer.sub('', title_normalized)
	title_normalized = space_collapser.sub(' ', title_normalized)

	# Enumerate values so this statement doesn't break if we update the table.
	dbh.execute('''INSERT INTO media (
		filename,
		filenameyear,
		imdbid,
		title,
		titlenormalized,
		year,
		runtime,
		genre,
		director,
		actors,
		shortplot,
		fullplot,
		poster,
		metascore,
		imdbrating,
		type,
		dateadded
	) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''', (
		# Use .get instead of brackets so unset values return None
		# instead of throwing a key error
		path,
		year,
		info.get('imdbID'),
		title,
		title_normalized,
		info.get('Year'),
		info.get('Runtime'),
		info.get('Genre'),
		info.get('Director'),
		info.get('Actors'),
		info.get('Plot'),
		info.get('Fullplot'), # We added this field ourselves
		info.get('Poster'),
		info.get('Metascore'),
		info.get('imdbRating'),
		info.get('Type'),
		int(now())
	))

	log('Added %s (%s) with imdbID %s' % (title, year, info.get('imdbID')))
	sleep(1) # Delay so we don't flood OMDB with requests

db_conn.commit()
db_conn.close()

