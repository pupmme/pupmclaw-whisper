#!/usr/bin/env python3
"""
Whisper ASR Webservice 启动器（前台模式，systemd Type=simple 兼容）
"""
import os
import sys

# 设置环境
os.environ.setdefault("ASR_ENGINE", "faster_whisper")
os.environ.setdefault("ASR_MODEL", "small")
os.environ.setdefault("ASR_DEVICE", "cpu")
os.environ.setdefault("ASR_QUANTIZATION", "int8")
os.environ.setdefault("ASR_MODEL_PATH", "/home/openclaw/.cache/whisper")

# 等待模型加载完成后才 fork（避免 systemd 认为进程立即退出）
sys.path.insert(0, "/home/openclaw/whisper-asr")

from app.webservice import app
from app.factory.asr_model_factory import ASRModelFactory
import uvicorn

print("[whisper-asr] 初始化模型...", flush=True)
model = ASRModelFactory.create_asr_model()
model.load_model()
print("[whisper-asr] 模型加载完成", flush=True)

# 前台运行 uvicorn（不 fork，不后台）
uvicorn.run(
    app,
    host="127.0.0.1",
    port=9000,
    log_level="info",
    access_log=False,
)
