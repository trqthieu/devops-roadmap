# Network interfaces
ip a                            # xem tất cả interfaces + IP
ip a show eth0                  # xem interface cụ thể
ip route                        # xem routing table
ip route get 8.8.8.8            # traffic đến 8.8.8.8 đi đường nào
hostname -I                     # chỉ in IP addresses

# Ping
ping -c 4 host                  # ping 4 lần
ping -c 1 -W 2 host             # ping 1 lần, timeout 2s

# Port & connection
ss -tlnp                        # TCP listening ports + process
ss -tlnp | grep :80             # kiểm tra port 80
ss -tnp state established       # connections đang active
nc -zw3 host port               # kiểm tra port có mở không

# curl — test HTTP
curl https://url                            # GET request
curl -I https://url                         # chỉ xem headers
curl -s -o /dev/null -w "%{http_code}" url  # chỉ status code
curl -X POST -H "Content-Type: application/json" \
     -d '{"key":"val"}' https://url         # POST với JSON
curl -v https://url                         # verbose debug
curl -L https://url                         # follow redirect
curl --connect-timeout 5 https://url        # với timeout

# wget — download
wget https://url/file           # download file
wget -O name.file https://url   # download đặt tên
wget --spider https://url       # kiểm tra URL không download

# traceroute
traceroute -n google.com        # trace đường đi
traceroute -m 10 google.com     # tối đa 10 hops