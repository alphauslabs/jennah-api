#!/bin/sh

echo "Compiling proto files..."
buf dep update && buf generate

# echo "Generating OpenAPI docs..."
# protoc -I . --openapiv2_out ./openapiv2 --openapiv2_opt logtostderr=true --openapiv2_opt allow_merge=true \
#        iam/v1/*.proto

# echo "Generating html docs..."
# protoc --doc_out=./generated/ --doc_opt=html,index.html \
#        iam/v1/*.proto
