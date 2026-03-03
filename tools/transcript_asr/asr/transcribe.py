from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional, Dict, Any

from faster_whisper import WhisperModel


@dataclass
class Segment:
    start: float
    end: float
    text: str


def transcribe_file(
    audio_path: str | Path,
    model_size: str = "base",
    device: str = "cpu",
    compute_type: str = "int8",
) -> Dict[str, Any]:
    """
    Offline English transcription.
    Returns dict with:
      - text: full transcript
      - segments: list of {start, end, text}
    """
    audio_path = Path(audio_path)
    if not audio_path.exists():
        raise FileNotFoundError(f"Audio file not found: {audio_path}")

    model = WhisperModel(model_size, device=device, compute_type=compute_type)

    segments_iter, info = model.transcribe(
        str(audio_path),
        language="en",
        vad_filter=True,  # helps cut silence
    )

    segments: List[Segment] = []
    texts: List[str] = []

    for s in segments_iter:
        seg_text = (s.text or "").strip()
        if seg_text:
            segments.append(Segment(start=float(s.start), end=float(s.end), text=seg_text))
            texts.append(seg_text)

    full_text = " ".join(texts).strip()
    return {
        "text": full_text,
        "segments": [seg.__dict__ for seg in segments],
        "language": getattr(info, "language", "en"),
    }