#!/bin/bash

# Author
# original author: https://github.com/gongzili456
# modified by: https://github.com/haoel
# modified by: wagagaha

COLOR_ERROR="\e[38;5;198m"
COLOR_NONE="\e[0m"
COLOR_SUCC="\e[92m"

update_core() {
	echo -e "${COLOR_ERROR}当前系统内核版本太低 <$VERSION_CURR>,需要更新系统内核.${COLOR_NONE}"
	echo "请选择要安装的Ubuntu版本的内核："
	echo "1) Ubuntu 18.04 LTS (Bionic Beaver)"
	echo "2) Ubuntu 20.04 LTS (Focal Fossa)"
	echo -e "3) Ubuntu 22.04 LTS (Jammy Jellyfish)\n"
	read -p "输入选择 (1-3): " user_choice

	case $user_choice in
	1)
		kernel_package="linux-generic-hwe-18.04"
		;;
	2)
		kernel_package="linux-generic-hwe-20.04"
		;;
	3)
		kernel_package="linux-generic-hwe-22.04"
		;;
	*)
		echo -e "${COLOR_ERROR}无效的选择，退出安装程序。${COLOR_NONE}"
		exit 1
		;;
	esac
	echo -e "${COLOR_ERROR}正在安装内核包：$kernel_package${COLOR_NONE}"
	sudo apt update -qq
	sudo apt install -y -qq --install-recommends $kernel_package
	sudo apt autoremove -y -qq

	echo -e "${COLOR_SUCC}内核更新完成，需要重新启动机器。${COLOR_NONE}"
	read -p "现在重启吗？(Y/n): " confirm_reboot
	if [[ $confirm_reboot =~ ^[Yy]$ ]] || [[ -z $confirm_reboot ]]; then
		sudo reboot
	else
		echo "请稍后手动重启机器。"
	fi
}

check_bbr() {
	has_bbr=$(lsmod | grep bbr)

	# 如果已经发现 bbr 进程
	if [ -n "$has_bbr" ]; then
		echo -e "${COLOR_SUCC}TCP BBR 拥塞控制算法已经启动${COLOR_NONE}"
	else
		start_bbr
	fi
}

start_bbr() {
	echo "启动 TCP BBR 拥塞控制算法"
	sudo modprobe tcp_bbr
	echo "tcp_bbr" | sudo tee --append /etc/modules-load.d/modules.conf
	echo "net.core.default_qdisc=fq" | sudo tee --append /etc/sysctl.conf
	echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee --append /etc/sysctl.conf
	sudo sysctl -p
	sysctl net.ipv4.tcp_available_congestion_control
	sysctl net.ipv4.tcp_congestion_control
}

install_bbr() {
	# 如果内核版本号满足最小要求
	if [ $VERSION_CURR ] >$VERSION_MIN; then
		check_bbr
	else
		update_core
	fi
}

install_docker() {
	if ! [ -x "$(command -v docker)" ]; then
		echo "开始安装 Docker CE"
		curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
		sudo add-apt-repository \
			"deb [arch=amd64] https://download.docker.com/linux/ubuntu \
            $(lsb_release -cs) \
            stable"
		sudo apt-get update -qq
		sudo apt-get install -y docker-ce
	else
		echo -e "${COLOR_SUCC}Docker CE 已经安装成功了${COLOR_NONE}"
	fi
}

check_docker() {
	if ! [ -x "$(command -v docker)" ]; then
		echo -e "${COLOR_ERROR}未发现Docker，请求安装 Docker ! ${COLOR_NONE}"
		return
	fi
}

check_container() {
	has_container=$(sudo docker ps --format "{{.Names}}" | grep -w "^$1")

	if [ -n "$has_container" ]; then
		return 0
	else
		return 1
	fi
}

install_certbot() {
	echo "开始安装 certbot 命令行工具"
	sudo apt-get update -qq
	sudo apt-get install -y software-properties-common
	sudo add-apt-repository universe
	sudo add-apt-repository ppa:certbot/certbot
	sudo apt-get update -qq
	sudo apt-get install -y certbot
}

create_cert() {
	if ! [ -x "$(command -v certbot)" ]; then
		install_certbot
	fi

	echo "开始生成 SSL 证书"
	echo -e "${COLOR_ERROR}注意：生成证书前,需要将域名指向一个有效的 IP,否则无法创建证书.${COLOR_NONE}"
	read -p "是否已经将域名指向了 IP？[Y/n]" has_record

	if ! [[ "$has_record" = "Y" ]]; then
		echo "请操作完成后再继续."
		return
	fi

	read -p "请输入你要使用的域名:" domain

	sudo certbot certonly --standalone -d $domain
}

create_nginx_static_file() {
	mkdir -p /var/www/html
	FILENAME=$1

	if [ -f "$FILENAME" ]; then
		return 0
	fi
	cat >$FILENAME <<EOF
<!DOCTYPE html>
<html>
  <head>
    <title>Welcome to nginx!</title>
    <style>
      html {
        color-scheme: light dark;
      }
      body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
      }
    </style>
  </head>
  <body>
    <h1>Welcome to nginx!</h1>
    <p>
      If you see this page, the nginx web server is successfully installed and
      working. Further configuration is required.
    </p>

    <p>
      For online documentation and support please refer to
      <a href="http://nginx.org/">nginx.org</a>.<br />
      Commercial support is available at
      <a href="http://nginx.com/">nginx.com</a>.
    </p>

    <p><em>Thank you for using nginx.</em></p>
  </body>
</html>
EOF
	return 0
}

set_config() {
	# check if docker installed
	if ! [ -x "$(command -v docker)" ]; then
		echo -e "${COLOR_ERROR}未发现Docker，请求安装 Docker ! ${COLOR_NONE}"
		return 1
	fi

	PROXY_TYPE=$1
	# check if container already exist
	if check_container $PROXY_TYPE; then
		echo -e "${COLOR_ERROR}$PROXY_TYPE 容器已经在运行了，你可以手动停止容器，并删除容器，然后再执行本命令来重新安装 ${COLOR_NONE}"
		return 1
	fi

	DEFAULT_PASS=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9+' | cut -c 1-16)
	NGINX_FILENAME="/var/www/html/proxy.html"

	read -p "请输入你要使用的域名 " DOMAIN

	if [ $PROXY_TYPE == "gost" ]; then
		DEFAULT_PORT=8443
		read -p "请输入 gost 侦听的端口号(默认 $DEFAULT_PORT) " PORT
		read -p "请输入你要使用的用户名 " USER
	else
		DEFAULT_PORT=9443
		read -p "请输入 hysteria 侦听的端口号(默认 $DEFAULT_PORT) " PORT
	fi

	read -p "请输入你要使用的密码(随机生成 $DEFAULT_PASS) " PASS

	echo -e "选择流量伪装方式\n"
	echo -e "\t1) 本地静态文件 (Nginx 默认页面)"
	echo -e "\t2) Web 代理 (https://news.ycombinator.com/)"
	echo -e "\t3) HTTP 状态码（404）"
	echo -e "\tq) 退出安装\n"
	read -p "输入选项 (1-3) " user_choice
	case $user_choice in
	1)
		if ! create_nginx_static_file $NGINX_FILENAME; then
			exit 1
		fi

		PROBE_RESISTTANCE="file:$NGINX_FILENAME"
		MASQUERADE_TYPE="file"
		;;
	2)
		PROBE_RESISTTANCE="web:news.ycombinator.com"
		MASQUERADE_TYPE="proxy"
		;;
	3)
		PROBE_RESISTTANCE="code:404"
		MASQUERADE_TYPE="string"
		;;
	*)
		echo -e "${COLOR_ERROR}无效的选择，请输入选项 (1-3) ${COLOR_NONE}"
		;;
	esac

	CERT_DIR=/etc/letsencrypt/live
	TLS_CERT_FILE=${CERT_DIR}/${DOMAIN}/fullchain.pem
	TLS_KEY_FILE=${CERT_DIR}/${DOMAIN}/privkey.pem

	if [ ! -f "$TLS_CERT_FILE" ] || [ ! -f "$TLS_KEY_FILE" ]; then
		echo -e "\n${COLOR_ERROR}证书文件不存在，请检查证书是否创建或域名是否填写正确。${COLOR_NONE}"
		exit 1
	fi

	if [[ -z "${USER// /}" ]]; then
		echo -e "\n${COLOR_ERROR}用户名不能为空 !${COLOR_NONE}"
		exit 1
	fi

	if ! [[ "${PORT}" =~ ^[0-9]+$ ]] || ! [ "$PORT" -ge 1 -a "$PORT" -le 655535 ]; then
		echo -e "\n${COLOR_ERROR}非法端口，使用默认端口 !${COLOR_NONE}"
		PORT=$DEFAULT_PORT
	fi

	if [[ -z "${PASS// /}" ]]; then
		PASS=$DEFAULT_PASS
	fi

	echo -e "\n\t${COLOR_SUCC}域名: ${DOMAIN}${COLOR_NONE}"
	echo -e "\t${COLOR_SUCC}端口: ${PORT}${COLOR_NONE}\n"
	echo -e "\n\t${COLOR_SUCC}用户名: ${USER}${COLOR_NONE}"
	echo -e "\t${COLOR_SUCC}密码: ${PASS}${COLOR_NONE}"
	return 0
}

install_gost() {

	echo -e "\nGost v3 配置\n"

	if ! set_config gost; then
		exit 1
	fi

	echo -e "开始启动 Gost v3 代理程序"

	GOST_CONFIG_FILE="/etc/gost.yml"
	rm -rf $GOST_CONFIG_FILE
	cat >$GOST_CONFIG_FILE <<EOF
services:
- name: service-0
  addr: ":$PORT"
  resolver: resolver-0
  handler:
    type: http2
    auth:
      username: $USER
      password: $PASS
    metadata:
      knock: www.google.com
      probeResistance: $PROBE_RESISTTANCE
    header:
      Proxy-Agent: None
  listener:
    type: http2
    tls:
      certFile: /etc/tls/cert.pem
      keyFile: /etc/tls/key.pem
resolvers:
- name: resolver-0
  nameservers:
  - addr: https://family.cloudflare-dns.com/dns-query
  - addr: tls://family.cloudflare-dns.com
  - addr: 1.1.1.3
  - addr: 1.0.0.3
  - addr: 2606:4700:4700::1113
  - addr: 2606:4700:4700::1003

EOF

	sudo docker run -d \
		--name gost \
		--network host \
		--restart always \
		--workdir /etc/gost \
		--volume $NGINX_FILENAME:$NGINX_FILENAME \
		--volume $TLS_CERT_FILE:/etc/tls/cert.pem:ro \
		--volume $TLS_KEY_FILE:/etc/tls/key.pem:ro \
		--volume $GOST_CONFIG_FILE:/etc/gost/gost.yml \
		gogost/gost -C /etc/gost/gost.yml

	echo -e "\n${COLOR_SUCC}gost 代理程序已经启动成功！${COLOR_NONE}"

	echo -e "\n${COLOR_ERROR}通过浏览器插件（e.g. SwitchyOmega）代理，请先访问 www.google.com${COLOR_NONE}\n"
	echo -e "Surge配置:\n"
	echo -e "\t${DOMAIN} = https, ${DOMAIN}, ${PORT}, username=${USER}, password=${PASS}, over-tls=true"
	echo -e "\nQuantumult X 配置:\n"
	echo -e "\thttp=${DOMAIN}:${PORT}, username=${USER}, password=${PASS}, over-tls=true, fast-open=false, udp-relay=false, tag=${DOMAIN}\n"
}

install_hysteria2() {
	echo -e "\nHysteria 2 配置\n"

	if ! set_config hysteria; then
		exit 1
	fi

	HYSTERIA_CONFIG_FILE="/etc/hysteria.yml"
	rm -rf $HYSTERIA_CONFIG_FILE
	cat >$HYSTERIA_CONFIG_FILE <<EOF
listen: :$PORT

tls:
  cert: /etc/tls/cert.pem
  key: /etc/tls/key.pem

auth:
  type: password
  password: $PASS 

resolver:
  type: udp
  tcp:
    addr: 1.1.1.3
    timeout: 4s 
  udp:
    addr: 1.1.1.3
    timeout: 4s
  tls:
    addr: family.cloudflare-dns.com
    timeout: 10s
    sni: cloudflare-dns.com 
    insecure: false 
  https:
    addr: family.cloudflare-dns.com/dns-query
    timeout: 10s
    sni: cloudflare-dns.com
    insecure: false

masquerade: 
  type: $MASQUERADE_TYPE
  file:
    dir: /var/www/html/index.html
  proxy:
    url: https://news.ycombinator.com/
    rewriteHost: true
  string:
    content: Not Found 
    headers: 
      content-type: text/plain
    statusCode: 404
EOF

	sudo docker run -d \
		--name hysteria \
		--restart always \
		--network host \
		--workdir /etc/hysteria \
		--volume $NGINX_FILENAME:/var/www/html/index.html \
		--volume $TLS_CERT_FILE:/etc/tls/cert.pem:ro \
		--volume $TLS_KEY_FILE:/etc/tls/key.pem:ro \
		--volume $HYSTERIA_CONFIG_FILE:/etc/hysteria/config.yml \
		tobyxdd/hysteria server -c /etc/hysteria/config.yml

	echo -e "\n${COLOR_SUCC}hysteria 代理程序已经启动成功！${COLOR_NONE}"
}

crontab_exists() {
	crontab -l 2>/dev/null | grep "$1" >/dev/null 2>/dev/null
}

create_cron_job() {
	# 写入前先检查，避免重复任务。
	if ! crontab_exists "cerbot renew --force-renewal"; then
		echo "0 0 1 * * /usr/bin/certbot renew --force-renewal" >>/var/spool/cron/crontabs/root
		echo "${COLOR_SUCC}成功安装证书renew定时作业！${COLOR_NONE}"
	else
		echo "${COLOR_SUCC}证书renew定时作业已经安装过！${COLOR_NONE}"
	fi

	if ! crontab_exists "docker restart gost"; then
		echo "5 0 1 * * /usr/bin/docker restart gost" >>/var/spool/cron/crontabs/root
		echo "${COLOR_SUCC}成功添加更新证书定时作业！${COLOR_NONE}"
	else
		echo "${COLOR_SUCC}更新证书定时作业已经添加！${COLOR_NONE}"
	fi
}

init() {
	VERSION_CURR=$(uname -r | awk -F '-' '{print $1}')
	VERSION_MIN="4.9.0"

	OIFS=$IFS # Save the current IFS (Internal Field Separator)
	IFS=','   # New IFS

	COLUMNS=50
	echo -e "\n菜单选项\n"

	while true; do
		PS3="请输入你的选项（1-7）"
		re='^[0-7]+$'
		select opt in "安装 TCP BBR 拥塞控制算法" \
			"安装 Docker 服务程序" \
			"创建 SSL 证书" \
			"安装 Gost v3 HTTP/2 代理服务" \
			"安装 Hyseria 2 代理服务" \
			"创建证书更新 CronJob" \
			"退出"; do
			if ! [[ $REPLY =~ $re ]]; then
				echo -e "\n${COLOR_ERROR}无效选项，请输入 1-7。${COLOR_NONE}\n"
				break
			elif ((REPLY == 1)); then
				install_bbr
				break
			elif ((REPLY == 2)); then
				install_docker
				break
			elif ((REPLY == 3)); then
				create_cert
				loop=1
				break
			elif ((REPLY == 4)); then
				install_gost
				break
			elif ((REPLY == 5)); then
				install_hysteria2
				break
			elif ((REPLY == 6)); then
				create_cron_job
				break
			elif ((REPLY == 7)); then
				exit
			else
				echo -e "\n${COLOR_ERROR}无效选项，请输入 1-7。${COLOR_NONE}\n"
			fi
		done
	done
	echo -e "${opt}"
	IFS=$OIFS # Restore the IFS
}

init
