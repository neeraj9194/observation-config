#!/bin/bash
usage () {
    echo "script usage: $0 [-f filepath] [-t template-id] [-k Bearer token key]"
}

if [ $# -eq 0 ];
then
    usage
    exit 0
fi

while getopts ':f:t:k:' OPTION; do
  case "$OPTION" in
    t)
      templateid="$OPTARG"
      echo "Template ID provided is $OPTARG"
      ;;
    f)
      file="$OPTARG"
      echo "File path is $OPTARG"
      ;;
    k)
      token_key="$OPTARG"
      echo "Bearer token key is $OPTARG"
      ;;
    ?)
      usage
      exit 0
      ;;
  esac
done
shift "$(($OPTIND -1))"

TEMPLATE_API="http://localhost:3000/api/gnet/dashboards"
IMPORT_API="http://localhost:3000/api/dashboards/import"

# Get Json from ID
get_json () {
    url="${TEMPLATE_API}/${templateid}"
    response=$(curl -s -w "%{http_code}" \
    --header 'Authorization: Bearer '${token_key} \
    --header 'Content-Type: application/json' \
    -s $url)
    # echo $template
    http_code=${response: -3} # get last 3 digits i.e http code
    template=$(echo ${response} | head -c-4)

    if [[ $http_code != 200  ]] ; then
        echo "Error fetching template"
        echo $template
        exit 0
    fi
    json_template=$( echo $template | jq '.json')
    # echo $json_template
}


# create dashboard from json
create_dashboard () {
    inputs=`echo ${json_template} | jq '.__inputs'`

    res=$(curl --location --request POST ${IMPORT_API} \
    --header 'Authorization: Bearer '${token_key} \
    --header 'Content-Type: application/json' \
    --data-raw '{"dashboard": '"${json_template}"',
    "overwrite": true,
    "inputs": '"${inputs}"',
    "folderId": 0}')
        
    echo $res
}


if [[ ! -v file ]]
then
    get_json
else
   json_template=`cat $file`
fi

create_dashboard


