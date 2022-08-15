#


find cached -mtime +1 -delete
if [ ! -e txo.json ]; then
  cat txo.yml | json_xs -f yaml -t json > txo.json
  sha=$(openssl sha256 -r "txo.json" | cut -d' ' -f1)
  echo sha: $sha
  otsid=$(echo $sha | cut -c-12)
  if [ ! -e txo-$otsid.json ]; then
    mv txo.json txo-$otsid.json
    ots stamp txo-$otsid.json
    hash=$(ots info txo-${otsid}.json.ots | grep -e hash: | cut -d' ' -f4)
    otsid=$(echo $hash | cut -c-12)
  fi
else
if [ -e txo.json.ots ]; then
  hash=$(ots info txo.json.ots | grep -e hash: | cut -d' ' -f4)
  otsid=$(echo $hash | cut -c-12)
  cp -p txo.json.ots txo-$otsid.json.ots
fi
fi
