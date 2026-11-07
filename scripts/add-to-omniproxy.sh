#!/bin/bash
# Thêm account Muse AI vào OmniProxy
# Yêu cầu: OmniProxy đang chạy, muse2api đang chạy trên :8788

set -e

OMNIPROXY_URL="http://127.0.0.1:20131"
MUSE2API_URL="http://127.0.0.1:8788"

# Đọc password OmniProxy từ config
OMNIPROXY_PASSWORD=$(python3 -c "import json; print(json.load(open('$HOME/.omniproxy-user/data/config.json'))['password'])")

# Login OmniProxy
echo "Logging into OmniProxy..."
TOKEN=$(curl -s -X POST "$OMNIPROXY_URL/admin/api/login" \
  -H "Content-Type: application/json" \
  -d "{\"password\":\"$OMNIPROXY_PASSWORD\"}" | python3 -c "import json,sys; print(json.load(sys.stdin)['token'])")

if [ -z "$TOKEN" ]; then
  echo "ERROR: Không thể login OmniProxy"
  exit 1
fi

# Đọc key của muse2api
MUSE2API_KEY=$(cat ~/muse/muse2api/data/api_key 2>/dev/null)
if [ -z "$MUSE2API_KEY" ]; then
  echo "ERROR: Không tìm thấy muse2api key tại ~/muse/muse2api/data/api_key"
  exit 1
fi

# Kiểm tra account đã tồn tại chưa
EXISTING=$(curl -s "$OMNIPROXY_URL/admin/api/accounts" \
  -H "X-Admin-Token: $TOKEN" | python3 -c "
import json,sys
for a in json.load(sys.stdin):
    if a.get('nickname')=='Muse AI':
        print(a['id'])
        break
")

if [ -n "$EXISTING" ]; then
  echo "Account 'Muse AI' đã tồn tại (ID: $EXISTING). Cập nhật..."
  curl -s -X PUT "$OMNIPROXY_URL/admin/api/accounts/$EXISTING" \
    -H "X-Admin-Token: $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"accessToken\":\"$MUSE2API_KEY\",
      \"allowedModels\":[\"muse-chat\",\"muse-image\",\"muse-video\",\"gpt-4o\",\"gpt-4o-mini\",\"gpt-4.1\",\"gpt-5\",\"claude-sonnet-4\",\"deepseek-chat\",\"dall-e-3\",\"gpt-image-1\",\"sora\"]
    }" > /dev/null
  
  # Refresh catalog
  curl -s -X POST "$OMNIPROXY_URL/admin/api/accounts/$EXISTING/models/refresh" \
    -H "X-Admin-Token: $TOKEN" > /dev/null
  
  echo "✅ Đã cập nhật account Muse AI"
else
  echo "Tạo account 'Muse AI' mới..."
  RESULT=$(curl -s -X POST "$OMNIPROXY_URL/admin/api/accounts" \
    -H "X-Admin-Token: $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"email\":\"muse-ai-web\",
      \"nickname\":\"Muse AI\",
      \"accessToken\":\"$MUSE2API_KEY\",
      \"authMethod\":\"external_openai\",
      \"provider\":\"External OpenAI\",
      \"baseUrl\":\"$MUSE2API_URL\",
      \"allowedModels\":[\"muse-chat\",\"muse-image\",\"muse-video\",\"gpt-4o\",\"gpt-4o-mini\",\"gpt-4.1\",\"gpt-5\",\"claude-sonnet-4\",\"deepseek-chat\",\"dall-e-3\",\"gpt-image-1\",\"sora\"],
      \"enabled\":true,
      \"region\":\"external\"
    }")
  
  ID=$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
  
  if [ -z "$ID" ]; then
    echo "ERROR: Không thể tạo account"
    exit 1
  fi
  
  # Refresh catalog
  sleep 2
  curl -s -X POST "$OMNIPROXY_URL/admin/api/accounts/$ID/models/refresh" \
    -H "X-Admin-Token: $TOKEN" > /dev/null
  
  echo "✅ Đã tạo account Muse AI (ID: $ID)"
fi

echo ""
echo "Bây giờ có thể gọi:"
echo "  curl -X POST http://127.0.0.1:20131/v1/chat/completions \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"model\":\"muse-chat\",\"messages\":[{\"role\":\"user\",\"content\":\"Hi\"}]}'"
