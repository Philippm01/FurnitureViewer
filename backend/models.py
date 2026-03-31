from sqlalchemy import Column, Integer, String, DateTime
from datetime import datetime

from database import Base

class FurnitureItem(Base):
    __tablename__ = "furniture_items"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    creator = Column(String, nullable=False)
    category = Column(String, nullable=True)
    file_name = Column(String, nullable=False)
    file_path = Column(String, nullable=False)
    file_url = Column(String, nullable=False)
    uploaded_at = Column(DateTime, default=datetime.utcnow)