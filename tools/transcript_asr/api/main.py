# from fastapi import FastAPI, UploadFile, File, HTTPException, BackgroundTasks
# from fastapi.responses import FileResponse
# from tempfile import NamedTemporaryFile
# import shutil
# import os

# from asr.transcribe import transcribe_file
# from asr.docx_export import save_transcript_to_docx

# app = FastAPI()


# def cleanup_file(path: str) -> None:
#     """Delete a file if it exists."""
#     if path and os.path.exists(path):
#         os.remove(path)


# @app.get("/health")
# def health():
#     return {"status": "ok"}


# @app.post("/transcribe")
# async def transcribe_audio(file: UploadFile = File(...)):
#     if not file.filename:
#         raise HTTPException(status_code=400, detail="No file uploaded")

#     suffix = os.path.splitext(file.filename)[1] or ".wav"
#     temp_path = None

#     try:
#         with NamedTemporaryFile(delete=False, suffix=suffix) as temp_file:
#             shutil.copyfileobj(file.file, temp_file)
#             temp_path = temp_file.name

#         result = transcribe_file(temp_path)
#         return result

#     except Exception as e:
#         raise HTTPException(status_code=500, detail=f"Transcription failed: {str(e)}")

#     finally:
#         await file.close()
#         if temp_path and os.path.exists(temp_path):
#             os.remove(temp_path)


# @app.post("/transcribe-docx")
# async def transcribe_audio_to_docx(
#     background_tasks: BackgroundTasks,
#     file: UploadFile = File(...)
# ):
#     if not file.filename:
#         raise HTTPException(status_code=400, detail="No file uploaded")

#     audio_suffix = os.path.splitext(file.filename)[1] or ".wav"
#     temp_audio_path = None
#     temp_docx_path = None

#     try:
#         with NamedTemporaryFile(delete=False, suffix=audio_suffix) as temp_audio:
#             shutil.copyfileobj(file.file, temp_audio)
#             temp_audio_path = temp_audio.name

#         result = transcribe_file(temp_audio_path)
#         transcript_text = result.get("text", "").strip()

#         if not transcript_text:
#             raise HTTPException(status_code=500, detail="No transcript text generated")

#         with NamedTemporaryFile(delete=False, suffix=".docx") as temp_docx:
#             temp_docx_path = temp_docx.name

#         save_transcript_to_docx(
#             transcript_text=transcript_text,
#             output_path=temp_docx_path,
#             title=f"Transcript - {file.filename}"
#         )

#         background_tasks.add_task(cleanup_file, temp_audio_path)
#         background_tasks.add_task(cleanup_file, temp_docx_path)

#         return FileResponse(
#             path=temp_docx_path,
#             media_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
#             filename=f"{os.path.splitext(file.filename)[0]}_transcript.docx"
#         )

#     except HTTPException:
#         raise

#     except Exception as e:
#         if temp_audio_path and os.path.exists(temp_audio_path):
#             os.remove(temp_audio_path)
#         if temp_docx_path and os.path.exists(temp_docx_path):
#             os.remove(temp_docx_path)

#         raise HTTPException(status_code=500, detail=f"Transcription failed: {str(e)}")

#     finally:
#         await file.close()

from fastapi import FastAPI, UploadFile, File, HTTPException, BackgroundTasks, Form
from fastapi.responses import FileResponse
from tempfile import NamedTemporaryFile
import shutil
import os

from asr.transcribe import transcribe_file
from asr.docx_export import save_transcript_to_docx
from asr.diarize import diarize_file
from asr.merge import assign_speakers

app = FastAPI()


def cleanup_file(path: str) -> None:
    """Delete a file if it exists."""
    if path and os.path.exists(path):
        os.remove(path)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/transcribe")
async def transcribe_audio(
    file: UploadFile = File(...),
    diarize: bool = Form(False)
):
    if not file.filename:
        raise HTTPException(status_code=400, detail="No file uploaded")

    suffix = os.path.splitext(file.filename)[1] or ".wav"
    temp_path = None

    try:
        with NamedTemporaryFile(delete=False, suffix=suffix) as temp_file:
            shutil.copyfileobj(file.file, temp_file)
            temp_path = temp_file.name

        result = transcribe_file(temp_path)

        if diarize:
            speaker_turns = diarize_file(temp_path)
            speaker_segments = assign_speakers(
                result.get("segments", []),
                speaker_turns
            )
            result["speaker_turns"] = speaker_turns
            result["speaker_segments"] = speaker_segments

        return result

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Transcription failed: {str(e)}")

    finally:
        await file.close()
        if temp_path and os.path.exists(temp_path):
            os.remove(temp_path)


@app.post("/transcribe-docx")
async def transcribe_audio_to_docx(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    diarize: bool = Form(False)
):
    if not file.filename:
        raise HTTPException(status_code=400, detail="No file uploaded")

    audio_suffix = os.path.splitext(file.filename)[1] or ".wav"
    temp_audio_path = None
    temp_docx_path = None

    try:
        with NamedTemporaryFile(delete=False, suffix=audio_suffix) as temp_audio:
            shutil.copyfileobj(file.file, temp_audio)
            temp_audio_path = temp_audio.name

        result = transcribe_file(temp_audio_path)
        transcript_text = result.get("text", "").strip()

        if diarize:
            speaker_turns = diarize_file(temp_audio_path)
            speaker_segments = assign_speakers(
                result.get("segments", []),
                speaker_turns
            )
            result["speaker_turns"] = speaker_turns
            result["speaker_segments"] = speaker_segments

            if speaker_segments:
                transcript_lines = []
                for seg in speaker_segments:
                    speaker = seg.get("speaker", "UNKNOWN")
                    text = seg.get("text", "").strip()
                    if text:
                        transcript_lines.append(f"{speaker}: {text}")
                transcript_text = "\n".join(transcript_lines).strip()

        if not transcript_text:
            raise HTTPException(status_code=500, detail="No transcript text generated")

        with NamedTemporaryFile(delete=False, suffix=".docx") as temp_docx:
            temp_docx_path = temp_docx.name

        save_transcript_to_docx(
            transcript_text=transcript_text,
            output_path=temp_docx_path,
            title=f"Transcript - {file.filename}"
        )

        background_tasks.add_task(cleanup_file, temp_audio_path)
        background_tasks.add_task(cleanup_file, temp_docx_path)

        return FileResponse(
            path=temp_docx_path,
            media_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            filename=f"{os.path.splitext(file.filename)[0]}_transcript.docx"
        )

    except HTTPException:
        raise

    except Exception as e:
        if temp_audio_path and os.path.exists(temp_audio_path):
            os.remove(temp_audio_path)
        if temp_docx_path and os.path.exists(temp_docx_path):
            os.remove(temp_docx_path)

        raise HTTPException(status_code=500, detail=f"Transcription failed: {str(e)}")

    finally:
        await file.close()