# LangChain JSON Loader JQ Schema
# Transforms raw JSON data into LangChain Document format

# Main schema for basic JSON to Document conversion
def to_documents:
  {
    documents: [
      .[] | {
        page_content: (. | tostring),
        metadata: {
          source: "json",
          row_number: $__loc__.line
        }
      }
    ]
  };

# Schema for nested JSON with custom metadata extraction
def to_documents_with_metadata(key_path; metadata_fields):
  .data as $data |
  $data | map(
    . as $item |
    {
      page_content: ($item | getpath(key_path) | tostring),
      metadata: (
        {
          source: "json"
        } +
        (
          metadata_fields | reduce .[] as $field (
            {};
            . + {($field): ($item | getpath([$field]))}
          )
        )
      )
    }
  ) |
  {documents: .};

# Schema for JSON lines (JSONL) format
def from_jsonl:
  split("\n") |
  map(
    select(length > 0) |
    fromjson |
    {
      page_content: (. | tostring),
      metadata: {
        source: "jsonl",
        timestamp: (now | todate)
      }
    }
  ) |
  {documents: .};

# Schema for extracting specific fields as documents
def extract_fields(fields):
  .data | map(
    . as $item |
    {
      page_content: (
        fields | map($item[.]) | join(" | ")
      ),
      metadata: {
        source: "json",
        id: ($item.id // $item._id // null),
        timestamp: (now | todate)
      }
    }
  ) |
  {documents: .};

# Schema for hierarchical JSON flattening
def flatten_to_documents:
  . as $root |
  [
    paths(scalars) as $path |
    {
      page_content: ($root | getpath($path) | tostring),
      metadata: {
        source: "json",
        key_path: ($path | join(".")),
        depth: ($path | length)
      }
    }
  ] |
  {documents: .};

# Schema for array-based JSON documents
def from_array:
  map(
    . as $item |
    {
      page_content: ($item | tostring),
      metadata: {
        source: "json_array",
        index: (. | indices([.]) | .[0])
      }
    }
  ) |
  {documents: .};

# Schema with text splitting for large documents
def split_documents(chunk_size; overlap):
  .documents | map(
    .page_content as $content |
    ($content | length) as $len |
    [
      range(0; $len; chunk_size - overlap) as $i |
      {
        page_content: ($content[$i:$i + chunk_size]),
        metadata: (.metadata + {
          chunk_index: ($i / (chunk_size - overlap) | floor),
          chunk_size: chunk_size
        })
      }
    ]
  ) | flatten |
  {documents: .};

# Schema for filtering documents by metadata
def filter_by_metadata(conditions):
  .documents | map(
    select(
      conditions | to_entries | map(
        .key as $key | .value as $value |
        (.metadata[$key] == $value)
      ) | all
    )
  ) |
  {documents: .};

# Schema for adding computed metadata
def add_computed_metadata:
  .documents | map(
    .metadata += {
      content_length: (.page_content | length),
      word_count: (.page_content | split(" ") | length),
      has_links: (.page_content | contains("http")),
      timestamp_added: (now | todate)
    }
  ) |
  {documents: .};

# Complete pipeline example
def complete_pipeline(source_type):
  if source_type == "jsonl" then
    from_jsonl | add_computed_metadata
  elif source_type == "array" then
    from_array | add_computed_metadata
  elif source_type == "nested" then
    flatten_to_documents | add_computed_metadata
  else
    to_documents | add_computed_metadata
  end;

# Usage examples:
# Input: raw JSON array
# to_documents

# Input: JSONL string
# from_jsonl

# Input: JSON with nested structure
# extract_fields(["title", "description", "author"])

# Input: LangChain documents
# split_documents(500; 50) | add_computed_metadata

# Input: Documents with metadata to filter
# filter_by_metadata({source: "json", type: "article"})
