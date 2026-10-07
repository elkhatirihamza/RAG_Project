from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, File, HTTPException, UploadFile, status

from backend.config import settings
from backend.database.models import DocumentCatalog, DocumentRecord
from backend.rag.loader import SUPPORTED_TYPES, load_document
from backend.rag.pipeline import RagPipeline, create_pipeline


router = APIRouter(prefix="/api/documents", tags=["documents"])
catalog = DocumentCatalog(settings.documents_path)
_pipeline: RagPipeline | None = None
MAX_FILE_SIZE = 20 * 1024 * 1024


def get_pipeline() -> RagPipeline:
    global _pipeline
    if _pipeline is None:
        _pipeline = create_pipeline()
    return _pipeline


@router.get("")
def list_documents() -> list[DocumentRecord]:
    return catalog.list()


@router.post("/upload", status_code=status.HTTP_201_CREATED)
async def upload_document(file: UploadFile = File(...)) -> DocumentRecord:
    suffix = Path(file.filename or "").suffix.lower()
    if suffix not in SUPPORTED_TYPES:
        raise HTTPException(status_code=400, detail="Supported formats: PDF, TXT, DOCX and Markdown")
    if file.content_type and file.content_type not in {SUPPORTED_TYPES[suffix], "application/octet-stream"}:
        raise HTTPException(status_code=400, detail="The uploaded MIME type does not match its extension")

    content = await file.read(MAX_FILE_SIZE + 1)
    if len(content) > MAX_FILE_SIZE:
        raise HTTPException(status_code=413, detail="The maximum file size is 20 MB")

    document_id = uuid4().hex
    destination = settings.documents_path / f"{document_id}{suffix}"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(content)
    try:
        pages = load_document(destination)
        get_pipeline().ingest(document_id, file.filename or destination.name, pages)
    except RuntimeError as error:
        destination.unlink(missing_ok=True)
        raise HTTPException(status_code=503, detail=str(error)) from error
    except Exception as error:
        destination.unlink(missing_ok=True)
        raise HTTPException(status_code=422, detail=f"Could not process document: {error}") from error

    document = DocumentRecord.create(
        document_id=document_id,
        name=file.filename or destination.name,
        size=len(content),
        content_type=SUPPORTED_TYPES[suffix],
        pages=len(pages),
    )
    return catalog.add(document)


@router.delete("/{document_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_document(document_id: str) -> None:
    document = catalog.remove(document_id)
    if document is None:
        raise HTTPException(status_code=404, detail="Document not found")
    try:
        get_pipeline().vector_store.delete_document(document_id)
    except RuntimeError:
        pass
    for suffix in SUPPORTED_TYPES:
        (settings.documents_path / f"{document_id}{suffix}").unlink(missing_ok=True)
