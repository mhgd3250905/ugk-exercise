#!/usr/bin/env python3
"""Apply the approved onset gains to seven English count prompts."""

import argparse
import hashlib
import math
import struct
import wave
from pathlib import Path


GAINS_DB = {
    2: (0.0, 1.0),
    4: (0.0, 6.0),
    16: (4.0, 0.0),
    17: (0.0, 1.5),
    22: (0.0, 2.0),
    25: (0.0, 1.0),
    28: (0.0, 5.0),
}
SOURCE_SHA256 = {
    2: "2946e8498b37d452ecb8572cb2cbe3e3781ec24df5def7156cefa325251d3620",
    4: "f9795042d56be8b37eb64bb79b1b3d731e0cc91868dc7feb639c96c45a7ef93d",
    16: "3ddd91b4e923af5b0061e47f7545a15c90774d9f77aed9fd53699c43f1dae3ed",
    17: "b86fd1a7f7d09fe9f7257cf1b02545ec40dc2f2dd6e396e6865cdbc56efad053",
    22: "d317af34f6ad850a4adeee58e8808e453604c7b8034e722fa325322bafc928b1",
    25: "2baced956787ced05d5199794cf2af07bb799e2b1239099ee3dfbb3810182eba",
    28: "2bf6e018c4665aedbabe8dfcfaa542ac7e2a58520248b126eed181d603df893e",
}
OUTPUT_SHA256 = {
    2: "95bb48b1af243978952b51cbe438b791955c2aeb9035931ef51475cfaa396206",
    4: "17b257a420f70611af51cf2b4ea203573c89719e69077e9e5515c24d7ceba91b",
    16: "46b594c883cc89b9544f204347c435f7401d6c7ec242f36d63f3fe81f9a1e7ad",
    17: "b078c878369c7be350308aebae3d0839d6e098d768b1197270fc461a9c945dfe",
    22: "26e54b26168343b7868ca258a5dfda8ca2927e91a614f31c0b31b73f0207329d",
    25: "8434ef32fc084fa1206a08b5f7f318d40d9f4c22065ced7e15938bb0854b8390",
    28: "25d35ef5a8ff12bfe89735ffc993fa3d659ed1439ef6633baf176de2f0be9e05",
}


def _smoothstep(value: float) -> float:
    return value * value * (3.0 - 2.0 * value)


def _boost_weight(milliseconds: float) -> float:
    if milliseconds < 10.0:
        return 0.0
    if milliseconds < 20.0:
        return _smoothstep((milliseconds - 10.0) / 10.0)
    if milliseconds < 75.0:
        return 1.0
    if milliseconds < 180.0:
        return 1.0 - _smoothstep((milliseconds - 75.0) / 105.0)
    return 0.0


def _audible_onset_ms(samples: tuple[int, ...], sample_rate: int) -> float:
    threshold = 1036  # -30 dBFS.
    window = sample_rate // 50
    required = sample_rate // 200
    hits = 0
    for index, sample in enumerate(samples):
        hits += abs(sample) >= threshold
        if index >= window:
            hits -= abs(samples[index - window]) >= threshold
        if index >= window - 1 and hits >= required:
            return (index - window + 1) * 1000.0 / sample_rate
    return math.inf


def _data_chunk(payload: bytearray) -> tuple[int, int]:
    offset = 12
    while offset + 8 <= len(payload):
        length = struct.unpack_from("<I", payload, offset + 4)[0]
        if payload[offset : offset + 4] == b"data":
            return offset + 8, length
        offset += 8 + length + (length & 1)
    raise ValueError("missing WAV data chunk")


def _refine(path: Path, base_db: float, onset_db: float) -> bytearray:
    payload = bytearray(path.read_bytes())
    with wave.open(str(path), "rb") as source:
        if (
            source.getnchannels(),
            source.getsampwidth(),
            source.getframerate(),
        ) != (1, 2, 24000):
            raise ValueError(f"{path.name}: expected mono 24 kHz PCM16")
        frames = source.readframes(source.getnframes())

    samples = struct.unpack(f"<{len(frames) // 2}h", frames)
    refined = []
    for index, sample in enumerate(samples):
        milliseconds = index * 1000.0 / 24000
        gain_db = base_db + onset_db * _boost_weight(milliseconds)
        refined.append(round(sample * math.pow(10.0, gain_db / 20.0)))
    if max(abs(sample) for sample in refined) > 32000:
        raise ValueError(f"{path.name}: refined peak exceeds safety limit")
    if _audible_onset_ms(tuple(refined), 24000) > 45.0:
        raise ValueError(f"{path.name}: refined onset still exceeds target")

    data_offset, data_length = _data_chunk(payload)
    output_frames = struct.pack(f"<{len(refined)}h", *refined)
    if data_length != len(output_frames):
        raise ValueError(f"{path.name}: unexpected WAV data length")
    payload[data_offset : data_offset + data_length] = output_frames
    return payload


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--audio-dir",
        type=Path,
        default=Path("assets/audio/voices/manbo/en"),
    )
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    for count, (base_db, onset_db) in GAINS_DB.items():
        path = args.audio_dir / f"count_{count:02d}.wav"
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest == OUTPUT_SHA256[count]:
            print(f"count_{count:02d}: already refined")
            continue
        if digest != SOURCE_SHA256[count]:
            raise ValueError(f"{path.name}: refusing to refine an unknown source")

        output = _refine(path, base_db, onset_db)
        if hashlib.sha256(output).hexdigest() != OUTPUT_SHA256[count]:
            raise ValueError(f"{path.name}: refined output is not reproducible")
        print(f"count_{count:02d}: base {base_db:.1f} dB, onset +{onset_db:.1f} dB")
        if not args.dry_run:
            path.write_bytes(output)


if __name__ == "__main__":
    main()
