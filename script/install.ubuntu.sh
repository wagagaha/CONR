#!/bin/bash

# Author
# original author: https://github.com/gongzili456
# modified by: https://github.com/haoel
# modified by: wagagaha


COLOR_ERROR="\e[38;5;198m"
COLOR_NONE="\e[0m"
COLOR_SUCC="\e[92m"



update_core(){
    echo -e "${COLOR_ERROR}当前系统内核版本太低 <$VERSION_CURR>,需要更新系统内核.${COLOR_NONE}"
    echo "请选择要安装的Ubuntu版本的内核："
    echo "1) Ubuntu 18.04 LTS (Bionic Beaver)"
    echo "2) Ubuntu 20.04 LTS (Focal Fossa)"
    echo "3) Ubuntu 22.04 LTS (Jammy Jellyfish)"
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

check_bbr(){
    has_bbr=$(lsmod | grep bbr)

    # 如果已经发现 bbr 进程
    if [ -n "$has_bbr" ] ;then
        echo -e "${COLOR_SUCC}TCP BBR 拥塞控制算法已经启动${COLOR_NONE}"
    else
        start_bbr
    fi
}

start_bbr(){
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
    if [ $VERSION_CURR > $VERSION_MIN ]; then
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


check_container(){
    has_container=$(sudo docker ps --format "{{.Names}}" | grep "$1")

    # test 命令规范： 0 为 true, 1 为 false, >1 为 error
    if [ -n "$has_container" ] ;then
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

    if ! [[ "$has_record" = "Y" ]] ;then
        echo "请操作完成后再继续."
        return
    fi

    read -p "请输入你要使用的域名:" domain

    sudo certbot certonly --standalone -d $domain
}


install_gost() {
    if ! [ -x "$(command -v docker)" ]; then
        echo -e "${COLOR_ERROR}未发现Docker，请求安装 Docker ! ${COLOR_NONE}" 
        return
    fi

    if check_container gost ; then
        echo -e "${COLOR_ERROR}Gost 容器已经在运行了，你可以手动停止容器，并删除容器，然后再执行本命令来重新安装 Gost。 ${COLOR_NONE}"
        return
    fi

    echo "准备启动 Gost 代理程序,为了安全,需要使用用户名与密码进行认证."
    read -p "请输入你要使用的域名：" DOMAIN
    read -p "请输入你要使用的用户名:" USER
    DEFAULT_PASS=$(openssl rand -base64 12)
    read -p "请输入你要使用的密码(随机生成 $DEFAULT_PASS):" PASS
    read -p "请输入HTTP/2需要侦听的端口号(443):" PORT

    echo "选择流量伪装方式"
    echo "1) HTTP 状态码(404)"
    echo "2) Web 服务(Nginx 默认页面)"
    while true; do
        read -p "输入选择 (1-2) 或者 q 退出安装: " user_choice
        case $user_choice in
          1)
              probe_resist="code:404"
              break
              ;;
          2)
              mkdir -p /var/www/html
              # write nginx default page to index.html
              cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
</body>
</html>
EOF
              # create www-data user and group
              sudo groupadd -g 101 www-data
              sudo useradd -u 101 -g 101 -d /var/www/html www-data
              sudo chown -R www-data:www-data /var/www/html
              probe_resist="file:/var/www/html/index.html"
              break
              ;;
          q)
              echo "程序退出"
              exit 1
              ;;
          *)
              echo -e "${COLOR_ERROR}无效的选择，请输入选择 (1-2) 或者 q 退出安装。${COLOR_NONE}"
              ;;
        esac
    done
    

    if [[ -z "${PORT// }" ]] || ! [[ "${PORT}" =~ ^[0-9]+$ ]] || ! [ "$PORT" -ge 1 -a "$PORT" -le 655535 ]; then
        echo -e "${COLOR_ERROR}非法端口,使用默认端口 443 !${COLOR_NONE}"
        PORT=443
    fi

    if [[ -z "${USER// }" ]]; then
        echo -e "${COLOR_ERROR}用户名不能为空 !${COLOR_NONE}"
        exit 1
    else
        echo -e "${COLOR_SUCC}用户名: ${USER}${COLOR_NONE}"
        exit 1
    fi

    if [[ -z "${PASS// }" ]]; then
        echo -e "${COLOR_SUCC}密码: ${USER}${COLOR_NONE}"
        PASS=$DEFAULT_PASS
    fi

    BIND_IP=0.0.0.0
    CERT_DIR=/etc/letsencrypt/
    CERT=${CERT_DIR}/live/${DOMAIN}/fullchain.pem
    KEY=${CERT_DIR}/live/${DOMAIN}/privkey.pem

    sudo docker run -d --name gost \
        -v ${CERT_DIR}:${CERT_DIR}:ro \
        --net=host ginuerzh/gost \
        -L "http2://${USER}:${PASS}@${BIND_IP}:${PORT}?cert=${CERT}&key=${KEY}&probe-resist=${probe_resist}"
}

crontab_exists() {
    crontab -l 2>/dev/null | grep "$1" >/dev/null 2>/dev/null
}

create_cron_job(){
    # 写入前先检查，避免重复任务。
    if ! crontab_exists "cerbot renew --force-renewal"; then
        echo "0 0 1 * * /usr/bin/certbot renew --force-renewal" >> /var/spool/cron/crontabs/root
        echo "${COLOR_SUCC}成功安装证书renew定时作业！${COLOR_NONE}"
    else
        echo "${COLOR_SUCC}证书renew定时作业已经安装过！${COLOR_NONE}"
    fi

    if ! crontab_exists "docker restart gost"; then 
        echo "5 0 1 * * /usr/bin/docker restart gost" >> /var/spool/cron/crontabs/root
        echo "${COLOR_SUCC}成功安装gost更新证书定时作业！${COLOR_NONE}"
    else
        echo "${COLOR_SUCC}gost更新证书定时作业已经成功安装过！${COLOR_NONE}"
    fi
}



init(){
    VERSION_CURR=$(uname -r | awk -F '-' '{print $1}')
    VERSION_MIN="4.9.0"

    OIFS=$IFS  # Save the current IFS (Internal Field Separator)
    IFS=','    # New IFS

    COLUMNS=50
    echo -e "\n菜单选项\n"

    while [ 1 == 1 ]
    do
        PS3="Please select a option:"
        re='^[0-6]+$'
        select opt in "安装 TCP BBR 拥塞控制算法" \
                    "安装 Docker 服务程序" \
                    "创建 SSL 证书" \
                    "安装 Gost HTTP/2 代理服务" \
                    "创建证书更新 CronJob" \
                    "退出" ; do

            if ! [[ $REPLY =~ $re ]] ; then
                echo -e "${COLOR_ERROR}Invalid option. Please input a number.${COLOR_NONE}"
                break;
            elif (( REPLY == 1 )) ; then
                install_bbr
                break;
            elif (( REPLY == 2 )) ; then
                install_docker
                break 
            elif (( REPLY == 3 )) ; then
                create_cert
                loop=1
                break
            elif (( REPLY == 4 )) ; then
                install_gost
                break
            elif (( REPLY == 5 )) ; then
                create_cron_job
                break
            elif (( REPLY == 6 )) ; then
                exit
            else
                echo -e "${COLOR_ERROR}无效选项，尝试另一个选项。${COLOR_NONE}"
            fi
        done
    done

     IFS=$OIFS  # Restore the IFS
}

init
