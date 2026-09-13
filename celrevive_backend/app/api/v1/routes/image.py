from fastapi import APIRouter, BackgroundTasks, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.services.image_intake_service import accept_validated_image
from app.schemas.assessment import ImageValidationSuccessResponse  # adjust to your schema

router = APIRouter()


@router.post("/image-validation")
async def validate_and_accept_image(
    # ... existing multipart image input + validation dependencies from 1.1/1.2 ...
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    # --- existing task 1.1/1.2 validation logic runs here, raising/returning
    # --- the "invalid image" response per task 1.3 on failure ---

    image_id = await accept_validated_image(
        db,
        background_tasks,
        session_id=session_id,          # from validated request/session context
        image_bytes=image_bytes,        # from validated upload
        original_filename=filename,
        mime_type=content_type,
        image_width=width,
        image_height=height,
        extension=extension,
    )

    return ImageValidationSuccessResponse(
        valid=True,
        image_id=image_id,
        next_step="questionnaire",       # frontend router navigates on this, not an HTTP redirect
    )