# Qwen3-TTS 语音生成使用说明

> 本机用 Qwen3-TTS（通义千问语音合成）为俯卧撑播报生成候选音频。
> 模型在本地 GPU 推理，无需 API key、无需网络（模型已下载）。

## 环境（仅本机，不进项目依赖）

Qwen3-TTS 环境装在 **E 盘独立 venv**，与项目 Flutter/Dart 完全无关：

| 项 | 位置 / 版本 |
|----|------------|
| venv | `E:\AII\MCP-LOCAL\qwen3-tts-env\.venv` |
| Python | 3.12.12（uv 管理，装在 E 盘） |
| torch | **2.10.0+cu128**（不能用 2.11，会段错误，见下文踩坑） |
| qwen-tts | 0.1.1 |
| transformers | 4.57.3 |
| 模型 | `E:\AII\MCP-LOCAL\qwen3-tts-mcp\qwen3-tts-models\`（18GB，6 个模型） |
| uv 缓存 | `E:\AII\MCP-LOCAL\.uv-cache`（E 盘，避免占 C 盘） |

### 激活 / 使用

```bash
# Python 解释器直接用绝对路径,无需 activate
VENV="E:/AII/MCP-LOCAL/qwen3-tts-env/.venv/Scripts/python.exe"

# numba cache 必须设(否则 import 卡死)
export NUMBA_CACHE_DIR="E:/AII/MCP-LOCAL/qwen3-tts-mcp/.numba_cache"

# 在 qwen3-tts-mcp 目录下跑(模型相对路径在那里才对)
cd "E:/AII/MCP-LOCAL/qwen3-tts-mcp"
"$VENV" -u gen_pushup_prompts.py          # 批量生成(见下文)
"$VENV" -u gen_one.py Vivian guide         # 单条生成
```

## ⚠️ 关键踩坑：torch 2.11.0 段错误（SIGSEGV）

**绝对不要升级到 torch 2.11.0+**。它有官方记载的 storage access regression：

- 崩溃栈：`torch/storage.py:471 __getitem__` → `transformers/modeling_utils.py:748 _load_state_dict_into_meta_model`
- 现象：加载 1.7B 模型权重时段错误（CPU/GPU 都崩，与 Python 版本无关）
- 修复：降到 `torch==2.10.0+cu128`（已验证稳定）

如果误升级了，恢复命令（用上交镜像，62MB/s）：
```bash
export UV_CACHE_DIR="E:/AII/MCP-LOCAL/.uv-cache"
uv pip install --python "$VENV" \
  --index-url "https://mirror.sjtu.edu.cn/pytorch-wheels/cu128/" \
  "torch==2.10.0+cu128" "torchaudio==2.10.0+cu128"
```

## 中文音色表（1.7B CustomVoice）

| 音色 | 性别 | 风格 |
|------|------|------|
| Vivian | 女 | 明亮略尖锐，活泼 |
| Serena | 女 | 温暖柔和，治愈 |
| Uncle_Fu | 男 | 低沉醇厚，有声书 |
| Dylan | 男 | 清澈自然，午夜电台 |
| Eric | 男 | 活力微沙哑，成都口音 |

另有英文 Ryan / Aiden，日文 Ono_Anna，韩文 Sohee。

## 生成方式

### 方式 1：单条生成 `gen_one.py`（推荐，交互式一条条来）

```bash
cd "E:/AII/MCP-LOCAL/qwen3-tts-mcp"

# 内置文案
"$VENV" -u gen_one.py Vivian guide              # 引导句
"$VENV" -u gen_one.py Vivian ready              # 准备句
"$VENV" -u gen_one.py Vivian count 3            # 数字 3

# 自定义文案 + 语速
"$VENV" -u gen_one.py Vivian custom "你好" --speed fast
"$VENV" -u gen_one.py Vivian guide --instruct "用温柔的语气说"

# 加后缀输出(对比用)
"$VENV" -u gen_one.py Vivian count 1 --speed faster --tag v2
```

语速档位：`normal` / `fast` / `faster`。

### 方式 2：批量生成 `gen_pushup_prompts.py`

```bash
# 小样本:5 音色 × (guide+ready+count_01~05) = 35 个
"$VENV" -u gen_pushup_prompts.py

# 全量:5 音色 × 33 条 = 165 个
"$VENV" -u gen_pushup_prompts.py --full

# 指定音色
"$VENV" -u gen_pushup_prompts.py --speakers Serena Dylan
```

输出到 `assets/audio/prompts_preview/<speaker>/`（已 gitignore，不进仓库）。
脚本读取文案源 `tool/tts/pushup_prompts.srt`（契约测试守护）。

### 方式 3：标准音色 + 固定种子（最稳定）

不加 instruct（纯标准音色），配固定随机种子，**每次结果完全一致**：

```python
torch.manual_seed(42)
torch.cuda.manual_seed_all(42)
wavs, sr = model.generate_custom_voice(
    text="三", language="Chinese", speaker="Vivian", instruct=None
)
# 同样的 seed + 文本 → 完全相同的音频(hash 一致)
```

## 模型加载与生成参考性能（RTX 4080 Laptop 12GB）

| 指标 | 数值 |
|------|------|
| 模型加载 | ~4-7 秒 |
| 单字生成 | ~0.5-1 秒 |
| 引导句生成 | ~5-15 秒 |
| 显存占用 | ~6GB（1.7B bf16） |

## 素材替换流程（生成 → 替换到项目）

1. 生成素材到 `prompts_preview/<voice>/`（试听目录）
2. 试听满意后，重命名 + 转 PCM_16，复制到正式目录：
   ```bash
   # 转换示例(MPEG→PCM_16 + 标准命名)
   "$VENV" -c "
   import soundfile as sf, numpy as np
   from pathlib import Path
   # ... 读取试听文件 → sf.write(目标, y, sr, subtype='PCM_16')
   "
   ```
3. 正式目录：`assets/audio/prompts/`（player 播放）
4. 主题归档：`assets/audio/voices/<voice_id>/<lang>/`（多音色管理，见 [docs/modules/voice-themes.md](../../docs/modules/voice-themes.md)）

## 已知限制

| 问题 | 说明 |
|------|------|
| 单字 TTS 偶发异常 | 孤立字词（"一"）生成可能拖音/重复，建议用固定种子或多生成几遍挑 |
| instruct 效果漂移 | 同一 instruct 在不同文本上语气/语速不一致，长文本尤甚 |
| 长文本跑飞 | 超长文案（如 1-30 连续数数）可能生成异常长音频，分段或抽卡 |
| sox 警告 | Windows 未装 sox，不影响生成 |
| flash-attn | 未安装，推理略慢但不影响功能 |

## 相关文件

| 文件 | 位置 | 说明 |
|------|------|------|
| 文案真源 | `tool/tts/pushup_prompts.srt` | 中文引导句 + 一…三十，契约测试守护 |
| 批量生成脚本 | `tool/tts/gen_pushup_prompts.py` | 5 音色批量生成（本项目副本） |
| 主题管理文档 | `docs/modules/voice-themes.md` | 多音色/多语言目录结构与规范 |
| MCP server | `E:\AII\MCP-LOCAL\qwen3-tts-mcp\server.py` | stdio MCP 服务（list_voices/start_synthesis 等） |
| 单条生成脚本 | `E:\AII\MCP-LOCAL\qwen3-tts-mcp\gen_one.py` | 交互式单条生成 |
