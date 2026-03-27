# RAG Architecture Overview

## What is RAG?

Retrieval-Augmented Generation (RAG) is an AI architecture pattern that enhances Large Language Model (LLM) responses by retrieving relevant information from external knowledge bases before generating answers. Instead of relying solely on the LLM's training data, RAG systems ground responses in up-to-date, domain-specific documents.

## Core Components

### 1. Document Ingestion Pipeline
The ingestion pipeline processes raw documents into searchable embeddings:
- **Document Loading**: Read files (PDF, Markdown, HTML, plain text)
- **Chunking**: Split documents into smaller segments (typically 500-1500 tokens)
- **Embedding**: Convert text chunks into vector representations using models like OpenAI text-embedding-3-small
- **Storage**: Store vectors in a vector database (Qdrant, Pinecone, Weaviate)

### 2. Retrieval System
When a user asks a question:
- The query is embedded using the same embedding model
- A similarity search finds the top-k most relevant chunks
- Retrieved chunks are passed as context to the LLM

### 3. Generation
The LLM receives:
- The user's original question
- Retrieved context from the knowledge base
- A system prompt with instructions on how to use the context

## Chunking Strategies

| Strategy | Best For | Chunk Size |
|----------|----------|------------|
| Fixed-size | Simple documents | 500-1000 tokens |
| Recursive character | Structured text | 500-1500 tokens |
| Semantic | Complex documents | Variable |
| Sentence-based | Q&A pairs | 1-5 sentences |

## Evaluation Metrics

RAG systems are evaluated using frameworks like RAGAS:
- **Faithfulness**: Are answers grounded in retrieved context?
- **Answer Relevancy**: Does the answer address the question?
- **Context Precision**: Are retrieved chunks relevant?
- **Context Recall**: Were all necessary chunks retrieved?

## Common Anti-Patterns

1. **Chunk size too large**: Dilutes relevant information with noise
2. **No reranking**: First-pass retrieval may not surface the best results
3. **Missing metadata filters**: Searching the entire corpus when category filtering would improve precision
4. **Ignoring hybrid search**: Pure vector search misses exact keyword matches
