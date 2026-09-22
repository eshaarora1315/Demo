output "domain_endpoint" {
  value = aws_opensearchserverless_collection.opensearch.collection_endpoint
}

output "domain_arn" {
  value = aws_opensearchserverless_collection.opensearch.arn
}

output "collection_name" {
  value = aws_opensearchserverless_collection.opensearch.name
}

output "firehose_delivery_stream_name" {
  value = aws_kinesis_firehose_delivery_stream.logs_to_opensearch.name
}
