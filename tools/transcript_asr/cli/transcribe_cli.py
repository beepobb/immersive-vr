from __future__ import annotations

import argparse
import json
from pathlib import Path

from asr.transcribe import transcribe_file


def main() -> int:
    p = argparse.ArgumentParser(description="Offline English audio transcription (faster-whisper).")
    p.add_argument("--input", "-i", required=True, help="Path to audio file (.wav/.mp3/.m4a, etc.)")
    p.add_argument("--outdir", "-o", default="outputs", help="Output directory")
    p.add_argument("--model", default="base", help="Whisper model size: tiny/base/small/medium/large-v3")
    args = p.parse_args()

    in_path = Path(args.input)
    out_dir = Path(args.outdir)
    out_dir.mkdir(parents=True, exist_ok=True)

    result = transcribe_file(in_path, model_size=args.model)

    # Write outputs
    base_name = in_path.stem  # e.g., "test1"

    transcript_path = out_dir / f"{base_name}_transcript.txt"
    segments_path = out_dir / f"{base_name}_segments.json"

    transcript_path.write_text(result["text"] + "\n", encoding="utf-8")
    segments_path.write_text(json.dumps(result["segments"], indent=2), encoding="utf-8")

    print(f"Saved: {transcript_path.resolve()}")
    print(f"Saved: {segments_path.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

# to run:
# python -m cli.transcribe_cli -i data/NAMEHEREXXX.m4a -o outputs --model base
# types of model in increasing accuracy:
# tiny, base, small, medium, large-v3