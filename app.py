import os

from src.data_loader import load_all_documents
from src.vectorstore import FaissVectorStore
from src.search import RAGSearch

# Example usage
if __name__ == "__main__":

    store = FaissVectorStore("faiss_store")

    # Build the index on first run (when it hasn't been saved yet); load it afterwards.
    if os.path.exists(os.path.join("faiss_store", "faiss.index")):
        store.load()
    else:
        docs = load_all_documents("data")
        store.build_from_documents(docs)

    rag_search = RAGSearch(store)
    query = "What is the EBITDA in 2022?"
    summary = rag_search.search_and_summarize(query, top_k=3)
    print("Summary:", summary)
    print("Query: ", query)