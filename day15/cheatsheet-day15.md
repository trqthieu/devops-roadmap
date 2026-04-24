# Tạo SSH key
ssh-keygen -t ed25519 -C "comment"           # tạo key mặc định
ssh-keygen -t ed25519 -f ~/.ssh/mykey -N ""  # tên file + no passphrase

# Copy key lên server
ssh-copy-id user@host                         # copy default key
ssh-copy-id -i ~/.ssh/mykey.pub user@host     # copy key cụ thể

# SSH với options
ssh user@host                                 # login bình thường
ssh -i ~/.ssh/mykey user@host                 # chỉ định key
ssh -p 2222 user@host                         # port khác
ssh -v user@host                              # verbose debug

# ~/.ssh/config
Host alias
    HostName ip_or_domain
    User username
    Port 22
    IdentityFile ~/.ssh/key
    ServerAliveInterval 60

# Port forwarding
ssh -L local:remote_host:remote_port user@host    # local forward
ssh -R remote:local_host:local_port user@host     # remote forward
ssh -L 5433:localhost:5432 -N -f user@host        # background tunnel

# scp — copy file
scp file.txt user@host:/path/                     # upload file
scp -r folder/ user@host:/path/                  # upload thư mục
scp user@host:/path/file.txt ./                  # download file
scp -P 2222 file.txt user@host:/path/            # port khác

# rsync — sync thông minh
rsync -avz src/ user@host:/dst/                  # sync lên server
rsync -avz --delete src/ user@host:/dst/         # sync + xóa file thừa
rsync -avzn src/ user@host:/dst/                 # dry run
rsync -avz --exclude="node_modules/" \
      --exclude="*.log" src/ user@host:/dst/     # với exclusions
rsync -avz --partial --progress \                # resume + progress
      file.tar.gz user@host:/backup/