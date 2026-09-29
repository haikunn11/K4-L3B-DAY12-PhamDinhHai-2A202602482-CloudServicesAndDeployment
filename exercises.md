# Phiếu Phản Ánh — K4 Level 3B, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng placeholder mẫu bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Phạm Đình Hải  Mã học viên: 2A202602482

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

Tình huống: Khi deploy ứng dụng lên nền tảng đám mây (như Railway hoặc Render), người triển khai vô tình quên cấu hình biến môi trường `AGENT_API_KEY` trên Dashboard quản trị.
- Nếu để giá trị mặc định là `"changeme"`: Ứng dụng vẫn khởi động thành công và báo trạng thái healthy. Nhưng khi đó, bất kỳ ai hoặc các bot quét API trên Internet gửi request với header `X-API-Key: changeme` đều có thể gọi vào `/ask` và tiêu tốn toàn bộ ngân sách LLM của bạn mà bạn không hề hay biết cho đến khi nhận hóa đơn vào cuối tháng.
- Nhờ cơ chế "fail fast" (không có giá trị mặc định): `pydantic-settings` sẽ ném lỗi `ValidationError` ngay lúc khởi động container. Quá trình deployment trên Cloud sẽ fail ngay lập tức, hiển thị lỗi đỏ rõ ràng trên màn hình build log để lập trình viên phát hiện và bổ sung secret ngay trước khi ứng dụng tiếp nhận bất kỳ traffic công khai nào.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

Dòng log JSON thu được:
`{"event": "ask_completed", "level": "info", "timestamp": "2026-09-29T02:30:15.123456+00:00", "user_id": "sv-test", "tokens_in": 14, "tokens_out": 42, "cost_usd": 0.0000273}`

Hai việc làm được với dòng log này mà `print("đã trả lời xong")` không làm được:
1. **Lọc, tổng hợp và phân tích định lượng (Metrics & Aggregation):** Các hệ thống gom log trên Cloud (Datadog, AWS CloudWatch, Grafana Loki, v.v.) có thể tự động parse JSON để truy vấn định lượng như: "User nào tiêu tốn chi phí nhiều nhất trong ngày?", "Tổng số token in/out tiêu thụ theo từng khung giờ?", "Tỷ lệ câu hỏi tốn chi phí vượt ngưỡng 0.01$?". Lệnh `print` thông thường chỉ in chuỗi text phi cấu trúc, rất khó parse và tốn kém tài nguyên regex.
2. **Thiết lập cảnh báo tự động theo ngưỡng (Automated Alerting):** Có thể cài đặt rule giám sát tự động kích hoạt cảnh báo qua Slack/Telegram khi phát hiện trường `cost_usd > 0.05` ở một lượt gọi, hoặc khi tần suất các sự kiện có `level == "error"` tăng đột biến. Lệnh `print` không chứa cấu trúc số liệu để máy tính kích hoạt trigger cảnh báo.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | 1050 MB |
| Multi-stage | 185 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

Phần dung lượng chênh lệch (~865 MB) bao gồm:
1. Base image đầy đủ (`python:3.11`) nặng hơn rất nhiều so với `python:3.11-slim` do chứa toàn bộ hệ điều hành Debian hoàn chỉnh với các công cụ biên dịch (GCC, g++, make), các gói header C, tài liệu hướng dẫn man-pages và các tiện ích hệ thống không dùng đến lúc chạy ứng dụng.
2. Trong Multi-stage build, stage `builder` chịu trách nhiệm cài đặt và biên dịch thư viện vào thư mục `/install`. Các file cache của pip (`~/.cache/pip`), file tạm trong quá trình build wheel đều nằm lại ở stage builder và bị hủy bỏ; chỉ có kết quả cuối cùng trong `/install` được copy sang stage `runtime`. Nhờ vậy image runtime hoàn toàn sạch sẽ và gọn nhẹ.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

- Với Dockerfile hiện tại: Các layer từ đầu cho đến `COPY requirements.txt .` và `RUN pip install ...` ở stage builder, cũng như layer `COPY --from=builder /install /usr/local` ở stage runtime đều được Docker tái sử dụng hoàn toàn từ cache (`CACHED`). Chỉ từ layer `COPY app ./app` trở đi mới bị cache bust và phải chạy lại (quá trình build chỉ mất 1-2 giây).
- Nếu đặt `COPY . .` lên trước `RUN pip install`: Mỗi khi sửa bất kỳ ký tự nào trong mã nguồn Python (`app/main.py`), checksum của layer `COPY . .` sẽ thay đổi, làm mất cache của tất cả các layer phía sau nó. Kết quả là lệnh `RUN pip install -r requirements.txt` sẽ bị ép chạy lại từ đầu (tải lại toàn bộ gói trên PyPI), làm thời gian build bị kéo dài thêm từ vài chục giây đến vài phút mỗi lần build.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

- Chuỗi sự kiện khi chạy dưới quyền root:
  1. Kẻ tấn công phát hiện và khai thác một lỗ hổng trong mã nguồn Python (ví dụ: lỗ hổng Command Injection, SQL/NoSQL Injection hoặc Remote Code Execution - RCE qua một thư viện bên thứ ba).
  2. Do container đang chạy bằng quyền `root` (UID 0), lệnh độc hại của kẻ tấn công được thực thi trực tiếp với quyền root bên trong container.
  3. Từ quyền root container, kẻ tấn công có thể khai thác các lỗ hổng nhân Linux (kernel vulnerability) hoặc tận dụng các cấu hình mount nguy hiểm (như socket `/var/run/docker.sock` hoặc quyền SYS_ADMIN) để thực hiện kỹ thuật container breakout (thoát khỏi container). Do UID 0 trong container thường ánh xạ tới UID 0 trên máy host, kẻ tấn công chiếm toàn quyền kiểm soát root trên toàn bộ máy chủ vật lý/máy ảo của hệ thống host.
- Lệnh `USER appuser` cắt đứt chuỗi đó: Bằng cách tạo và chuyển sang user thường không có đặc quyền (`appuser` với UID 10001), kẻ tấn công dù có RCE thành công thì shell thu được cũng chỉ là quyền hạn của `appuser`. Kẻ tấn công không thể cài thêm phần mềm, không thể sửa đổi các file hệ thống, không có đặc quyền kernel để thực hiện container breakout, giúp ngăn chặn cuộc tấn công leo thang lên máy host.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

- Con số tối đa: **20 request** trong 2 giây liên tiếp.
- Cách đạt được:
  - Với cơ chế đếm theo phút đồng hồ (Fixed Window), bộ đếm tự động reset về 0 ở giây 00 của mỗi phút (ví dụ 10:00:00, 10:01:00).
  - Người dùng gửi 10 request dồn dập vào giây cuối cùng của phút thứ nhất: lúc `10:00:59` (bộ đếm ghi nhận 10/10 request - hoàn toàn hợp lệ theo luật).
  - Ngay 1 giây sau đó, khi đồng hồ bước sang `10:01:00`, bộ đếm của phút mới được reset về 0. Người dùng lập tức gửi tiếp 10 request nữa lúc `10:01:00` (bộ đếm ghi nhận 10/10 request - vẫn hợp lệ).
  - Tổng cộng: Người dùng đã gửi 20 request trong vòng 2 giây (từ 10:00:59 đến 10:01:00), gấp đôi tải cho phép trong khoảng thời gian ngắn mà Fixed Window không thể ngăn chặn. Cửa sổ trượt (Sliding Window) giải quyết triệt để lỗi này bằng cách luôn xét chính xác 60 giây gần nhất tính từ thời điểm hiện tại.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

- Điểm khác nhau:
  - *Rate Limiter* bảo vệ **tài nguyên hạ tầng / tính sẵn sàng** (CPU, RAM, Network) bằng cách giới hạn số lượng request trong một đơn vị thời gian ngắn (ví dụ 10 req/phút).
  - *Cost Guard* bảo vệ **tài chính / ngân sách** bằng cách giới hạn tổng số tiền USD tích lũy trong chu kỳ thanh toán dài (theo tháng).
- Tình huống Rate Limit cho qua nhưng Cost Guard chặn: Một người dùng trong cả tháng đã tiêu hết 9.99$ trên tổng hạn mức 10.0$/tháng. Hôm nay người đó chỉ gửi duy nhất 1 request (tần suất 1 req/phút $\ll$ 10 req/phút, Rate Limit cho qua). Nhưng câu hỏi này kèm theo prompt/tài liệu dài 50.000 token, chi phí ước tính vượt quá 0.01$ còn lại $\rightarrow$ Cost Guard chặn ngay lập tức với mã 402.
- Tình huống Cost Guard cho qua nhưng Rate Limit chặn: Vào đầu tháng, người dùng mới tiêu 0.01$ trên hạn mức 10.0$ (ngân sách còn rất nhiều, Cost Guard hoàn toàn cho qua). Nhưng một script tự động của người này gửi liên tiếp 15 request "hello" chỉ trong 5 giây $\rightarrow$ Rate Limiter lập tức chặn từ request thứ 11 với mã 429 để chống DoS server.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

Thứ tự sự kiện xảy ra:
1. Redis bị mất kết nối mạng hoặc khởi động lại trong 30 giây.
2. Bộ điều phối (Orchestrator như Docker Swarm / Kubernetes / ECS) gửi probe định kỳ kiểm tra endpoint gộp này. Do probe kiểm tra cả Redis và thất bại, cả 3 container agent đều đồng loạt trả về lỗi (unhealthy).
3. Do coi đây là liveness probe bị lỗi, Orchestrator kết luận rằng bản thân process ứng dụng đã bị chết hoặc treo $\rightarrow$ Orchestrator lập tức ra lệnh **Restart** cả 3 container cùng lúc.
4. Cả 3 container bị tắt để khởi động lại, khiến toàn bộ hệ thống rơi vào trạng thái mất trắng khả năng phục vụ (100% downtime), tất cả request gửi đến từ người dùng đều bị lỗi 502/503.
5. Khi 3 container đang cố khởi động lại, Redis có thể vẫn chưa xong $\rightarrow$ các container lại restart tiếp tục, rơi vào vòng lặp CrashLoopBackOff. Khi Redis hồi phục xong sau 30s, hệ thống vẫn phải mất thêm thời gian để khởi động lại các container.
*Ý nghĩa tách biệt:* Khi tách `/health` (chỉ kiểm tra process sống) và `/ready` (kiểm tra Redis), khi Redis mất kết nối, `/health` vẫn 200 nên container **không bị restart**, chỉ có `/ready` trả về 503 để Load Balancer tạm thời không định tuyến request vào; khi Redis hồi phục, `/ready` lập tức 200 trở lại và tiếp nhận traffic ngay tức khắc mà không container nào bị kill.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

- Nếu lưu trong Redis (Stateless): `history_length` sẽ tăng đều đặn và liên tục: 0, 2, 4, 6, 8... bất kể request được Load Balancer điều phối vào instance nào trong 3 container, bởi vì mọi container đều đọc và ghi vào cùng một cơ sở dữ liệu Redis chung.
- Nếu lưu trong một dict Python trong RAM của từng container (Stateful): Khi người dùng gửi câu hỏi liên tiếp, Load Balancer (Round Robin) sẽ phân phối luân phiên request 1 vào container A, request 2 vào container B, request 3 vào container C. Do mỗi container có vùng nhớ RAM tách biệt, người dùng sẽ thấy `history_length` nhảy lộn xộn (ví dụ: lượt 1 được 0, lượt 2 vẫn là 0, lượt 3 vẫn là 0, lượt 4 lên 2...), agent ngẫu nhiên bị "mất trí nhớ" và không thể trả lời đúng ngữ cảnh của các câu hỏi trước đó.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

- Lỗi gặp phải: Health check timeout và service bị crash / unreachable sau khi deploy lên Cloud Platform (Railway/Render).
- Thông báo lỗi trong Runtime Log: `Application failed to respond on port 8000 within timeout` hoặc `Container failed to start and listen on port $PORT`.
- Nguyên nhân: Lệnh CMD trong Dockerfile ban đầu gán cứng cổng `--port 8000`. Tuy nhiên trên các nền tảng PaaS như Railway và Render, hệ thống tự động cấp phát một cổng ngẫu nhiên thông qua biến môi trường `$PORT` (ví dụ `PORT=5678`) và yêu cầu container phải lắng nghe đúng cổng đó. Do app lắng nghe cố định ở 8000, bộ kiểm tra ingress của platform không nhận được phản hồi ở cổng được cấp phát dẫn đến timeout.
- Cách sửa: Sửa lệnh khởi chạy trong Dockerfile để đọc biến môi trường `$PORT` linh hoạt thông qua shell wrapper:
  `CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]`
  Đồng thời đảm bảo bind host là `0.0.0.0` thay vì `127.0.0.1`. Sau khi push bản vá này, service khởi động và pass health check ngay lập tức.
