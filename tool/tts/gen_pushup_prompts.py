"""
俯卧撑播报语音批量生成 — Qwen3-TTS CustomVoice

读 tool/tts/pushup_prompts.srt 的文案真源,用 5 个中文音色批量生成候选 wav,
输出到 ugk-post-voice/assets/audio/prompts_preview/<speaker>/。

设计参考 generate_zhangwuji.py:加载一次模型、循环生成、已存在则跳过(断点续跑)。
本项目工具脚本(非 Flutter 运行时代码),放在 qwen3-tts-mcp 侧,不进 ugk-post-voice git。

用法:
    cd E:\\AII\\MCP-LOCAL\\qwen3-tts-mcp
    python gen_pushup_prompts.py            # 默认小样本:guide+ready+count_01~05,全 5 音色
    python gen_pushup_prompts.py --full     # 全量 33 条,全 5 音色
    python gen_pushup_prompts.py --speakers Serena Dylan   # 只跑指定音色
"""
from __future__ import annotations

import argparse
import glob
import os
import re
import sys
import time
from pathlib import Path

# numba cache 必须在 import torch / qwen_tts 之前设好,否则 Windows 上
# qwen_tts 的 import 会卡住(见 README §Runtime Notes)。
_ROOT = Path(__file__).resolve().parent
_cache_dir = _ROOT / ".numba_cache"
_cache_dir.mkdir(parents=True, exist_ok=True)
os.environ.setdefault("NUMBA_CACHE_DIR", str(_cache_dir))

import numpy as np
import soundfile as sf
import torch
from qwen_tts import Qwen3TTSModel

# ── 路径 ──
MODEL_PATH = "qwen3-tts-models/Qwen3-TTS-12Hz-1.7B-CustomVoice"
PROJECT_VOICE_DIR = Path("E:/AII/ugk-post-voice/assets/audio/prompts_preview")
SRT_PATH = Path("E:/AII/ugk-post-voice/tool/tts/pushup_prompts.srt")
SR = 24000
LEAD_TAIL_SILENCE_SEC = 0.08  # 数字音频前后补一点静音,避免首尾爆音

# ── 音色 ──(1.7B CustomVoice 全部 5 个中文音色)
ALL_SPEAKERS = ["Vivian", "Serena", "Uncle_Fu", "Dylan", "Eric"]

# ── 语气指令 ──
# 引导/准备句:清晰沉稳、带鼓励,像私教在旁边说话
INSTRUCT_CUE = "用清晰沉稳、温和鼓励的语气说,语速适中偏慢,咬字清楚,像运动教练在示范前讲解。"
# 数字:干脆、有节奏、不拖沓,像报分员
INSTRUCT_COUNT = "用干脆利落、有节奏感的语气说,语速明快,每个数字短促有力不拖音,像体育报分员。"


# ── 解析 SRT,提取文案真源 ──
def parse_srt(srt_path: Path) -> list[dict]:
    """返回 [{'kind': 'guide'|'ready'|'count', 'text': ..., 'filename': ...}]"""
    raw = srt_path.read_text(encoding="utf-8")
    blocks = re.split(r"\n\s*\n", raw.strip())
    entries = []
    for block in blocks:
        lines = [ln.strip() for ln in block.strip().splitlines() if ln.strip()]
        if len(lines) < 3:
            continue
        idx = int(lines[0])
        text = "".join(lines[2:])
        if idx == 1:
            entries.append({"kind": "guide", "text": text, "filename": "guide.wav"})
        elif idx == 2:
            entries.append({"kind": "ready", "text": text, "filename": "ready.wav"})
        else:
            n = idx - 2  # cue 3 -> count 1
            if 1 <= n <= 30:
                entries.append(
                    {
                        "kind": "count",
                        "text": text,
                        "filename": f"count_{n:02d}.wav",
                        "n": n,
                    }
                )
    return entries


def select_entries(entries: list[dict], full: bool) -> list[dict]:
    if full:
        return entries
    # 小样本:guide + ready + count_01~05
    return [e for e in entries if e["kind"] in ("guide", "ready") or e.get("n", 99) <= 5]


def instruct_for(entry: dict) -> str:
    return INSTRUCT_COUNT if entry["kind"] == "count" else INSTRUCT_CUE


def pad_silence(audio: np.ndarray, sr: int, sec: float) -> np.ndarray:
    n = int(sr * sec)
    pad = np.zeros(n, dtype=audio.dtype)
    return np.concatenate([pad, audio, pad])


def main() -> int:
    # Windows 后台运行时 stdout 默认块缓冲,强制行缓冲以便看实时进度
    try:
        sys.stdout.reconfigure(line_buffering=True)
        sys.stderr.reconfigure(line_buffering=True)
    except Exception:  # noqa: BLE001
        pass

    ap = argparse.ArgumentParser()
    ap.add_argument("--full", action="store_true", help="生成全量 33 条(默认小样本 guide+ready+count_01~05)")
    ap.add_argument("--speakers", nargs="+", default=ALL_SPEAKERS, help="音色子集,默认全 5 个")
    args = ap.parse_args()

    speakers = args.speakers
    for s in speakers:
        if s not in ALL_SPEAKERS:
            print(f"[ERR] 未知音色: {s},可选: {ALL_SPEAKERS}", file=sys.stderr)
            return 2

    if not SRT_PATH.exists():
        print(f"[ERR] 找不到 SRT 文案源: {SRT_PATH}", file=sys.stderr)
        return 2

    entries = parse_srt(SRT_PATH)
    selected = select_entries(entries, full=args.full)
    scope = "全量" if args.full else "小样本(guide+ready+count_01~05)"
    print(f"[INFO] 文案源: {SRT_PATH}")
    print(f"[INFO] 范围: {scope},共 {len(selected)} 条")
    print(f"[INFO] 音色: {speakers}")
    print(f"[INFO] 预计生成 {len(selected) * len(speakers)} 个 wav")
    print(f"[INFO] 输出: {PROJECT_VOICE_DIR}/<speaker>/  (已 gitignore)")

    PROJECT_VOICE_DIR.mkdir(parents=True, exist_ok=True)

    print(f"\n[LOAD] 加载模型 {MODEL_PATH} ...")
    t0 = time.time()
    model = Qwen3TTSModel.from_pretrained(MODEL_PATH, device_map="cuda:0", dtype=torch.bfloat16)
    print(f"[LOAD] 就绪 ({time.time()-t0:.1f}s)\n")

    total = len(selected) * len(speakers)
    done = 0
    fail = 0
    t_start = time.time()

    for speaker in speakers:
        out_dir = PROJECT_VOICE_DIR / speaker
        out_dir.mkdir(parents=True, exist_ok=True)
        existing = {Path(f).name for f in glob.glob(str(out_dir / "*.wav"))}

        print(f"{'='*60}")
        print(f"[GEN] 音色: {speaker}  ({len(selected)} 条)")
        print(f"{'='*60}")

        for entry in selected:
            out_path = out_dir / entry["filename"]
            if entry["filename"] in existing:
                print(f"  SKIP {entry['filename']} (已存在)")
                done += 1
                continue

            t1 = time.time()
            # guide/ready 长文本偶发 KeyError(采样相关),重试最多 3 次
            attempts = 3 if entry["kind"] in ("guide", "ready") else 1
            last_exc = None
            for attempt in range(attempts):
                try:
                    wavs, sr = model.generate_custom_voice(
                        text=entry["text"],
                        language="Chinese",
                        speaker=speaker,
                        instruct=instruct_for(entry),
                    )
                    audio = pad_silence(np.asarray(wavs[0], dtype=np.float32), sr, LEAD_TAIL_SILENCE_SEC)
                    sf.write(str(out_path), audio, sr)
                    dur = len(audio) / sr
                    done += 1
                    kind_tag = {"guide": "引导", "ready": "准备", "count": f"计数{entry['n']:02d}"}[entry["kind"]]
                    tag = f"  OK   {entry['filename']:16s} {kind_tag:6s} {dur:.1f}s  ({time.time()-t1:.1f}s)"
                    if attempt > 0:
                        tag += f"  [retry {attempt+1}]"
                    print(tag)
                    last_exc = None
                    break
                except Exception as exc:  # noqa: BLE001
                    last_exc = exc
                    if attempt < attempts - 1:
                        print(f"  ...retry {entry['filename']} ({repr(exc)[:60]})")
                    continue
            if last_exc is not None:
                fail += 1
                print(f"  FAIL {entry['filename']}  {repr(last_exc)}", file=sys.stderr)

    elapsed = time.time() - t_start
    print(f"\n{'='*60}")
    print(f"[DONE] 完成 {done}/{total},失败 {fail},耗时 {elapsed:.0f}s")
    print(f"[DONE] 输出目录: {PROJECT_VOICE_DIR}")
    print(f"       试听: 每个音色一个子目录,横向对比 guide/ready/count_01~05")
    if not args.full:
        print(f"       定好音色后,跑: python gen_pushup_prompts.py --full --speakers <选中音色>")
    return 0 if fail == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
