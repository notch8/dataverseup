#!/bin/bash
set -euo pipefail

# Solr field-update scripts are vendored under vendor-solr/ next to this script (repo: scripts/init.d/vendor-solr/; container: $HOME_DIR/init.d/vendor-solr/).
# Avoids runtime version skew against the running Dataverse image.

if [ "${CLARIN:-}" ]; then
    wget https://raw.githubusercontent.com/IQSS/dataverse-docker/master/config/schemas/cmdi-oral-history.tsv -O /tmp/cmdi.tsv
    curl http://localhost:8080/api/admin/datasetfield/load -H "Content-type: text/tab-separated-values" -X POST --upload-file /tmp/cmdi.tsv
    custommetadatablock=True
fi

if [ "${CESSDA:-}" ]; then
    wget https://gdcc.github.io/dataverse-external-vocab-support/scripts/skosmos.js -O /tmp/skosmos.js
#    wget https://raw.githubusercontent.com/ekoi/speeltuin/master/resources/CMM_Custom_MetadataBlock.tsv -O /tmp/CMM_Custom_MetadataBlock.tsv
    wget https://raw.githubusercontent.com/IQSS/dataverse-docker/master/config/schemas/CESSDA_CMM.tsv -O /tmp/CMM_Custom_MetadataBlock.tsv
    wget https://raw.githubusercontent.com/IQSS/dataverse-docker/master/config/schemas/cv_voc.json -O /tmp/cv_voc.json
    curl -H "Content-Type: application/json" -X PUT \
          -d @/tmp/cv_voc.json http://localhost:8080/api/admin/settings/:CVocConf
    curl http://localhost:8080/api/admin/datasetfield/load -H "Content-type: text/tab-separated-values" -X POST --upload-file /tmp/CMM_Custom_MetadataBlock.tsv
    custommetadatablock=True
fi

if [ "${ODISSEI:-}" ]; then
    wget https://cdn.jsdelivr.net/gh/SSHOC/dataverse-external-vocab-support/scripts/skosmos-no-lang.js -O /tmp/skosmos.js
    wget https://raw.githubusercontent.com/SSHOC/dataverse-external-vocab-support/main/examples/config/cv_odissei.json -O /tmp/cv_voc.json
    curl -H "Content-Type: application/json" -X PUT \
          -d @/tmp/cv_voc.json http://localhost:8080/api/admin/settings/:CVocConf
    custommetadatablock=True
fi

if [ -n "${custommetadatablock:-}" ]; then
    _vendor="${HOME_DIR}/init.d/vendor-solr"
    cp "${_vendor}/update-fields.sh" /tmp/update-fields.sh
    cp "${_vendor}/updateSchemaMDB.sh" /tmp/updateSchemaMDB.sh
    chmod +x /tmp/update-fields.sh /tmp/updateSchemaMDB.sh
    cd /tmp
    /bin/cp "${HOME_DIR}/dvinstall/schema.xml" /tmp/schema.xml
    curl -fsS "http://localhost:8080/api/admin/index/solr/schema" | ./update-fields.sh schema.xml
    /bin/cp /tmp/schema.xml "${HOME_DIR}/dvinstall/schema.xml"
    ./updateSchemaMDB.sh -s solr:8983
fi
