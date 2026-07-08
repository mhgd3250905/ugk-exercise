import math
from pathlib import Path
import sys

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))

from step0_verify import (
    angle_degrees,
    evaluate_gates,
    keypoints_to_pixels,
    letterbox_info,
    weighted_mean,
)


def test_letterbox_inverse_mapping():
    info = letterbox_info(width=720, height=1280, target=192)
    # Original 720x1280 frames fit height-first into 108x192 with 42px side pads.
    assert info.scale == 0.15
    assert info.pad_x == 42
    assert info.pad_y == 0

    keypoints = np.zeros((17, 3), dtype=np.float32)
    keypoints[0] = [0.5, 0.5, 0.9]
    pixels = keypoints_to_pixels(keypoints, info, width=720, height=1280)

    assert np.allclose(pixels[0, :2], [360, 640], atol=1)
    assert pixels[0, 2] == 0.9


def test_weighted_mean_ignores_low_confidence_points():
    assert math.isclose(
        weighted_mean(values=[100, 300], weights=[0.05, 0.95], min_conf=0.1),
        300,
    )
    assert math.isnan(weighted_mean(values=[100, 300], weights=[0.05, 0.09], min_conf=0.1))


def test_angle_degrees_right_angle():
    assert math.isclose(
        angle_degrees(
            shoulder=np.array([0.0, 0.0]),
            elbow=np.array([1.0, 0.0]),
            wrist=np.array([1.0, 1.0]),
        ),
        90.0,
        abs_tol=0.1,
    )


def test_evaluate_gates_enforces_hard_failures():
    gates = evaluate_gates(
        shoulder_conf_mean=0.51,
        nose_conf_mean=0.41,
        shoulder_amplitude_px=63.9,
        elbow_conf_mean=0.31,
        cycle_visible=True,
        height=1280,
    )

    assert gates["C1"]["pass"] is True
    assert gates["C3"]["pass"] is False
    assert gates["hard_pass"] is False
