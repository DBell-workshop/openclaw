"""
Python TTS worker for mycat (StyleTTS2 / Matcha-TTS selectable via env).
Streams PCM16 chunks to stdout (length-prefixed) for Node host.
"""
import os
import sys
import struct
import time

ENGINE = os.getenv("MYCAT_TTS_ENGINE", "styletts2")  # styletts2|matcha
MODEL = os.getenv("MYCAT_TTS_MODEL", "")

# Lazy imports to speed cold start path if engine unused

def load_styletts2():
    import torch
    from styletts2 import StyleTTS2

    model = StyleTTS2.from_pretrained(MODEL or "sidharthrajaram/StyleTTS2")
    model.to("cuda" if torch.cuda.is_available() else "cpu")
    return model


def load_matcha():
    import torch
    from matcha_tts import MatchaTTS

    repo = MODEL or "shivammehta25/matcha-tts"
    model = MatchaTTS.from_pretrained(repo)
    model.to("cuda" if torch.cuda.is_available() else "cpu")
    return model


def pcm_chunks(pcm, chunk_ms=40, sample_rate=24000):
    bytes_per_sample = 2
    bytes_per_chunk = int(sample_rate * bytes_per_sample * chunk_ms / 1000)
    for i in range(0, len(pcm), bytes_per_chunk):
        yield pcm[i : i + bytes_per_chunk]


def main():
    model = load_styletts2() if ENGINE == "styletts2" else load_matcha()
    sample_rate = 24000

    for line in sys.stdin:
        text = line.strip()
        if not text:
            continue
        t0 = time.time()
        if ENGINE == "styletts2":
            wav = model.tts(text)
            pcm = (wav * 32767).clamp(-32768, 32767).short().cpu().numpy().tobytes()
        else:
            wav = model.tts(text)["audio"]
            pcm = (wav * 32767).clamp(-32768, 32767).short().cpu().numpy().tobytes()
        # stream chunks length-prefixed
        for chunk in pcm_chunks(pcm, chunk_ms=40, sample_rate=sample_rate):
            sys.stdout.buffer.write(struct.pack("<I", len(chunk)))
            sys.stdout.buffer.write(chunk)
            sys.stdout.flush()
        # final zero-length chunk marks end
        sys.stdout.buffer.write(struct.pack("<I", 0))
        sys.stdout.flush()
        sys.stderr.write(f"done {len(pcm)/sample_rate:.2f}s audio in {time.time()-t0:.2f}s\n")
        sys.stderr.flush()


if __name__ == "__main__":
    main()
