from __future__ import annotations

from typing import List, Dict, Any


def overlap(a_start: float, a_end: float, b_start: float, b_end: float) -> float:
    return max(0.0, min(a_end, b_end) - max(a_start, b_start))


def assign_speakers(
    asr_segments: List[Dict[str, Any]],
    speaker_turns: List[Dict[str, Any]],
) -> List[Dict[str, Any]]:
    merged = []

    for seg in asr_segments:
        seg_start = float(seg["start"])
        seg_end = float(seg["end"])

        best_speaker = "UNKNOWN"
        best_overlap = 0.0

        for turn in speaker_turns:
            ov = overlap(seg_start, seg_end, float(turn["start"]), float(turn["end"]))
            if ov > best_overlap:
                best_overlap = ov
                best_speaker = turn["speaker"]

        merged.append({
            "start": seg_start,
            "end": seg_end,
            "speaker": best_speaker,
            "text": seg["text"],
        })

    return merged