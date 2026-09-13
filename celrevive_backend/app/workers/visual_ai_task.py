import logging
import uuid

logger = logging.getLogger("visual_ai_task")


async def run_visual_ai_analysis(image_id: uuid.UUID, session_id: uuid.UUID) -> None:
    """
    Placeholder for the Visual AI analysis pipeline (work item 2.4).
    Runs out-of-band via FastAPI BackgroundTasks so it never blocks the
    validation response. Replace body with the real Visual AI API call,
    schema validation, and session_skin_concern_detection persistence.
    """
    try:
        logger.info("Visual AI analysis started image_id=%s session_id=%s", image_id, session_id)
        # TODO (2.4): call Visual AI API, validate against image_detection.json schema,
        # persist to session_skin_concern_detection
    except Exception:
        logger.exception("Visual AI analysis failed image_id=%s session_id=%s", image_id, session_id)
        # TODO: write failure state so 2.6's recommendation response can degrade gracefully