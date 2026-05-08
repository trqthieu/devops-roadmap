# 📘 Ngày 10: Networking Cơ Bản Linux

## 🎯 Mục Tiêu Ngày Hôm Nay
Hiểu cách Linux kết nối mạng, debug connection issues, test API endpoints - kỹ năng thiết yếu khi làm việc với server.

---

## 🌐 Tại Sao DevOps Cần Hiểu Networking?

**Tình huống thực tế:**
- App không kết nối được database → debug network
- API trả về chậm → trace route tìm bottleneck
- Container không ping được nhau → kiểm tra network config
- Port bị firewall chặn → debug connectivity

**Không hiểu networking = không debug được 50% lỗi production.**

---

## 🏗️ Networking Basics - Các Khái Niệm Cơ Bản

### IP Address - Địa Chỉ Mạng

```
Trong LAN (Local Area Network):
┌────────────────────────────────┐
│  Router: 192.168.1.1           │
├────────────────────────────────┤
│  Server: 192.168.1.100         │
│  Laptop: 192.168.1.101         │
│  Phone:  192.168.1.102         │
└────────────────────────────────┘

Trên Internet (Public IP):
Server có thể có 2 IP:
- Private IP: 192.168.1.100 (trong LAN)
- Public IP: 45.67.89.123 (trên Internet)
```

**Private IP ranges (không dùng trên Internet):**
- `10.0.0.0` - `10.255.255.255`
- `172.16.0.0` - `172.31.255.255`
- `192.168.0.0` - `192.168.255.255`

### Port - Cửa Ra Vào Của Dịch Vụ

```
Server IP: 192.168.1.100
┌─────────────────────────────┐
│  Port 22:  SSH              │  ← ssh vào đây
│  Port 80:  HTTP (Nginx)     │  ← web traffic
│  Port 443: HTTPS            │  ← web traffic (encrypted)
│  Port 3306: MySQL           │  ← database
│  Port 6379: Redis           │  ← cache
└─────────────────────────────┘

1 IP address có 65535 ports (0-65535)
```

**Well-known ports (chuẩn):**
- **22**: SSH
- **80**: HTTP
- **443**: HTTPS
- **3306**: MySQL
- **5432**: PostgreSQL
- **6379**: Redis
- **27017**: MongoDB
- **3000**: Node.js (thường dùng trong dev)

### Protocol - Giao Thức Giao Tiếp

```
TCP (Transmission Control Protocol)
- Đảm bảo data đến đầy đủ, đúng thứ tự
- Dùng cho: HTTP, SSH, Database
- Chậm hơn UDP nhưng tin cậy

UDP (User Datagram Protocol)
- Nhanh nhưng không đảm bảo data đến
- Dùng cho: Video stream, DNS, Gaming

ICMP (Internet Control Message Protocol)
- Dùng cho: ping, traceroute
```

---

## 🔍 ip / ifconfig - Xem Thông Tin Network Interface

### Khái Niệm: Network Interface

**Network Interface** = card mạng (vật lý hoặc ảo).

```
Server có nhiều interfaces:
┌────────────────────────────────────┐
│  lo (loopback)                     │  ← 127.0.0.1 (localhost)
│  eth0 (Ethernet)                   │  ← Kết nối Internet
│  docker0 (Docker bridge)           │  ← Mạng Docker
│  wlan0 (WiFi)                      │  ← Card WiFi (nếu có)
└────────────────────────────────────┘
```

### Xem IP Address

```bash
ip addr show
hoặc
ifconfig

Output:
eth0: flags=4163<UP,BROADCAST,RUNNING>
    inet 192.168.1.100  netmask 255.255.255.0  broadcast 192.168.1.255
    │    │               │                      └─ Broadcast address
    │    │               └─ Subnet mask
    │    └─ IP address của server này
    └─ Interface name
```

**Các trạng thái:**
- **UP**: Interface đang hoạt động
- **DOWN**: Interface tắt (không dùng được)
- **RUNNING**: Có kết nối

### Loopback (127.0.0.1)

```
127.0.0.1 = localhost = chính máy này

Ứng dụng:
- Test app trên local: curl http://127.0.0.1:3000
- Database bind 127.0.0.1 → chỉ app local connect được (bảo mật)
```

---

## 🏓 ping - Kiểm Tra Kết Nối

### Khái Niệm

**ping** = gửi packet ICMP đến host, xem có phản hồi không.

```
Laptop (192.168.1.101)
    │
    │  ping 192.168.1.100
    ↓
Server (192.168.1.100)
    │
    │  Reply (phản hồi)
    ↓
Laptop: "Server đang sống ✓"
```

### Use Cases

**1. Kiểm tra server có online không**
```bash
ping 192.168.1.100

Output:
64 bytes from 192.168.1.100: icmp_seq=1 ttl=64 time=0.5ms
64 bytes from 192.168.1.100: icmp_seq=2 ttl=64 time=0.6ms
│                            │          │       └─ Latency (độ trễ)
│                            │          └─ Time To Live (giới hạn hop)
│                            └─ Sequence number
└─ Có phản hồi → Server online ✓

Không phản hồi → Server down hoặc firewall block ICMP
```

**2. Kiểm tra kết nối Internet**
```bash
ping 8.8.8.8        ← Google DNS
ping google.com     ← Tên miền

Nếu ping 8.8.8.8 OK nhưng google.com fail
→ Vấn đề DNS resolution
```

**3. Đo latency (độ trễ mạng)**
```bash
ping -c 10 server.com
│        └─ Count: ping 10 lần rồi dừng

Output:
--- server.com ping statistics ---
10 packets transmitted, 10 received, 0% packet loss, time 9015ms
rtt min/avg/max = 10.2/15.5/25.3 ms
│   │   │   │
│   │   │   └─ Latency max: 25.3ms
│   │   └─ Latency trung bình: 15.5ms
│   └─ Latency min: 10.2ms
└─ Round Trip Time

< 10ms:  Excellent (same datacenter)
< 50ms:  Good (in-country)
< 100ms: OK (cross-country)
> 200ms: Slow (international)
```

---

## 🗺️ traceroute - Trace Đường Đi Của Packet

### Khái Niệm

**traceroute** = xem packet đi qua những router nào để đến đích.

```
Laptop → Router 1 → Router 2 → Router 3 → google.com
         (ISP)      (Backbone) (Google)
```

### Use Case: Tìm Nơi Bị Chậm

```bash
traceroute google.com

Output:
 1  192.168.1.1        1 ms    ← Router nhà
 2  10.0.0.1          5 ms    ← ISP
 3  172.16.0.1        15 ms   ← ISP backbone
 4  203.x.x.x         50 ms   ← Internet gateway
 5  *  *  *                   ← Timeout! (vấn đề ở đây)
 6  142.250.x.x       200 ms  ← Google server (chậm do hop 5)
```

**Phân tích:**
- Hop 1-4: Bình thường
- Hop 5: Timeout → có thể là bottleneck
- Hop 6: Latency cao (200ms) vì hop 5 chậm

**Kết luận:** Vấn đề nằm ở ISP routing (hop 5), không phải server.

---

## 🔌 netstat / ss - Kiểm Tra Port & Connections

### Khái Niệm

**netstat/ss** = xem các kết nối mạng đang active và port đang listen.

### Use Case 1: Xem Port Nào Đang Listen

```bash
ss -tuln
│  │││└─ n = numeric (hiện số port, không resolve tên)
│  ││└─ l = listening (port đang chờ connection)
│  │└─ u = UDP
│  └─ t = TCP

Output:
Proto  Local Address:Port    State
tcp    0.0.0.0:22           LISTEN   ← SSH
tcp    0.0.0.0:80           LISTEN   ← Nginx HTTP
tcp    0.0.0.0:443          LISTEN   ← Nginx HTTPS
tcp    127.0.0.1:3306       LISTEN   ← MySQL (chỉ local)
tcp    0.0.0.0:6379         LISTEN   ← Redis (nguy hiểm, mở public!)
```

**Phân tích:**
- `0.0.0.0:port` = listen trên tất cả interfaces (public + private)
- `127.0.0.1:port` = chỉ listen localhost (chỉ app local connect được)

**Security issue:**
- Redis `0.0.0.0:6379` → ai cũng connect được → NGUY HIỂM
- Nên sửa thành `127.0.0.1:6379` hoặc dùng firewall

### Use Case 2: Tìm Process Đang Dùng Port

```bash
Tình huống: Start app, báo "Port 3000 already in use"

ss -tulnp | grep :3000
│       └─ p = process (hiện PID)

Output:
tcp  0.0.0.0:3000  LISTEN  5678/node
                           │   └─ Process name
                           └─ PID

→ Process node (PID 5678) đang dùng port 3000
→ Kill: kill 5678
```

### Use Case 3: Xem Active Connections

```bash
ss -tuanp

Output:
State      Local Address:Port      Peer Address:Port
ESTABLISHED 192.168.1.100:80      45.67.89.12:54321   ← Client đang connected
ESTABLISHED 192.168.1.100:22      10.0.0.5:60123      ← SSH session active
TIME_WAIT   192.168.1.100:80      23.45.67.89:12345   ← Connection vừa đóng

→ Biết có bao nhiêu client đang connect
→ Phát hiện connection lạ (có thể là hacker)
```

---

## 🌐 curl / wget - Test HTTP Endpoints

### curl - Gửi HTTP Request Từ Terminal

```bash
curl http://example.com

Output:
<html>
  <body>Hello World</body>
</html>

→ Hiện HTML response
```

### Use Cases Thực Tế

**1. Test API endpoint**
```bash
curl http://localhost:3000/api/users

Output:
{"users": [{"id": 1, "name": "John"}]}

→ API hoạt động ✓
```

**2. Test với headers**
```bash
curl -H "Authorization: Bearer token123" http://api.example.com/data
     │  └─ Header
     └─ -H flag
```

**3. POST request**
```bash
curl -X POST http://api.example.com/users \
     -H "Content-Type: application/json" \
     -d '{"name": "John", "email": "john@example.com"}'
     │   └─ Data (body)
     └─ -d flag
```

**4. Xem response headers**
```bash
curl -I http://example.com
     └─ -I = head request (chỉ lấy headers)

Output:
HTTP/1.1 200 OK
Server: nginx/1.18.0
Content-Type: text/html
Content-Length: 1234
```

**5. Follow redirects**
```bash
curl -L http://example.com
     └─ -L = follow redirects (301/302)
```

**6. Lưu output vào file**
```bash
curl http://example.com/file.zip -o file.zip
     └─ -o = output file
```

**7. Test HTTPS certificate**
```bash
curl https://example.com

Error: SSL certificate verify failed
→ Certificate có vấn đề

curl -k https://example.com
     └─ -k = insecure (bỏ qua cert check, chỉ dùng test)
```

### wget - Download File

**Khác với curl:**
- `curl` = test request, xem response
- `wget` = download file

```bash
wget http://example.com/file.zip
→ Download file.zip về thư mục hiện tại

wget -O custom-name.zip http://example.com/file.zip
     └─ -O = đặt tên file

wget -c http://example.com/large-file.iso
     └─ -c = continue (resume download nếu bị dứt)
```

---

## 🔍 Workflow Debug: App Không Kết Nối Database

**Tình huống:** App báo lỗi "Can't connect to MySQL server".

### Debug Step-by-Step

```
Bước 1: Kiểm tra MySQL có đang chạy không
systemctl status mysql
→ Nếu stopped → systemctl start mysql

Bước 2: Kiểm tra MySQL listen port nào
ss -tuln | grep 3306

Output A: tcp 127.0.0.1:3306 LISTEN
→ MySQL chỉ listen localhost
→ Nếu app ở server khác → không connect được
→ Fix: Sửa /etc/mysql/my.cnf, bind-address = 0.0.0.0

Output B: Không có output
→ MySQL không listen port 3306
→ Kiểm tra config MySQL

Bước 3: Test kết nối từ app server
telnet db-server 3306
hoặc
nc -zv db-server 3306
         │ └─ verbose
         └─ z = scan mode

Output: Connection refused
→ Firewall block hoặc MySQL không cho remote connection

Bước 4: Kiểm tra firewall
ufw status
→ Xem port 3306 có được allow không

Bước 5: Test authentication
mysql -h db-server -u appuser -p
→ Thử login thủ công
→ Nếu lỗi "Access denied" → user/password sai hoặc permission không đủ

Bước 6: Kiểm tra MySQL user permissions
mysql> SELECT host, user FROM mysql.user WHERE user='appuser';

Output:
host        user
localhost   appuser    ← Chỉ cho localhost, không cho remote!

Fix:
mysql> GRANT ALL ON database.* TO 'appuser'@'%' IDENTIFIED BY 'password';
                                              └─ % = mọi host
```

---

## 🌐 DNS - Domain Name System

### Khái Niệm

**DNS** = dịch domain name (example.com) → IP address (93.184.216.34).

```
Browser: "Truy cập google.com"
    ↓
DNS Server: "google.com = 142.250.x.x"
    ↓
Browser connect đến 142.250.x.x
```

### nslookup / dig - Query DNS

```bash
nslookup google.com

Output:
Server:    8.8.8.8        ← DNS server đang dùng
Address:   8.8.8.8#53

Name:      google.com
Address:   142.250.185.46 ← IP của google.com
```

**dig (chi tiết hơn):**
```bash
dig google.com

Output:
;; ANSWER SECTION:
google.com.  300  IN  A  142.250.185.46
│            │    │   │  └─ IP address
│            │    │   └─ Record type (A = IPv4)
│            │    └─ Class (IN = Internet)
│            └─ TTL (Time To Live) = 300 giây
└─ Domain
```

### Use Case: Debug DNS Issues

```bash
Tình huống: curl example.com fail, nhưng curl <IP> OK

Bước 1: Test DNS resolution
nslookup example.com

Output: Server failed
→ DNS server không phản hồi
→ Kiểm tra /etc/resolv.conf

Bước 2: Xem DNS server nào đang dùng
cat /etc/resolv.conf

Output:
nameserver 8.8.8.8      ← Google DNS
nameserver 1.1.1.1      ← Cloudflare DNS

Bước 3: Test DNS server khác
nslookup example.com 1.1.1.1
→ Nếu OK → vấn đề ở DNS server cũ
→ Đổi DNS server trong /etc/resolv.conf
```

---

## 🎓 Tóm Tắt Ngày 10

✅ **ip / ifconfig** xem IP address và network interfaces
✅ **ping** kiểm tra host có online không, đo latency
✅ **traceroute** trace đường đi packet, tìm nơi bị chậm
✅ **ss / netstat** xem port listening và active connections
✅ **curl** test HTTP API endpoints, debug web services
✅ **wget** download file từ URL
✅ **nslookup / dig** query DNS, debug domain resolution

**Kỹ năng cốt lõi:** Debug network issues - 50% lỗi production liên quan đến network.
