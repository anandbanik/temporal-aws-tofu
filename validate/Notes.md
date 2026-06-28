curl --location 'http://localhost:8080/transfer' \
--header 'Content-type: application/json' \
--data '{
  "sourceAccountId" : "mt-source-account-id",
  "destinationAccountId" : "mt-destination-account-id",
  "transactionReferenceId" : "3967d64f-7bd7-447a-8880-3d7273917246",
  "amountToTransfer" : "60"
}'
{"message":"Resource Created Successfully"}


curl -X 'POST' \
  'http://localhost:9090/api/v1/namespaces' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "active_cluster": "active",
  "description": "Default Namespace",
  "is_global": false,
  "name": "default",
  "owner_email": "default@example.com",
  "retention_days": 60
}'
{
  "id": "b039e1b0-f211-40a6-80d2-421a4cae5d70"
}

curl -X 'GET' \
  'http://localhost:9090/api/v1/health/temporal' \
  -H 'accept: application/json'

{"status":"ok","cluster_name":"active","server_version":"1.31.0"}