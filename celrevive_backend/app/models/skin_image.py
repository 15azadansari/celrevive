import uuid
from sqlalchemy import ForeignKey, String, BigInteger, Integer, TIMESTAMP, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from app.db.base import Base


class SkinImage(Base):
    __tablename__ = "skin_image"

    image_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    session_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("customer_session.session_id", ondelete="CASCADE"), nullable=False
    )
    storage_uri: Mapped[str] = mapped_column(String, nullable=False)
    original_filename: Mapped[str | None] = mapped_column(String, nullable=True)
    mime_type: Mapped[str | None] = mapped_column(String(100), nullable=True)
    file_size_bytes: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    image_width: Mapped[int | None] = mapped_column(Integer, nullable=True)
    image_height: Mapped[int | None] = mapped_column(Integer, nullable=True)
    sha256: Mapped[str | None] = mapped_column(String(64), nullable=True)
    uploaded_at: Mapped["TIMESTAMPTZ"] = mapped_column(
        TIMESTAMP(timezone=True), server_default=text("CURRENT_TIMESTAMP")
    )