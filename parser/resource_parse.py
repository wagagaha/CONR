# coding=utf-8

import re
import base64
import json

# 订阅格式转换
class Parser:
    """协议解析
    支持对 ss, ssr, vmess, torjan 等协议类型进行格式化解析
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
        """
        vmess parse
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
        vmess_share_format = {
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
        for k in vmess_share_format:
            vmess_share_format[k] = self.data[k]
        surge_vmess_format = f"{vmess_share_format['ps']} = vmess, {vmess_share_format['add']}, {vmess_share_format['port']}, username={vmess_share_format['id']}, skip-cert-verify=true, ws=true, vmess-aead=true, tls=true, tfo=true"
        print(surge_vmess_format)
        return surge_vmess_format
        

    # torjan parse
    def torjan(self):
        pass
        
    # parser 选择
    def parse(self) -> None:
        if self.protocol == "ssr":
            self.ssr()
        elif self.protocol == "ss":
            self.ss()
        elif self.protocol == "vmess":
            self.vmess()
        elif self.protocol == "torjan":
            self.torjan()
        else:
            print("unsupported protocol: ", self.protocol)
# 订阅下载
def download(url:str) -> str:
    pass
# 去重
def deduplicate() -> None:
    pass

#  解析标签
def tag_parser() -> None:
    pass




if __name__ == "__main__":
    data = "vmess://"
    p = Parser(data, "vmess")
    p.parse()    

