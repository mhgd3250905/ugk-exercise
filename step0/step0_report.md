# Step 0 验证报告

## 机位核对

| 待确认项 | 实测结论 |
|---|---|
| 镜头相对人的方向 | 正前方低机位，手机接近地面 |
| 人物哪一面朝向镜头 | 脸朝镜头 |
| 画面稳定可见的身体部位 | 头、肩、肘、腕稳定可见；髋以下多数帧受遮挡/透视影响 |

## 输入

- 视频：`俯卧撑.mp4`
- 分辨率：720 x 1280
- FPS：30.00
- 帧数：359
- 模型：MoveNet SinglePose Lightning TFLite int8 v4

## 输出

- 叠加视频：`out_keypoints.mp4`
- 信号 CSV：`out_signals.csv`
- 曲线图：`out_signals_plot.png`
- 机器摘要：`out_summary.json`

## C1-C5 判定

| 编号 | 检查项 | 实测值 | 阈值 | 结论 |
|---|---:|---:|---:|---|
| C1 | shoulder confidence | 0.6949 | 0.5000 | PASS |
| C2 | nose confidence | 0.4956 | 0.4000 | PASS |
| C3 | shoulder Y amplitude px | 170.0601 | 64.0000 | PASS |
| C4 | elbow confidence | 0.6800 | 0.3000 | PASS |
| C5 | visible cycles | True | True | PASS |

硬门槛结论：**通过**

备注：C5 默认由脚本的周期估计给出，验收时仍应打开曲线图复核。
