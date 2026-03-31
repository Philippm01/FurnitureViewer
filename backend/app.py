import os
import uuid
from datetime import datetime

from fastapi import FastAPI, UploadFile, File, Form, Depends, HTTPException
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session

from database import Base, engine, SessionLocal
from models import FurnitureItem

app = FastAPI()

UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

Base.metadata.create_all(bind=engine)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@app.get("/")
def root():
    return {"message": "Furniture Viewer backend is running"}


@app.get("/furniture")
def get_furniture(db: Session = Depends(get_db)):
    items = db.query(FurnitureItem).all()
    return items


@app.get("/furniture/{item_id}")
def get_furniture_item(item_id: int, db: Session = Depends(get_db)):
    item = db.query(FurnitureItem).filter(FurnitureItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Furniture item not found")
    return item


@app.post("/furniture")
async def upload_furniture(
    name: str = Form(...),
    creator: str = Form(...),
    category: str = Form(None),
    model_file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    if not model_file.filename.lower().endswith(".usdz"):
        raise HTTPException(status_code=400, detail="Only .usdz files are allowed")

    unique_filename = f"{uuid.uuid4()}_{model_file.filename}"
    file_path = os.path.join(UPLOAD_DIR, unique_filename)

    content = await model_file.read()
    with open(file_path, "wb") as f:
        f.write(content)

    file_url = f"http://127.0.0.1:8001/uploads/{unique_filename}"

    item = FurnitureItem(
        name=name,
        creator=creator,
        category=category,
        file_name=unique_filename,
        file_path=file_path,
        file_url=file_url,
        uploaded_at=datetime.utcnow()
    )

    db.add(item)
    db.commit()
    db.refresh(item)

    return item


@app.delete("/furniture/{item_id}")
def delete_furniture(item_id: int, db: Session = Depends(get_db)):
    item = db.query(FurnitureItem).filter(FurnitureItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Furniture item not found")

    if os.path.exists(item.file_path):
        os.remove(item.file_path)

    db.delete(item)
    db.commit()

    return {"message": "Furniture item deleted successfully"}