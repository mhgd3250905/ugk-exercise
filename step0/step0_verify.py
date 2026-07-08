import argparse
import csv
import json
import math
import shutil
import urllib.request
from dataclasses import dataclass
from pathlib import Path

import cv2
import matplotlib
import numpy as np

matplotlib.use("Agg")
from matplotlib import pyplot as plt

try:
    from ai_edge_litert.interpreter import Interpreter
except ImportError as exc:
    raise SystemExit(
        "Missing LiteRT runtime. Install it with: python -m pip install ai-edge-litert"
    ) from exc


MODEL_URL = (
    "https://tfhub.dev/google/lite-model/movenet/singlepose/lightning/"
    "tflite/int8/4?lite-format=tflite"
)
KEYPOINTS = [
    "nose",
    "left_eye",
    "right_eye",
    "left_ear",
    "right_ear",
    "left_shoulder",
    "right_shoulder",
    "left_elbow",
    "right_elbow",
    "left_wrist",
    "right_wrist",
    "left_hip",
    "right_hip",
    "left_knee",
    "right_knee",
    "left_ankle",
    "right_ankle",
]
EDGES = [
    ("nose", "left_eye"),
    ("nose", "right_eye"),
    ("left_eye", "left_ear"),
    ("right_eye", "right_ear"),
    ("left_shoulder", "right_shoulder"),
    ("left_shoulder", "left_elbow"),
    ("left_elbow", "left_wrist"),
    ("right_shoulder", "right_elbow"),
    ("right_elbow", "right_wrist"),
    ("left_shoulder", "left_hip"),
    ("right_shoulder", "right_hip"),
    ("left_hip", "right_hip"),
    ("left_hip", "left_knee"),
    ("right_hip", "right_knee"),
    ("left_knee", "left_ankle"),
    ("right_knee", "right_ankle"),
]
NAME_TO_INDEX = {name: i for i, name in enumerate(KEYPOINTS)}


@dataclass(frozen=True)
class LetterboxInfo:
    scale: float
    pad_x: int
    pad_y: int
    new_width: int
    new_height: int
    target: int


def letterbox_info(width: int, height: int, target: int) -> LetterboxInfo:
    scale = min(target / width, target / height)
    new_width = int(round(width * scale))
    new_height = int(round(height * scale))
    return LetterboxInfo(
        scale=scale,
        pad_x=(target - new_width) // 2,
        pad_y=(target - new_height) // 2,
        new_width=new_width,
        new_height=new_height,
        target=target,
    )


def letterbox_frame(frame_bgr: np.ndarray, target: int) -> tuple[np.ndarray, LetterboxInfo]:
    height, width = frame_bgr.shape[:2]
    info = letterbox_info(width, height, target)
    rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
    resized = cv2.resize(rgb, (info.new_width, info.new_height), interpolation=cv2.INTER_LINEAR)
    canvas = np.zeros((target, target, 3), dtype=np.uint8)
    y1 = info.pad_y
    x1 = info.pad_x
    canvas[y1 : y1 + info.new_height, x1 : x1 + info.new_width] = resized
    return canvas, info


def keypoints_to_pixels(
    keypoints_yx_conf: np.ndarray,
    info: LetterboxInfo,
    width: int,
    height: int,
) -> np.ndarray:
    pixels = np.zeros((len(KEYPOINTS), 3), dtype=np.float32)
    for i, (y_norm, x_norm, conf) in enumerate(keypoints_yx_conf):
        x = (float(x_norm) * info.target - info.pad_x) / info.scale
        y = (float(y_norm) * info.target - info.pad_y) / info.scale
        pixels[i] = [
            min(max(x, 0.0), float(width - 1)),
            min(max(y, 0.0), float(height - 1)),
            float(conf),
        ]
    return pixels


def weighted_mean(values, weights, min_conf=0.1) -> float:
    pairs = [(float(v), float(w)) for v, w in zip(values, weights) if float(w) >= min_conf]
    if not pairs:
        return math.nan
    total_weight = sum(w for _, w in pairs)
    return sum(v * w for v, w in pairs) / total_weight


def angle_degrees(shoulder: np.ndarray, elbow: np.ndarray, wrist: np.ndarray) -> float:
    a = shoulder - elbow
    b = wrist - elbow
    denom = np.linalg.norm(a) * np.linalg.norm(b)
    if denom == 0:
        return math.nan
    cos_angle = float(np.dot(a, b) / denom)
    return math.degrees(math.acos(np.clip(cos_angle, -1.0, 1.0)))


def download_model(model_path: Path) -> None:
    if model_path.exists() and model_path.stat().st_size > 1_000_000:
        return
    model_path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = model_path.with_suffix(".tmp")
    request = urllib.request.Request(MODEL_URL, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request, timeout=120) as response, tmp_path.open("wb") as out:
        shutil.copyfileobj(response, out)
    if tmp_path.stat().st_size < 1_000_000:
        tmp_path.unlink(missing_ok=True)
        raise RuntimeError("Downloaded model is too small; TF Hub did not return a TFLite file.")
    tmp_path.replace(model_path)


def make_input(frame_rgb: np.ndarray, input_detail: dict) -> np.ndarray:
    dtype = input_detail["dtype"]
    value = frame_rgb.astype(np.float32)
    if np.issubdtype(dtype, np.integer):
        scale, zero_point = input_detail.get("quantization", (0.0, 0))
        if scale:
            info = np.iinfo(dtype)
            value = np.clip(np.round(value / scale + zero_point), info.min, info.max)
        return np.expand_dims(value.astype(dtype), axis=0)
    return np.expand_dims(value.astype(dtype), axis=0)


def dequantize_output(output: np.ndarray, output_detail: dict) -> np.ndarray:
    if np.issubdtype(output.dtype, np.integer):
        scale, zero_point = output_detail.get("quantization", (0.0, 0))
        if scale:
            output = (output.astype(np.float32) - zero_point) * scale
    keypoints = np.squeeze(output).astype(np.float32)
    if keypoints.shape != (17, 3):
        keypoints = keypoints.reshape(17, 3)
    return keypoints


def run_inference(interpreter: Interpreter, frame_rgb: np.ndarray, input_detail: dict, output_detail: dict):
    interpreter.set_tensor(input_detail["index"], make_input(frame_rgb, input_detail))
    interpreter.invoke()
    return dequantize_output(interpreter.get_tensor(output_detail["index"]), output_detail)


def paired_conf(pixels: np.ndarray, left_name: str, right_name: str) -> float:
    left = pixels[NAME_TO_INDEX[left_name], 2]
    right = pixels[NAME_TO_INDEX[right_name], 2]
    return float(np.mean([left, right]))


def aggregate_row(frame_index: int, fps: float, pixels: np.ndarray) -> dict:
    left_shoulder = pixels[NAME_TO_INDEX["left_shoulder"]]
    right_shoulder = pixels[NAME_TO_INDEX["right_shoulder"]]
    left_elbow = pixels[NAME_TO_INDEX["left_elbow"]]
    right_elbow = pixels[NAME_TO_INDEX["right_elbow"]]
    left_wrist = pixels[NAME_TO_INDEX["left_wrist"]]
    right_wrist = pixels[NAME_TO_INDEX["right_wrist"]]

    left_angle = angle_degrees(left_shoulder[:2], left_elbow[:2], left_wrist[:2])
    right_angle = angle_degrees(right_shoulder[:2], right_elbow[:2], right_wrist[:2])
    elbow_angle = weighted_mean(
        [left_angle, right_angle],
        [
            min(left_shoulder[2], left_elbow[2], left_wrist[2]),
            min(right_shoulder[2], right_elbow[2], right_wrist[2]),
        ],
        min_conf=0.15,
    )

    row = {
        "frame": frame_index,
        "time_s": frame_index / fps if fps else frame_index,
        "nose_y": float(pixels[NAME_TO_INDEX["nose"], 1]),
        "shoulder_y": weighted_mean(
            [left_shoulder[1], right_shoulder[1]], [left_shoulder[2], right_shoulder[2]]
        ),
        "shoulder_conf": paired_conf(pixels, "left_shoulder", "right_shoulder"),
        "elbow_y": weighted_mean([left_elbow[1], right_elbow[1]], [left_elbow[2], right_elbow[2]]),
        "elbow_x": weighted_mean([left_elbow[0], right_elbow[0]], [left_elbow[2], right_elbow[2]]),
        "elbow_conf": paired_conf(pixels, "left_elbow", "right_elbow"),
        "wrist_y": weighted_mean([left_wrist[1], right_wrist[1]], [left_wrist[2], right_wrist[2]]),
        "wrist_conf": paired_conf(pixels, "left_wrist", "right_wrist"),
        "elbow_angle": elbow_angle,
    }
    for i, name in enumerate(KEYPOINTS):
        row[f"{name}_x"] = float(pixels[i, 0])
        row[f"{name}_y"] = float(pixels[i, 1])
        row[f"{name}_conf"] = float(pixels[i, 2])
    return row


def draw_overlay(frame: np.ndarray, pixels: np.ndarray, frame_index: int) -> np.ndarray:
    out = frame.copy()
    for a_name, b_name in EDGES:
        a = pixels[NAME_TO_INDEX[a_name]]
        b = pixels[NAME_TO_INDEX[b_name]]
        if a[2] >= 0.2 and b[2] >= 0.2:
            cv2.line(out, tuple(a[:2].astype(int)), tuple(b[:2].astype(int)), (0, 220, 255), 2)
    for i, name in enumerate(KEYPOINTS):
        x, y, conf = pixels[i]
        color = (0, 255, 0) if conf >= 0.3 else (0, 0, 255)
        cv2.circle(out, (int(x), int(y)), 5, color, -1)
        cv2.putText(
            out,
            f"{conf:.2f}",
            (int(x) + 5, int(y) - 5),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.35,
            color,
            1,
            cv2.LINE_AA,
        )
    cv2.putText(
        out,
        f"frame {frame_index}",
        (16, 36),
        cv2.FONT_HERSHEY_SIMPLEX,
        1.0,
        (255, 255, 255),
        2,
        cv2.LINE_AA,
    )
    return out


def smooth_nan(values: np.ndarray, window: int = 5) -> np.ndarray:
    result = np.full(values.shape, np.nan, dtype=np.float32)
    radius = window // 2
    for i in range(len(values)):
        start = max(0, i - radius)
        end = min(len(values), i + radius + 1)
        chunk = values[start:end]
        if np.isfinite(chunk).any():
            result[i] = float(np.nanmean(chunk))
    return result


def estimate_cycles(signal: np.ndarray, min_prominence: float, min_gap: int = 8) -> int:
    valid = np.isfinite(signal)
    if valid.sum() < min_gap * 2:
        return 0
    x = np.arange(len(signal))
    filled = np.interp(x, x[valid], signal[valid])
    low = float(np.nanpercentile(filled, 20))
    high = float(np.nanpercentile(filled, 80))
    if high - low < min_prominence:
        return 0

    up_threshold = low + 0.4 * (high - low)
    down_threshold = low + 0.6 * (high - low)
    state = "down" if filled[0] >= down_threshold else "up"
    last_switch = -min_gap
    cycles = 0
    for i, value in enumerate(filled):
        if i - last_switch < min_gap:
            continue
        if state == "up" and value >= down_threshold:
            state = "down"
            last_switch = i
        elif state == "down" and value <= up_threshold:
            cycles += 1
            state = "up"
            last_switch = i
    return cycles


def evaluate_gates(
    shoulder_conf_mean: float,
    nose_conf_mean: float,
    shoulder_amplitude_px: float,
    elbow_conf_mean: float,
    cycle_visible: bool,
    height: int,
) -> dict:
    c3_threshold = height * 0.05
    gates = {
        "C1": {
            "name": "shoulder confidence",
            "value": shoulder_conf_mean,
            "threshold": 0.5,
            "pass": shoulder_conf_mean >= 0.5,
            "hard": True,
        },
        "C2": {
            "name": "nose confidence",
            "value": nose_conf_mean,
            "threshold": 0.4,
            "pass": nose_conf_mean >= 0.4,
            "hard": False,
        },
        "C3": {
            "name": "shoulder Y amplitude px",
            "value": shoulder_amplitude_px,
            "threshold": c3_threshold,
            "pass": shoulder_amplitude_px >= c3_threshold,
            "hard": True,
        },
        "C4": {
            "name": "elbow confidence",
            "value": elbow_conf_mean,
            "threshold": 0.3,
            "pass": elbow_conf_mean >= 0.3,
            "hard": False,
        },
        "C5": {
            "name": "visible cycles",
            "value": bool(cycle_visible),
            "threshold": True,
            "pass": bool(cycle_visible),
            "hard": True,
        },
    }
    gates["hard_pass"] = all(gate["pass"] for gate in gates.values() if isinstance(gate, dict) and gate["hard"])
    return gates


def write_csv(csv_path: Path, rows: list[dict]) -> None:
    fieldnames = list(rows[0].keys())
    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def write_plot(plot_path: Path, rows: list[dict], height: int) -> np.ndarray:
    frames = np.array([row["frame"] for row in rows])
    shoulder = np.array(
        [row["shoulder_y"] if row["shoulder_conf"] >= 0.3 else math.nan for row in rows],
        dtype=np.float32,
    )
    nose = np.array(
        [row["nose_y"] if row["nose_conf"] >= 0.3 else math.nan for row in rows],
        dtype=np.float32,
    )
    elbow_angle = np.array([row["elbow_angle"] for row in rows], dtype=np.float32)
    shoulder_smooth = smooth_nan(shoulder)

    fig, axes = plt.subplots(2, 1, figsize=(12, 8), sharex=True)
    axes[0].plot(frames, shoulder_smooth, label="shoulder_y smoothed", linewidth=2)
    axes[0].plot(frames, nose, label="nose_y", alpha=0.65)
    axes[0].invert_yaxis()
    axes[0].set_ylabel("Y pixels (inverted)")
    axes[0].set_title(f"Shoulder amplitude threshold: {height * 0.05:.0f}px")
    axes[0].legend(loc="best")
    axes[0].grid(alpha=0.25)

    axes[1].plot(frames, elbow_angle, label="elbow_angle", color="tab:orange")
    axes[1].set_ylabel("degrees")
    axes[1].set_xlabel("frame")
    axes[1].legend(loc="best")
    axes[1].grid(alpha=0.25)

    fig.tight_layout()
    fig.savefig(plot_path, dpi=160)
    plt.close(fig)
    return shoulder_smooth


def write_report(report_path: Path, video_path: Path, outputs: dict, metrics: dict, gates: dict) -> None:
    lines = [
        "# Step 0 验证报告",
        "",
        "## 机位核对",
        "",
        "| 待确认项 | 实测结论 |",
        "|---|---|",
        "| 镜头相对人的方向 | 正前方低机位，手机接近地面 |",
        "| 人物哪一面朝向镜头 | 脸朝镜头 |",
        "| 画面稳定可见的身体部位 | 头、肩、肘、腕稳定可见；髋以下多数帧受遮挡/透视影响 |",
        "",
        "## 输入",
        "",
        f"- 视频：`{video_path.name}`",
        f"- 分辨率：{metrics['width']} x {metrics['height']}",
        f"- FPS：{metrics['fps']:.2f}",
        f"- 帧数：{metrics['frames']}",
        f"- 模型：MoveNet SinglePose Lightning TFLite int8 v4",
        "",
        "## 输出",
        "",
        f"- 叠加视频：`{outputs['video']}`",
        f"- 信号 CSV：`{outputs['csv']}`",
        f"- 曲线图：`{outputs['plot']}`",
        f"- 机器摘要：`{outputs['summary']}`",
        "",
        "## C1-C5 判定",
        "",
        "| 编号 | 检查项 | 实测值 | 阈值 | 结论 |",
        "|---|---:|---:|---:|---|",
    ]
    for code in ["C1", "C2", "C3", "C4", "C5"]:
        gate = gates[code]
        value = gate["value"]
        threshold = gate["threshold"]
        value_text = f"{value:.4f}" if isinstance(value, float) else str(value)
        threshold_text = f"{threshold:.4f}" if isinstance(threshold, float) else str(threshold)
        lines.append(
            f"| {code} | {gate['name']} | {value_text} | {threshold_text} | "
            f"{'PASS' if gate['pass'] else 'FAIL'} |"
        )
    lines.extend(
        [
            "",
            f"硬门槛结论：**{'通过' if gates['hard_pass'] else '不通过'}**",
            "",
            "备注：C5 默认由脚本的周期估计给出，验收时仍应打开曲线图复核。",
            "",
        ]
    )
    report_path.write_text("\n".join(lines), encoding="utf-8")


def parse_cycle_visible(value: str, estimated_cycles: int) -> bool:
    if value == "yes":
        return True
    if value == "no":
        return False
    return estimated_cycles >= 2


def process_video(video_path: Path, output_dir: Path, model_path: Path, cycle_visible_arg: str) -> dict:
    download_model(model_path)
    interpreter = Interpreter(model_path=str(model_path), num_threads=4)
    interpreter.allocate_tensors()
    input_detail = interpreter.get_input_details()[0]
    output_detail = interpreter.get_output_details()[0]
    input_shape = input_detail["shape"]
    if int(input_shape[1]) != int(input_shape[2]):
        raise RuntimeError(f"Expected square MoveNet input, got shape {input_shape}")
    target = int(input_shape[1])

    cap = cv2.VideoCapture(str(video_path))
    if not cap.isOpened():
        raise RuntimeError(f"Cannot open video: {video_path}")
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = float(cap.get(cv2.CAP_PROP_FPS)) or 30.0
    frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

    output_dir.mkdir(parents=True, exist_ok=True)
    video_out = output_dir / "out_keypoints.mp4"
    csv_out = output_dir / "out_signals.csv"
    plot_out = output_dir / "out_signals_plot.png"
    summary_out = output_dir / "out_summary.json"
    report_out = output_dir / "step0_report.md"

    writer = cv2.VideoWriter(
        str(video_out),
        cv2.VideoWriter_fourcc(*"mp4v"),
        fps,
        (width, height),
    )
    rows = []
    frame_index = 0
    while True:
        ok, frame = cap.read()
        if not ok:
            break
        model_frame, info = letterbox_frame(frame, target)
        keypoints = run_inference(interpreter, model_frame, input_detail, output_detail)
        pixels = keypoints_to_pixels(keypoints, info, width, height)
        rows.append(aggregate_row(frame_index, fps, pixels))
        writer.write(draw_overlay(frame, pixels, frame_index))
        frame_index += 1
        if frame_index % 30 == 0:
            print(f"processed {frame_index}/{frame_count or '?'} frames")

    cap.release()
    writer.release()
    if not rows:
        raise RuntimeError("No frames processed.")

    write_csv(csv_out, rows)
    shoulder_smooth = write_plot(plot_out, rows, height)

    shoulder_conf_mean = float(np.mean([row["shoulder_conf"] for row in rows]))
    nose_conf_mean = float(np.mean([row["nose_conf"] for row in rows]))
    elbow_conf_mean = float(np.mean([row["elbow_conf"] for row in rows]))
    shoulder_amplitude_px = float(np.nanmax(shoulder_smooth) - np.nanmin(shoulder_smooth))
    estimated_cycles = estimate_cycles(shoulder_smooth, min_prominence=height * 0.05)
    cycle_visible = parse_cycle_visible(cycle_visible_arg, estimated_cycles)
    gates = evaluate_gates(
        shoulder_conf_mean=shoulder_conf_mean,
        nose_conf_mean=nose_conf_mean,
        shoulder_amplitude_px=shoulder_amplitude_px,
        elbow_conf_mean=elbow_conf_mean,
        cycle_visible=cycle_visible,
        height=height,
    )
    metrics = {
        "width": width,
        "height": height,
        "fps": fps,
        "frames": len(rows),
        "shoulder_conf_mean": shoulder_conf_mean,
        "nose_conf_mean": nose_conf_mean,
        "elbow_conf_mean": elbow_conf_mean,
        "shoulder_amplitude_px": shoulder_amplitude_px,
        "estimated_cycles": estimated_cycles,
        "cycle_visible_mode": cycle_visible_arg,
    }
    summary = {"metrics": metrics, "gates": gates}
    summary_out.write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
    outputs = {
        "video": video_out.name,
        "csv": csv_out.name,
        "plot": plot_out.name,
        "summary": summary_out.name,
    }
    write_report(report_out, video_path, outputs, metrics, gates)
    return summary


def main() -> None:
    parser = argparse.ArgumentParser(description="Step 0 MoveNet validation for push-up video.")
    parser.add_argument("--video", default="俯卧撑.mp4")
    parser.add_argument("--output-dir", default="step0")
    parser.add_argument("--model", default="step0/models/movenet_singlepose_lightning_int8_4.tflite")
    parser.add_argument("--cycle-visible", choices=["auto", "yes", "no"], default="auto")
    args = parser.parse_args()

    summary = process_video(
        video_path=Path(args.video),
        output_dir=Path(args.output_dir),
        model_path=Path(args.model),
        cycle_visible_arg=args.cycle_visible,
    )
    print(json.dumps(summary["metrics"], indent=2, ensure_ascii=False))
    print("HARD_PASS=" + str(summary["gates"]["hard_pass"]))


if __name__ == "__main__":
    main()
