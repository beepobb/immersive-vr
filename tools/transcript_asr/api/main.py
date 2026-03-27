from fastapi import FastAPI, UploadFile, File, HTTPException
from tempfile import NamedTemporaryFile
import shutil
import os

from asr.transcribe import transcribe_file

app = FastAPI()


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/transcribe")
async def transcribe_audio(file: UploadFile = File(...)):
    if not file.filename:
        raise HTTPException(status_code=400, detail="No file uploaded")

    suffix = os.path.splitext(file.filename)[1] or ".wav"
    temp_path = None

    try:
        with NamedTemporaryFile(delete=False, suffix=suffix) as temp_file:
            shutil.copyfileobj(file.file, temp_file)
            temp_path = temp_file.name

        result = transcribe_file(temp_path)

        return result

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Transcription failed: {str(e)}")

    finally:
        await file.close()
        if temp_path and os.path.exists(temp_path):
            os.remove(temp_path)