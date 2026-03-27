# Qdrant Vector Database

## Overview

Qdrant is an open-source vector similarity search engine written in Rust. It provides a production-ready service with a convenient API to store, search, and manage vectors with additional payloads. Qdrant is optimized for extended filtering support, making it useful for neural network or semantic-based matching, faceted search, and other applications.

## Key Features

- **Written in Rust**: High performance and memory safety
- **Rich filtering**: Combine vector similarity with payload filters
- **Horizontal scaling**: Distributed deployment for large datasets
- **On-disk storage**: Handles datasets larger than available RAM
- **gRPC and REST API**: Flexible integration options
- **Quantization**: Scalar and product quantization for memory optimization

## Core Concepts

### Collections
A collection is a named set of points (vectors with payloads). Each collection has:
- **Vector configuration**: Dimension size, distance metric (Cosine, Euclid, Dot)
- **Optimizers**: Indexing and storage configuration
- **Shard configuration**: For distributed deployments

### Points
A point consists of:
- **ID**: Unique identifier (integer or UUID)
- **Vector**: The embedding representation
- **Payload**: JSON metadata (filterable)

### Distance Metrics
| Metric | Use Case | Range |
|--------|----------|-------|
| Cosine | Text similarity | -1 to 1 |
| Euclid | Spatial distance | 0 to infinity |
| Dot Product | Recommendation systems | -infinity to infinity |

## API Examples

### Create a Collection
```
PUT /collections/my_documents
{
  "vectors": {
    "size": 1536,
    "distance": "Cosine"
  }
}
```

### Insert Points
```
PUT /collections/my_documents/points
{
  "points": [
    {
      "id": 1,
      "vector": [0.1, 0.2, ...],
      "payload": {"title": "Document 1", "category": "technical"}
    }
  ]
}
```

### Search
```
POST /collections/my_documents/points/search
{
  "vector": [0.1, 0.2, ...],
  "limit": 5,
  "filter": {
    "must": [{"key": "category", "match": {"value": "technical"}}]
  }
}
```

## Deployment

Qdrant runs as a Docker container:
```
docker run -p 6333:6333 -p 6334:6334 qdrant/qdrant
```

- Port 6333: REST API
- Port 6334: gRPC API
- Dashboard: http://localhost:6333/dashboard

## Performance Tips

1. Use **HNSW index** for approximate nearest neighbor search (default)
2. Enable **quantization** for large collections to reduce memory usage
3. Use **payload indexing** on frequently filtered fields
4. Set appropriate **ef** and **m** HNSW parameters based on recall requirements
