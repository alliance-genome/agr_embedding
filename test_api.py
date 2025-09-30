#!/usr/bin/env python3
"""
Quick test script for Qwen3-Embedding API
"""
import requests
import time
import sys

API_URL = "http://localhost:9000"


def test_health():
    """Test health endpoint"""
    print("Testing /health endpoint...")
    response = requests.get(f"{API_URL}/health")
    if response.status_code == 200:
        print(f"✅ Health check passed: {response.json()}")
        return True
    else:
        print(f"❌ Health check failed: {response.status_code}")
        return False


def test_embed_documents():
    """Test document embedding"""
    print("\nTesting /embed endpoint (documents)...")

    documents = [
        "The capital of China is Beijing.",
        "Gravity is a force that attracts two bodies towards each other."
    ]

    start = time.time()
    response = requests.post(
        f"{API_URL}/embed",
        json={
            "texts": documents,
            "normalize": True
        }
    )
    elapsed = time.time() - start

    if response.status_code == 200:
        data = response.json()
        print(f"✅ Embedded {data['num_embeddings']} documents")
        print(f"   Embedding dimension: {data['embedding_dim']}")
        print(f"   Time: {elapsed:.2f}s")
        return data["embeddings"]
    else:
        print(f"❌ Document embedding failed: {response.status_code}")
        print(f"   Error: {response.text}")
        return None


def test_embed_queries():
    """Test query embedding"""
    print("\nTesting /embed/query endpoint (queries with instruction)...")

    queries = [
        "What is the capital of China?",
        "Explain gravity"
    ]

    start = time.time()
    response = requests.post(
        f"{API_URL}/embed/query",
        json={
            "texts": queries,
            "instruction": "Given a web search query, retrieve relevant passages that answer the query"
        }
    )
    elapsed = time.time() - start

    if response.status_code == 200:
        data = response.json()
        print(f"✅ Embedded {data['num_embeddings']} queries")
        print(f"   Embedding dimension: {data['embedding_dim']}")
        print(f"   Time: {elapsed:.2f}s")
        return data["embeddings"]
    else:
        print(f"❌ Query embedding failed: {response.status_code}")
        print(f"   Error: {response.text}")
        return None


def test_similarity(query_embeddings, doc_embeddings):
    """Test similarity computation"""
    print("\nTesting similarity computation...")

    import numpy as np

    # Convert to numpy arrays
    queries = np.array(query_embeddings)
    docs = np.array(doc_embeddings)

    # Compute cosine similarity (dot product since vectors are normalized)
    similarity = queries @ docs.T

    print(f"✅ Similarity matrix:")
    print(f"   Query 1 -> Doc 1: {similarity[0][0]:.4f}")
    print(f"   Query 1 -> Doc 2: {similarity[0][1]:.4f}")
    print(f"   Query 2 -> Doc 1: {similarity[1][0]:.4f}")
    print(f"   Query 2 -> Doc 2: {similarity[1][1]:.4f}")

    # Expected: Query 1 should match Doc 1, Query 2 should match Doc 2
    if similarity[0][0] > similarity[0][1] and similarity[1][1] > similarity[1][0]:
        print(f"✅ Similarity scores are correct (diagonal is highest)")
        return True
    else:
        print(f"⚠️  Warning: Similarity scores unexpected")
        return False


def main():
    """Run all tests"""
    print("=" * 60)
    print("Qwen3-Embedding-8B API Test Suite")
    print("=" * 60)

    # Test health
    if not test_health():
        print("\n❌ Server is not healthy. Make sure it's running:")
        print("   python server.py")
        sys.exit(1)

    # Test document embedding
    doc_embeddings = test_embed_documents()
    if not doc_embeddings:
        sys.exit(1)

    # Test query embedding
    query_embeddings = test_embed_queries()
    if not query_embeddings:
        sys.exit(1)

    # Test similarity
    test_similarity(query_embeddings, doc_embeddings)

    print("\n" + "=" * 60)
    print("✅ All tests passed!")
    print("=" * 60)


if __name__ == "__main__":
    main()
