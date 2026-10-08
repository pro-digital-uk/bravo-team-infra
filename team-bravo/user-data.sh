#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
echo "<h1>Hello Guys, Welcome! This server is running on $(hostname -I)</h1>" > /var/www/html/index.html