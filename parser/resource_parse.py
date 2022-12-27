# coding=utf-8

import re
import base64
import json
import requests
import urllib.parse
import configparser

LOCATION = [
    "香港", "新加坡", "日本","德国", "韩国", 
    "俄罗斯", "台湾", "英国", "西班牙", "迪拜", 
    "阿根廷", "巴西", "越南", "泰国", "印度", 
    "澳洲", "印尼", "荷兰", "土耳其", "法国",
    "加拿大", "美国", "菲律宾", "马来西亚"
]

# 订阅格式转换
class Parser:
    """协议解析
    支持对 ss, ssr, vmess, trojan 等协议类型进行格式化解析
    Attributes:
        url: 订阅地址
        format: 源格式
    """
    def __init__(self, data:list, format: str) -> None:
        self.data = data
        self.format = format
    # ssr parse
    def ssr(self) -> None:
        """ssr
        format: 
            ssr://base64({server}):{port}:{protocol}:{method}:{obfs}:{base64(password)}/?obfsparam={base64(obfsparam)}&protoparam={base64(protoparam)}&remarks={base64(remark)}&group={base64(group)})
        """        
        # split the data: ssr://{data}
        for i in range(len(self.data)):
            node = self.data[i]
            node = node.split("://")[-1].replace("_", "/").replace("-", "+")
            # padding alignment =
            node += (4 - len(node) % 4) * "="
            # base64 decode
            node = base64.b64decode(node).decode()
            share_format = {
                "server": "".join(re.findall(r"^([0-9a-zA-Z/.-]+):", node)),
                "port": "".join(re.findall(r":(\d+):", node)),
                "protocol": "".join(re.findall(r":\d+:([0-9a-zA-Z_-]+):", node)).replace("_", "-"),
                "method": "".join(re.findall(r":([0-9a-zA-A-]+):\w+:\w+//?", node)),
                "obfs": "".join(re.findall(r":(\w+):\w+/", node)),
                "password": "".join(re.findall(r":(\w+)//?", node)),
                "obfs_param": "".join(re.findall(r"obfsparam=(.*)&", node)),
                "proto_param": "".join(re.findall(r"&protoparam=(\w+)&", node)),
                "remarks": "".join(re.findall(r"&remarks=(\w+)&", node)),
                "group": "".join(re.findall(r"&group=(.*)$", node)),
            }
            tag = base64.b64decode(b64_padding(share_format['remarks'])).decode()
            password = base64.b64decode(b64_padding(share_format['password'])).decode()
            self.data[i] = f"{tag} = ss, {share_format['server']}, {share_format['port']}, encrypt-method=rc4-md5, password={password}, obfs=tls, obfs-host=6ddae15593.msn.microsoft.com"

    # ss parse
    def ss(self):
        pass

    def vmess(self) -> None:
        """vmess
        format:
            {
                "v": "2",
                "ps": "remark", 
                "add": "111.111.111.111",
                "port": "32000",
                "id": "1386f85e-657b-4d6e-9d56-78badb75e1fd", 
                "aid": "100",
                "scy": "zero",
                "net": "tcp",
                "type": "none",
                "host": "www.bbb.com",
                "path": "/",
                "tls": "tls",
                "sni": "www.ccc.com"
            }
        """
        for i in range(len(self.data)):
            # split the data: vmess://{data}
            node = self.data[i]
            node = node.split("://")[-1]
            # base64 decode
            node = base64.b64decode(node).decode().strip()
             # loads as json
            node = json.loads(node)
            self.data[i] = f"{node['ps']} = vmess, {node['add']}, {node['port']}, username={node['id']}, skip-cert-verify=true, ws=true, vmess-aead=true, tls=true, tfo=true"        

    # trojan parse
    def trojan(self) -> None:
        """trojan
        format:
            trojan://{password}@{host}:{port}?allowInsecure=1&peer=example.com&sni={sni}#{tag}
        """
        for i in range(len(self.data)):
            node = self.data[i]
            # split the data
            share_format = {
                "host": "".join(re.findall(r"trojan://[0-9a-zA-z-]+@(.*):", node)),
                "port": "".join(re.findall(r"trojan://.*:([0-9]+)", node)),
                "password": "".join(re.findall(r"trojan://([0-9a-zA-z-]+)@", node)),
                "sni": "".join(re.findall(r"sni=(.*)#", node)),
                "tag": "".join(re.findall(r"#(.*)$", node)),
            }
            self.data[i] = f"{share_format['tag']} = trojan, {share_format['host']}, {share_format['port']}, password={share_format['password']}, sni={share_format['sni']}, skip-cert-verify=true, tls=true, tfo=true"

    def surge(self) -> str:
        """surge format
        format: there could be including "obfs=" in the node list
        """ 
        node_list = []
        for line in self.data:
            if re.search("obfs=|encrypt-method=", line):
                node_list.append(line)
            elif node_list:
                self.data = node_list
                break
    # parser 选择
    def parse(self) -> None:
        if self.format == "ssr":
            self.ssr()
        elif self.format == "ss":
            self.ss()
        elif self.format == "vmess":
            self.vmess()
        elif self.format == "trojan":
            self.trojan()
        elif self.format == "surge":
            self.surge()
        else:
            print("unsupported protocol: ", self.format)
# 订阅下载
def download(url:str, b64:bool) -> str:
    """download from subscribe url
    Args:
        url: subscribe url
        b64: whether the data is Base64 encoded 
    Return:
        data
    """
    res = requests.get(url)
    if res.status_code == 200:
        text = res.text
        if b64:
            text = base64.b64decode(res.text).decode()
        data = urllib.parse.unquote(text)
        return data.strip()
    else:
        return ""

# base64 补齐 = 
def b64_padding(s: str) -> str:
    s += (4 - len(s) % 4) * "="
    return s
    

#  去重
def deduplicate(node_list: list) -> dict:
    node_dict = {}
    for n in node_list:
        tag = re.findall(r"^(.*?)=", n)[0]
        value = re.findall(r"=(.*?)$", n)[0]
        node_dict[value] = tag
    return node_dict

# 标签解析 
def tag_parser(prefix:str, node_dict: dict) -> dict:
    for k in node_dict:
        for loc in LOCATION:
            if loc in node_dict[k]:
                node_dict[k] = loc
                break
        if node_dict[k] not in LOCATION:
            node_dict[k] = "其他"
    # 根据 value(tag)排序
    node_dict = dict(sorted(node_dict.items(), key=lambda kv: kv[1]))
    cur_tag = ""
    index = 1
    for k,v in node_dict.items():
        if v != cur_tag:
            cur_tag = v
            index = 0
        node_dict[k] = f"{prefix}-{v}-{str(index).zfill(2)}"
        index+=1
    # 交换 key, value
    node_dict = dict(zip(node_dict.values(), node_dict.keys()))
    return node_dict
                
# 生成 Proxy Group
def gen_group(group_name:str, node_dict: dict) -> str:
    group = f"{group_name} = url-test, "
    node_tag = list(node_dict.keys())
    group += ", ".join(node_tag)
    group += ", url=http://cp.cloudflare.com/generate_204, interval=600, tolerance=50"
    return group

#  读取订阅配置文件
def read_config() -> dict:
    nodes = {}
    filename = "./subscribe.ini"
    subscribe = configparser.ConfigParser()
    subscribe.read(filename)
    for node in subscribe.sections():
        nodes[node] = {
            "url": subscribe[node]["url"],
            "b64encoded": subscribe[node].getboolean("b64encoded"),
            "format": subscribe[node]["format"], 
        }
    return nodes


if __name__ == "__main__":
    with open("./template.conf", "r") as fp:
        template = fp.read()
    fp = open("./custom.conf", "a+")
    fp.write(template)
    try:
        nodes = read_config()
    except:
        print("read subscribe file error")
        exit
    node_groups = []
    for k,v in nodes.items():
        # 配置下载
        try:
            node_raw_data = download(v["url"], v["b64encoded"])
        except:
            print(f"download node: [{k}] error")
            continue
        # 配置解析
        node_parsed_list = []
        try:
            node_raw_list = node_raw_data.split("\n")
            p = Parser(node_raw_list, v["format"])
            p.parse()
            node_parsed_list = p.data
        except:
            print(f"parser node: [{k}] error")
            continue
        # 配置去重
        node_deduplicate_dict = deduplicate(node_parsed_list)
        # 标签解析
        node_tag_parsed_dict = tag_parser(k.upper(), node_deduplicate_dict)
        for tag,v in node_tag_parsed_dict.items():
            line = f"{tag} = {v}\n"
            fp.write(line)
        # 节点分组
        node_groups.append(gen_group(k.upper(), node_tag_parsed_dict))
    with open("./custom.group", "r") as f:
        custom_group = f.read()
    fp.write(f"{custom_group}\n")
    for g in node_groups:
        fp.write(f"{g}\n")
    fp.close()