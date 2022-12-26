# coding=utf-8

import re
import base64
import json
import requests
import urllib.parse

# 订阅格式转换
class Parser:
    """协议解析
    支持对 ss, ssr, vmess, trojan 等协议类型进行格式化解析
    Attributes:
        url: 订阅地址
        b64_encoded: 是否 base64 编码 
    """
    def __init__(self, data:str, protocol: str) -> None:
        self.data = data
        self.protocol = protocol
    # ssr parse
    def ssr(self):
        pass

    # ss parse
    def ss(self):
        pass

    def vmess(self) -> str:
        """vmess parse
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
        share_format = {
            "ps": None,
            "add": None,
            "port": None,
            "id": None,
        }
        # split the data: vmess://{data}
        self.data = self.data.split("://")[-1]
        # base64 decode
        self.data = base64.b64decode(self.data).decode()
        # loads as json
        self.data = json.loads(self.data) 
        for k in share_format:
            share_format[k] = self.data[k]
        surge_format = f"{share_format['ps']} = vmess, {share_format['add']}, {share_format['port']}, username={share_format['id']}, skip-cert-verify=true, ws=true, vmess-aead=true, tls=true, tfo=true"
        return surge_format
        

    # trojan parse
    def trojan(self):
        """trojan parse
        format:
            trojan://{password}@{host}:{port}?allowInsecure=1&peer=example.com&sni={sni}#{tag}
        """
        # split the data
        share_format = {
            "host": "".join(re.findall(r"trojan://[0-9a-zA-z-]+@(.*):", self.data)),
            "port": "".join(re.findall(r"trojan://.*:([0-9]+)", self.data)),
            "password": "".join(re.findall(r"trojan://([0-9a-zA-z-]+)@", self.data)),
            "sni": "".join(re.findall(r"sni=(.*)#", self.data)),
            "tag": "".join(re.findall(r"#(.*)$", self.data)),
        }
        surge_format = f"{share_format['tag']} = trojan, {share_format['host']}, {share_format['port']}, password={share_format['password']}, sni={share_format['sni']}, skip-cert-verify=true, tls=true, tfo=true"
        print(surge_format)
        return surge_format

        
        
    # parser 选择
    def parse(self) -> None:
        if self.protocol == "ssr":
            self.ssr()
        elif self.protocol == "ss":
            self.ss()
        elif self.protocol == "vmess":
            self.vmess()
        elif self.protocol == "trojan":
            self.trojan()
        else:
            print("unsupported protocol: ", self.protocol)
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
    if b64:
        res = base64.b64decode(res.text).decode()
    res = urllib.parse.unquote(res)
    print(res)
    return res
# 去重
def deduplicate() -> None:
    pass

#  解析标签
def tag_parser() -> None:
    pass




if __name__ == "__main__":
    pass

