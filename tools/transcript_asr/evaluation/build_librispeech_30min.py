import os
import random
import numpy as np
import soundfile as sf

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIBRISPEECH_DIR = os.path.join(BASE_DIR, "data", "librispeech", "LibriSpeech", "test-clean")
OUTPUT_WAV = os.path.join(BASE_DIR, "outputs", "librispeech_30min.wav")
OUTPUT_TXT = os.path.join(BASE_DIR, "outputs", "librispeech_30min.txt")

TARGET_DURATION_SEC = 30 * 60


def load_transcripts(transcript_file: str) -> dict[str, str]:
    mapping = {}
    with open(transcript_file, "r", encoding="utf-8") as f:
        for line in f:
            parts = line.strip().split(" ", 1)
            if len(parts) == 2:
                mapping[parts[0]] = parts[1]
    return mapping


def collect_audio_and_transcripts(root_dir: str):
    audio_files = []
    transcript_map = {}

    for root, _, files in os.walk(root_dir):
        for file in files:
            path = os.path.join(root, file)
            if file.endswith(".flac"):
                audio_files.append(path)
            elif file.endswith(".trans.txt"):
                transcript_map.update(load_transcripts(path))

    return audio_files, transcript_map


def main():
    os.makedirs(os.path.join(BASE_DIR, "outputs"), exist_ok=True)

    audio_files, transcript_map = collect_audio_and_transcripts(LIBRISPEECH_DIR)

    if not audio_files:
        raise FileNotFoundError(f"No .flac files found in {LIBRISPEECH_DIR}")

    random.shuffle(audio_files)

    selected_audio = []
    selected_texts = []
    total_duration = 0.0
    sample_rate = None

    for audio_path in audio_files:
        data, sr = sf.read(audio_path)
        duration = len(data) / sr
        file_id = os.path.splitext(os.path.basename(audio_path))[0]
        text = transcript_map.get(file_id)

        if text is None:
            continue

        if sample_rate is None:
            sample_rate = sr
        elif sr != sample_rate:
            raise ValueError(f"Sample rate mismatch: {audio_path} has {sr}, expected {sample_rate}")

        if total_duration + duration > TARGET_DURATION_SEC:
            break

        selected_audio.append(data)
        selected_texts.append(text)
        total_duration += duration

    if not selected_audio:
        raise RuntimeError("No audio selected. Check LibriSpeech path and transcript mapping.")

    full_audio = np.concatenate(selected_audio, axis=0)
    sf.write(OUTPUT_WAV, full_audio, sample_rate)

    with open(OUTPUT_TXT, "w", encoding="utf-8") as f:
        f.write(" ".join(selected_texts))

    print(f"Saved WAV: {OUTPUT_WAV}")
    print(f"Saved transcript: {OUTPUT_TXT}")
    print(f"Total duration: {total_duration / 60:.2f} minutes")


if __name__ == "__main__":
    main()