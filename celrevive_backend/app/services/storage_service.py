import hashlib
import os
import uuid
from pathlib import Path

# Swap this for an S3/GCS-backed implementation later; interface stays the same.
LOCAL_STORAGE_ROOT = Path(os.getenv("SKIN_IMAGE_STORAGE_ROOT", "./data/skin_images"))
LOCAL_STORAGE_ROOT.mkdir(parents=True, exist_ok=True)


class StoredImage:
    def __init__(self, storage_uri: str, sha256: str, file_size_bytes: int):
        self.storage_uri = storage_uri
        self.sha256 = sha256
        self.file_size_bytes = file_size_bytes


def save_image_bytes(image_bytes: bytes, session_id: uuid.UUID, extension: str) -> StoredImage:
    """Persist validated image bytes to storage and return locator + integrity metadata."""
    sha256 = hashlib.sha256(image_bytes).hexdigest()
    filename = f"{session_id}_{uuid.uuid4().hex}{extension}"
    dest_path = LOCAL_STORAGE_ROOT / filename

    with open(dest_path, "wb") as f:
        f.write(image_bytes)

    # storage_uri is what skin_image.storage_uri stores — abstracts local vs cloud path
    return StoredImage(
        storage_uri=f"file://{dest_path.resolve()}",
        sha256=sha256,
        file_size_bytes=len(image_bytes),
    )