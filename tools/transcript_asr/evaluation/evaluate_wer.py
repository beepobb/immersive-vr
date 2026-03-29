import os
import re

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GROUND_TRUTH = os.path.join(BASE_DIR, "outputs", "librispeech_30min.txt")
PREDICTED = os.path.join(BASE_DIR, "outputs", "librispeech_30min_pred.txt")


def normalize_text(text: str) -> str:
    text = text.lower()
    text = re.sub(r"[^a-z0-9\s']", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def levenshtein_distance(ref_words, hyp_words):
    m, n = len(ref_words), len(hyp_words)
    dp = [[0] * (n + 1) for _ in range(m + 1)]

    for i in range(m + 1):
        dp[i][0] = i
    for j in range(n + 1):
        dp[0][j] = j

    for i in range(1, m + 1):
        for j in range(1, n + 1):
            if ref_words[i - 1] == hyp_words[j - 1]:
                dp[i][j] = dp[i - 1][j - 1]
            else:
                dp[i][j] = min(
                    dp[i - 1][j] + 1,
                    dp[i][j - 1] + 1,
                    dp[i - 1][j - 1] + 1,
                )

    return dp[m][n]


def compute_wer(reference: str, hypothesis: str) -> float:
    ref_words = normalize_text(reference).split()
    hyp_words = normalize_text(hypothesis).split()

    if not ref_words:
        raise ValueError("Reference transcript is empty.")

    distance = levenshtein_distance(ref_words, hyp_words)
    return distance / len(ref_words)


def main():
    with open(GROUND_TRUTH, "r", encoding="utf-8") as f:
        reference = f.read()

    with open(PREDICTED, "r", encoding="utf-8") as f:
        hypothesis = f.read()

    wer = compute_wer(reference, hypothesis)
    print(f"WER: {wer:.4f} ({wer * 100:.2f}%)")


if __name__ == "__main__":
    main()