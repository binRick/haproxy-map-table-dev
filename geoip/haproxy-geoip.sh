#!/bin/bash

set -e -o pipefail 

DEFAULT_INFILE="http://geolite.maxmind.com/download/geoip/database/GeoIPCountryCSV.zip"
DEFAULT_CACHEFILE="/etc/haproxy/GeoIPCountryCSV.zip"

function usage()
{
	cat >&2 << EOF

Usage: $0 [-l] [-i <input file>] [<country code>...]

Options :
  -h              display this help and exit
  -l              applies a lowercase filter to the output
  -c <cachefile>  when using an HTTP URL, defines where the file will be cached
                    on disk. This prevents downloading a file that was not
                    modified
                    Default: $DEFAULT_CACHEFILE
  -i <infile>     the input file containing the GeOIP database.
                    it can be a local file or an HTTP URL. If the file name
                    ends with ".zip", it will be automatically unzipped
                    Default: $DEFAULT_INFILE

  <country code>  if specified, only those countries will be sent to the
                    output. If not specified, all of them will


Example :
$ $0 -l -i $DEFAULT_INFILE FR UK IT US
EOF
	exit 1
}

# Initialize the parameters from the command line
filters=""
infile=$DEFAULT_INFILE
cachefile=$DEFAULT_CACHEFILE
lowercase_opts=0
while getopts "c:i:hl" opt;
do
	case $opt in
		c) cachefile=$OPTARG;;
		i) infile=$OPTARG;;
		l) lowercase_opts=1;;
		h | \?) usage;;
	esac
done
shift $(($OPTIND - 1)) 


# Fetch the file if it's a HTTP URL, then use the cache file as input
if [[ "$infile" =~ ^http://.* ]];
then
	curl -fs -z $cachefile -o $cachefile $infile || { echo "Unable to fetch the GeoIP data file"; exit 1; }
	infile=$cachefile
fi

if [ ! -e $infile ];
then
	echo "Le fichier source de géolocalisation $infile n'existe pas". >&2
	exit 1
fi

# Should we decompress it on the fly ?
if [[ "$infile" =~ ^.*\.zip ]];
then
	reader="funzip"
else
	reader="cat"
fi

# Initialize the country filter
countries=""
for country in $*;
do
	if [ "$countries" = "" ];
	then
		countries="$country"
	else
		countries="$countries|$country"
	fi
done

if [ "$countries" != "" ];
then
	filters="$filters|grep -Ei '($countries)'"
fi

# Initialize the lowercase filter
if [ $lowercase_opts -eq 1 ];
then
	filters="$filters|tr A-Z a-z"
fi

# Now we can launch the conversion process
eval "$reader $infile | cut -d, -f1,2,5 | iprange | sed 's/\"//g' $filters" || { echo "GeoIP data conversion failure"; exit 1; }

