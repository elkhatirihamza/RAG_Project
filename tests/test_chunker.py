from backend.rag.chunker import chunk_text


def test_chunker_preserves_document_metadata_and_overlap() -> None:
    chunks = chunk_text(
        "Alpha paragraph.\nBeta paragraph.\nGamma paragraph.",
        document_id="doc-1",
        document_name="notes.txt",
        page=3,
        chunk_size=30,
        overlap=8,
    )

    assert len(chunks) >= 2
    assert all(chunk.document_id == "doc-1" for chunk in chunks)
    assert all(chunk.document_name == "notes.txt" for chunk in chunks)
    assert all(chunk.page == 3 for chunk in chunks)
    assert chunks[0].id == "doc-1-0"