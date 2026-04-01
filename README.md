# Whisper ASR Box — OpenClaw 部署版

> 基于 [ahmetoner/whisper-asr-webservice](https://github.com/ahmetoner/whisper-asr-webservice) v1.9.1，本地化部署用于 OpenClaw 语音转录。

---

## 🎯 与上游的改动

| 文件 | 上游 | 本版 | 原因 |
|------|------|------|------|
| `start.py` | `poetry run whisper-asr-webservice` | 自定义 Python 启动器（新增） | 懒加载模型 + systemd 兼容 |
| `app/factory/asr_model_factory.py` | `from app import *` | `sys.path.insert(0, "/home/openclaw/whisper-asr")` | 解决 import 路径问题 |
| `app/webservice.py` | 上游原版 | 新增 `/v1/audio/transcriptions` 端点 | OpenAI 兼容接口，供 QQ 频道等插件直连 |
| `app/config.py` | `torch` 全局 import | 保留（无修改） | — |
| `openclaw-whisper-asr.service` | 无 | systemd 服务（新增） | 持久化运行 |
| `cli-wrapper.sh` | 无 | OpenClaw CLI wrapper（新增） | OpenClaw 接入 |
| Poetry/poetry.lock | 使用 | 已删除 | pip 直接安装即可 |
| Docker 相关文件 | 使用 | 已删除 | 非 Docker 部署 |
| `mkdocs.yml` | 使用 | 已删除 | 文档已内嵌 |
| `server.log` | 无 | 已删除 | 运行日志由 systemd journal 接管 |

**上游未改动的内容：** `app/` 下所有源码（asr_models、webservice、config）均为原版。

---

## 📦 安装（裸服务器）

### 第一步：安装系统依赖

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y ffmpeg python3 python3-pip

# 验证 ffmpeg
ffmpeg -version | head -1
```

### 第二步：安装 Python 依赖

```bash
pip install -U pip

# 核心依赖
pip install fastapi uvicorn python-multipart ffmpeg-python

# Whisper 引擎（二选一）
pip install faster-whisper       # 推荐：CPU int8，轻量
# 或
pip install openai-whisper      # 官方版，较大
# 或
pip install whisperx            # 功能最多（含 VAD/Diarization）
```

### 第三步：安装 Whisper ASR Webservice 源码

```bash
# 方式 A：从本项目复制（推荐）
scp -r /home/openclaw/whisper-asr/ user@newserver:/home/openclaw/whisper-asr/
pip install -e /home/openclaw/whisper-asr/

# 方式 B：从 GitHub 直接安装
pip install git+https://github.com/ahmetoner/whisper-asr-webservice.git
```

### 第四步：配置环境变量（可选）

写在 `start.py` 里或提前 export：

```bash
export ASR_ENGINE="faster_whisper"    # 引擎
export ASR_MODEL="small"             # 模型大小（tiny/base/small/medium/large-v3）
export ASR_DEVICE="cpu"             # cpu 或 cuda
export ASR_QUANTIZATION="int8"      # int8 / float16 / float32（CPU 建议 int8）
export ASR_MODEL_PATH="/home/openclaw/.cache/whisper"  # 模型缓存路径
```

### 第五步：验证服务

```bash
# 启动服务
python3 /home/openclaw/whisper-asr/start.py &

# 测试（等待模型加载完成后）
curl -X POST http://127.0.0.1:9000/asr \
  -F "audio=@/tmp/test.wav"

# 期望返回：{"text": "这里是转写的文字"}
```

### 第六步：配置 systemd 服务（生产环境）

```bash
# 复制服务文件
sudo cp /home/openclaw/whisper-asr/openclaw-whisper-asr.service /etc/systemd/system/

# 重载 systemd
sudo systemctl daemon-reload

# 启用并启动
sudo systemctl enable --now openclaw-whisper-asr

# 查看状态
sudo systemctl status openclaw-whisper-asr

# 查看日志
sudo journalctl -u openclaw-whisper-asr -f
```

---

## 🔧 接入 OpenClaw（两种方式）

### 方式 A：CLI Wrapper（框架 tools.media.audio，推荐）

框架会自动调用 CLI 脚本，适合 Telegram 等通用场景。

```json
{
  "tools": {
    "media": {
      "audio": {
        "enabled": true,
        "echoTranscript": false,
        "language": "zh",
        "models": [
          {
            "type": "cli",
            "command": "/home/openclaw/whisper-asr/cli-wrapper.sh",
            "args": ["{{MediaPath}}"],
            "timeoutSeconds": 60
          },
          {
            "provider": "openai",
            "model": "gpt-4o-mini-transcribe"
          }
        ]
      }
    }
  }
}
```

### 方式 B：OpenAI 兼容 HTTP（QQ 频道等插件直连）

插件的 STT 模块直接 POST 到 Whisper ASR，无需 CLI wrapper。

在 OpenClaw 的 `openclaw.json` 中加入：

```json
{
  "tools": {
    "media": {
      "audio": {
        "enabled": true,
        "echoTranscript": false,
        "language": "zh",
        "models": [
          {
            "type": "cli",
            "command": "/home/openclaw/whisper-asr/cli-wrapper.sh",
            "args": ["{{MediaPath}}"],
            "timeoutSeconds": 60
          },
          {
            "provider": "openai",
            "model": "gpt-4o-mini-transcribe"
          }
        ]
      }
    }
  }
}
```

重启 OpenClaw gateway 生效：

```bash
# 重启 gateway 进程
sudo kill -HUP $(pgrep -f openclaw-gateway)

# 验证配置无错误
curl http://127.0.0.1:18789/health
```

### 方式 B 配置：QQ 频道插件直连

```json
{
  "channels": {
    "qqbot": {
      "stt": {
        "enabled": true,
        "baseUrl": "http://127.0.0.1:9000",
        "apiKey": "local-whisper-asr",
        "provider": "openai",
        "model": "small"
      }
    }
  }
}
```

---

## 📁 目录结构

```
/home/openclaw/whisper-asr/
├── app/
│   ├── asr_models/        ← 上游源码（未改动）
│   ├── factory/           ← 上游源码（未改动）
│   ├── config.py          ← 上游源码（未改动）
│   └── webservice.py      ← 上游源码 + 本版新增 OpenAI 端点
├── cli-wrapper.sh         ← OpenClaw CLI wrapper（新增）
├── openclaw-whisper-asr.service  ← systemd 服务（新增）
├── start.py               ← 启动器（新增）
├── pyproject.toml         ← 依赖声明（上游保留）
└── README.md              ← 本文档
```

---

## 🔧 常见问题

**Q: 首次启动慢？**
> 模型首次运行从 HuggingFace 下载，约 75MB（small 模型）。后续启动直接加载缓存。

**Q: CPU 占用高？**
> `ASR_QUANTIZATION=int8`（默认）可大幅降低内存和 CPU 开销。

**Q: 想换模型大小？**
> 设置 `ASR_MODEL=base`（最小）或 `medium`/`large-v3`（更准但更慢）。

**Q: 服务无法启动？**
> 检查 journal：`sudo journalctl -u openclaw-whisper-asr -n 50`
