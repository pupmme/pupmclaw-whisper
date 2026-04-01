#!/bin/bash
# OpenClaw Whisper ASR CLI Wrapper
# 用法: whisper-asr-cli.sh <音频文件路径>
# 输出: 纯文本转录结果
# 退出码: 0=成功, 非0=失败

set -e

MEDIA_PATH="$1"
ASR_URL="${ASR_URL:-http://127.0.0.1:9000/asr}"

if [ -z "$MEDIA_PATH" ]; then
    echo "Usage: $0 <audio_file>" >&2
    exit 1
fi

if [ ! -f "$MEDIA_PATH" ]; then
    echo "Error: File not found: $MEDIA_PATH" >&2
    exit 1
fi

# 调用本地 Whisper ASR API
# encode=true 让服务端处理转码（amr/silk/ogg 等格式）
RESULT=$(curl -s -X POST "$ASR_URL" \
    -F "audio_file=@$MEDIA_PATH" \
    -F "encode=true" \
    -F "language=zh" \
    -F "output=txt" \
    -w "\n%{http_code}")

HTTP_CODE="${RESULT: -3}"
BODY="${RESULT:0:${#RESULT}-3}"

if [ "$HTTP_CODE" != "200" ]; then
    echo "ASR request failed (HTTP $HTTP_CODE): $BODY" >&2
    exit 1
fi

echo "$BODY"
exit 0
