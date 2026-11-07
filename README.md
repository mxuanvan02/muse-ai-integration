# Muse AI Integration with OmniProxy

Tích hợp Muse AI (muse.ai web app) vào OmniProxy để sử dụng qua OpenAI-compatible API.

## Kiến trúc

```
Hermes/Tool → OmniProxy (:20131) → muse2api (:8788) → muse.ai web (Noise WS)
```

- **OmniProxy**: nhận request chuẩn OpenAI `/v1/chat/completions`, route tới account "External OpenAI" trỏ về `localhost:8788`
- **muse2api**: proxy Python (FastAPI) chuyển đổi request OpenAI thành giao thức Noise XX + protobuf của muse.ai
- **muse.ai**: web app của Meta (Hatch), dùng cookies session để xác thực

## Cài đặt

### 1. Clone và cài muse2api

```bash
cd ~/muse
git clone https://github.com/www222fff/muse2api.git
cd muse2api
python3 -m venv .venv
source .venv/bin/activate
pip install -e .
```

### 2. Cấu hình

Tạo file `.env` trong `muse2api/`:

```env
MUSE2API_HOST=127.0.0.1
MUSE2API_PORT=8788
MUSE2API_DRIVER=browser
MUSE2API_API_KEY=
MUSE2API_SITE_URL=https://muse.ai
MUSE2API_CHROMIUM_PATH=/usr/bin/google-chrome
MUSE2API_HEADLESS=false
MUSE2API_CDP_PORT=19210
MUSE2API_PAGE_READY_TIMEOUT=60
MUSE2API_ACCOUNT_MAX_CONCURRENCY=2
```

### 3. Cài systemd service

```bash
cp systemd/muse2api.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now muse2api.service
```

### 4. Thêm account vào OmniProxy

Dùng script `scripts/add-to-omniproxy.sh`:

```bash
bash scripts/add-to-omniproxy.sh
```

Hoặc thủ công qua OmniProxy dashboard:
- Provider: External OpenAI
- Base URL: `http://127.0.0.1:8788`
- Access Token: (key tự sinh của muse2api, đọc từ `muse2api/data/api_key`)
- Allowed Models: `muse-chat`, `muse-image`, `muse-video`, `gpt-4o`, `gpt-4o-mini`, `gpt-4.1`, `gpt-5`, `claude-sonnet-4`, `deepseek-chat`, `dall-e-3`, `gpt-image-1`, `sora`

### 5. Import cookies muse.ai

**Cách A — Extension Chrome (khuyến nghị):**

1. Load extension từ thư mục `extension/`:
   - Mở `chrome://extensions`
   - Bật **Developer mode**
   - Click **Load unpacked** → chọn thư mục `extension/`

2. Đăng nhập `https://muse.ai` bằng email/password

3. Mở popup extension → nhập:
   - Gateway URL: `http://127.0.0.1:8788`
   - Admin key: (đọc từ `muse2api/data/api_key`)

4. Click **Import**

**Cách B — Dashboard:**

1. Mở `http://127.0.0.1:8788/dashboard`
2. Nhập admin key
3. Tab Accounts → paste cookies hoặc dùng nút **Tải extension**

**Cách C — API thủ công:**

```bash
curl -X POST http://127.0.0.1:8788/admin/accounts \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "my-muse-account",
    "cookies": {
      "hatch_sess": "...",
      "hatch_native_auth_device": "..."
    }
  }'
```

## Sử dụng

Sau khi setup xong, gọi qua OmniProxy như mọi model khác:

```bash
curl -X POST http://127.0.0.1:20131/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "muse-chat",
    "messages": [{"role": "user", "content": "Xin chào"}],
    "max_tokens": 200
  }'
```

## Models có sẵn

- **Chat**: `muse-chat`, `gpt-4o`, `gpt-4o-mini`, `gpt-4.1`, `gpt-5`, `claude-sonnet-4`, `deepseek-chat`
- **Image**: `muse-image`, `dall-e-3`, `gpt-image-1`
- **Video**: `muse-video`, `sora`

## Troubleshooting

**Lỗi "no usable account in pool"**: Chưa import cookies muse.ai. Làm bước 5.

**Lỗi "connection refused" trên :8788**: muse2api chưa chạy. Kiểm tra:
```bash
systemctl --user status muse2api.service
```

**Lỗi "invalid or missing API key"**: OmniProxy đang gửi sai key. Cập nhật account trong OmniProxy với key từ `muse2api/data/api_key`.

## License

MIT - dựa trên [muse2api](https://github.com/www222fff/muse2api) của www222fff.
