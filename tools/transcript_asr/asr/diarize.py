from __future__ import annotations

import os
from pathlib import Path
from typing import List, Dict, Any

import torchaudio
from dotenv import load_dotenv
from pyannote.audio import Pipeline

load_dotenv()

_PIPELINE = None


def get_diarization_pipeline() -> Pipeline:
    global _PIPELINE

    if _PIPELINE is None:
        hf_token = os.getenv("HF_TOKEN")
        if not hf_token:
            raise RuntimeError(
                "HF_TOKEN is not set. Copy .env.example to .env and add your Hugging Face token."
            )

        print("DEBUG diarize.py loaded")
        print("DEBUG HF_TOKEN present:", bool(hf_token))

        _PIPELINE = Pipeline.from_pretrained(
            "pyannote/speaker-diarization-community-1",
            token=hf_token,
        )

    return _PIPELINE


def diarize_file(audio_path: str | Path) -> List[Dict[str, Any]]:
    audio_path = Path(audio_path)

    if not audio_path.exists():
        raise FileNotFoundError(f"Audio file not found: {audio_path}")

    print("DEBUG audio path:", audio_path)

    waveform, sample_rate = torchaudio.load(str(audio_path))

    pipeline = get_diarization_pipeline()

    output = pipeline(
        {
            "waveform": waveform,
            "sample_rate": sample_rate,
        }
    )

    diarization = output.speaker_diarization

    turns: List[Dict[str, Any]] = []
    for turn, _, speaker in diarization.itertracks(yield_label=True):
        turns.append(
            {
                "start": float(turn.start),
                "end": float(turn.end),
                "speaker": str(speaker),
            }
        )

    return turns