#!/bin/bash
set -o nounset
set -o errexit

USER=${OPENSHIFT_USER:-janedoe}
PASSWORD=${OPENSHIFT_PASSWORD:-janedoe}
HTPASSWD_FILE="/tmp/crwhtpasswd"
[[ -f "$HTPASSWD_FILE" ]] && htpasswd -bB ${HTPASSWD_FILE} $USER $PASSWORD || htpasswd -cbB ${HTPASSWD_FILE} $USER $PASSWORD 
htpwd_encoded="$(cat $HTPASSWD_FILE | base64 -w 0)"

cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  creationTimestamp: null
  name: htpass-secret
  namespace: openshift-config
data:
  htpasswd: ${htpwd_encoded}
EOF

# If there are no identityprovider yet
kubectl patch oauths cluster --type merge -p '
spec:
  identityProviders:
    - name: htpasswd
      mappingMethod: claim
      type: HTPasswd
      htpasswd:
        fileData:
          name: htpass-secret
'

# If there is an existing identity providers
# kubectl patch oauth cluster --type='json' -p '[
#   {
#     "op":"add","path":"/spec/identityProviders/1",
#     "value":{
#       "name":"htpasswd",
#       "mappingMethod":"claim",
#       "type":"HTPasswd",
#       "htpasswd":
#         {"fileData":
#           {"name":"htpass-secret"}
#         }
#     }
#   }
# ]'

sleep 5

oc policy add-role-to-user registry-editor "htpasswd:${USER}"
