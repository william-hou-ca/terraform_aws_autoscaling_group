#! /bin/sh
sudo yum update -y
sudo amazon-linux-extras install -y nginx1
sudo systemctl start nginx
sudo curl -s http://169.254.169.254/latest/meta-data/local-hostname >/tmp/hostname.html
sudo mv /tmp/hostname.html /usr/share/nginx/html/index.html
sudo chmod a+r /usr/share/nginx/html/index.html