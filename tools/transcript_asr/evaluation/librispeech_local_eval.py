from __future__ import annotations
from jiwer import wer, Compose, ToLowerCase, RemovePunctuation, RemoveMultipleSpaces, Strip, ExpandCommonEnglishContractions

import argparse
from pathlib import Path

from jiwer import wer

from asr.transcribe import transcribe_file

normalize = Compose([
    ToLowerCase(),
    RemovePunctuation(),
    RemoveMultipleSpaces(),
    Strip(),
])

def iter_librispeech_pairs(root: Path):
    """
    Yields (audio_path, reference_text) by parsing *.trans.txt files.
    """
    for trans_file in root.rglob("*.trans.txt"):
        parent = trans_file.parent
        for line in trans_file.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line:
                continue
            utt_id, ref = line.split(" ", 1)  # first token is utterance id
            audio_path = parent / f"{utt_id}.flac"
            if audio_path.exists():
                yield audio_path, ref.strip()


def main() -> int:
    p = argparse.ArgumentParser(description="Evaluate ASR on local LibriSpeech (WER) without torchcodec.")
    p.add_argument("--model", default="base", help="tiny/base/small/medium/large-v3")
    p.add_argument("--subset", default="test-clean", help='e.g. "test-clean", "test-other"')
    p.add_argument("--limit", type=int, default=20, help="Number of samples to evaluate")
    p.add_argument("--root", default="data/librispeech/LibriSpeech", help="Path containing LibriSpeech/")
    p.add_argument("--outdir", default="outputs/librispeech", help="Where to save refs/preds")
    args = p.parse_args()

    root = Path(args.root) / args.subset
    if not root.exists():
        raise FileNotFoundError(
            f"LibriSpeech subset folder not found: {root}\n"
            f"Did you download it? Try:\n"
            f'python -c "from torchaudio.datasets import LIBRISPEECH; LIBRISPEECH(\'data/librispeech\', url=\'{args.subset}\', download=True)"'
        )

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    wers: list[float] = []
    n = args.limit

    for i, (audio_path, ref) in enumerate(iter_librispeech_pairs(root)):
        if i >= n:
            break

        pred = transcribe_file(audio_path, model_size=args.model)["text"].strip()
        # if i == 0:
        #     print("\nREF:", ref)
        #     print("PRED:", pred, "\n")

        (outdir / f"sample_{i:04d}_audio.txt").write_text(str(audio_path) + "\n", encoding="utf-8")
        (outdir / f"sample_{i:04d}_ref.txt").write_text(ref + "\n", encoding="utf-8")
        (outdir / f"sample_{i:04d}_pred.txt").write_text(pred + "\n", encoding="utf-8")

        w = wer(normalize(ref), normalize(pred))
        wers.append(w)
        print(f"[{i+1}/{n}] WER={w:.4f}")

    mean_wer = sum(wers) / len(wers) if wers else float("nan")
    print("\n====================")
    print(f"Subset: {args.subset}")
    print(f"Model: {args.model}")
    print(f"Samples: {len(wers)}")
    print(f"Mean WER: {mean_wer:.4f}")
    print("====================\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())