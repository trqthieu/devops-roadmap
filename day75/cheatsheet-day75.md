# Day 75: Networking Fundamentals - Cheatsheet

## OSI Model & TCP/IP Layers
```bash
# Xem network interfaces
ip addr show                          # hiển thị tất cả network interfaces và IP
ifconfig                              # thông tin network interfaces (legacy)
ip link show                          # xem trạng thái network interfaces

# Routing table
ip route show                         # xem routing table
netstat -rn                          # routing table (legacy)
route -n                             # routing table (numeric)
```

## DNS Operations
```bash
# DNS lookup
nslookup example.com                  # query DNS server cho domain
dig example.com                       # detailed DNS query
dig example.com +short                # chỉ hiển thị IP address
dig example.com MX                    # query MX records
dig example.com NS                    # query nameserver records
dig @8.8.8.8 example.com             # query specific DNS server

host example.com                      # simple DNS lookup
cat /etc/resolv.conf                 # xem DNS servers đang dùng
```

## TCP/IP Testing
```bash
# Ping - ICMP protocol (Layer 3)
ping -c 4 example.com                 # gửi 4 ICMP packets
ping -i 0.5 example.com              # ping interval 0.5s

# Traceroute - xem đường đi packets
traceroute example.com                # trace route đến destination
traceroute -n example.com            # không resolve hostnames
mtr example.com                       # real-time traceroute

# TCP connection testing
telnet example.com 80                 # test TCP connection port 80
nc -zv example.com 80                # check port 80 (verbose)
nc -zv example.com 80-443            # scan range ports 80-443
```

## Port & Socket Operations
```bash
# Xem listening ports
netstat -tulpn                        # TCP/UDP listening ports với PID
ss -tulpn                            # faster netstat alternative
lsof -i :80                          # xem process đang dùng port 80
lsof -i TCP:3000                     # xem TCP port 3000

# Xem established connections
netstat -an | grep ESTABLISHED        # tất cả established connections
ss -tan                              # TCP connections (numeric)
lsof -i -n                           # tất cả network connections
```

## HTTP/HTTPS Testing
```bash
# HTTP requests
curl http://example.com               # GET request
curl -I http://example.com           # chỉ headers (HEAD request)
curl -v http://example.com           # verbose với request/response details
curl -X POST -d "data=value" http://example.com  # POST request

# HTTPS với SSL info
curl -v https://example.com          # verbose HTTPS
curl -k https://example.com          # ignore SSL verification (insecure)
openssl s_client -connect example.com:443  # test SSL/TLS connection
openssl s_client -connect example.com:443 -showcerts  # xem certificates

# Check SSL certificate
echo | openssl s_client -connect example.com:443 2>/dev/null | openssl x509 -noout -dates
# hiển thị cert validity dates
```

## TLS/SSL Certificate Operations
```bash
# Xem certificate details
openssl x509 -in cert.pem -text -noout           # xem cert info
openssl x509 -in cert.pem -noout -subject        # subject name
openssl x509 -in cert.pem -noout -issuer         # issuer info
openssl x509 -in cert.pem -noout -dates          # validity period

# Generate self-signed certificate
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes
# tạo self-signed cert valid 365 days

# Verify certificate chain
openssl verify -CAfile ca.pem cert.pem           # verify cert với CA
```

## Network Debugging
```bash
# Packet capture
tcpdump -i eth0                      # capture packets trên eth0
tcpdump -i eth0 port 80              # chỉ capture port 80
tcpdump -i eth0 -w capture.pcap      # save to file
tcpdump -r capture.pcap              # read từ file

# Network statistics
netstat -s                           # network statistics
ss -s                                # socket statistics summary
ip -s link                           # interface statistics

# Check network connectivity
ping -c 1 8.8.8.8                    # test internet connectivity
ping -c 1 $(ip route | grep default | awk '{print $3}')  # ping gateway
```

## Common Ports
```bash
# Well-known ports
# 20/21  - FTP (data/control)
# 22     - SSH
# 23     - Telnet
# 25     - SMTP (email)
# 53     - DNS
# 80     - HTTP
# 110    - POP3
# 143    - IMAP
# 443    - HTTPS
# 3306   - MySQL
# 5432   - PostgreSQL
# 6379   - Redis
# 27017  - MongoDB
# 8080   - HTTP alternate
# 9090   - Prometheus
# 3000   - Grafana/Node.js apps

# Scan common ports
nmap -p 22,80,443 example.com         # scan specific ports
nmap -p- example.com                  # scan tất cả ports (slow)
nmap -sV example.com                  # detect service versions
```

## Firewall Quick Check
```bash
# iptables
iptables -L -n -v                     # list firewall rules
iptables -L INPUT -n                  # input chain rules

# ufw (Ubuntu)
ufw status                            # firewall status
ufw status numbered                   # rules với numbers

# firewalld (CentOS/RHEL)
firewall-cmd --list-all               # xem firewall config
firewall-cmd --list-ports             # open ports
```

## Network Performance
```bash
# Bandwidth testing
iperf3 -s                            # start iperf server
iperf3 -c server_ip                  # client connect to server

# Download speed test
curl -o /dev/null http://speedtest.tele2.net/100MB.zip  # test download speed
wget --output-document=/dev/null http://speedtest.tele2.net/100MB.zip

# Network latency
ping -c 100 example.com | tail -1    # average latency từ 100 packets
```
