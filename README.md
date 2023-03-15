# CONR

Clean and Open Network Rules

在一些开源的代理规则 [SukkaW/Surge](https://github.com/SukkaW/Surge) 上，基于个人使用习惯，做了一些修改补充，持续更新

## Surge

Non CN Domain - 不在中国大陆、香港、台湾等提供服务
```bash
RULE-SET,https://raw.githubusercontent.com/wagagaha/CONR/master/Surge/non-cn-domain.conf
```
代理域名
```bash
RULE-SEt,https://raw.githubusercontent.com/wagagaha/CONR/master/Surge/proxy-domain.conf
```
直连域名
```bash
RULE-SET,https://raw.githubusercontent.com/wagagaha/CONR/master/Surge/direct-domain.conf
```
Apple Service - 不在中国大陆提供的服务或所提供的服务不完整，比如 Podcast, Apple News
```bash
RULE-SET,https://raw.githubusercontent.com/wagagaha/CONR/master/Surge/apple-service.conf
```
代理 CDN 域名
```bash
RULE-SET,https://raw.githubusercontent.com/wagagaha/CONR/master/Surge/proxy-cdn-domain.conf
```
代理流媒体域名
```
RULE-SET,https://raw.githubusercontent.com/wagagaha/CONR/master/Surge/proxy-stream-domain.conf
```
流媒体 IP 

```bash
RULE-SET,https://raw.githubusercontent.com/wagagaha/CONR/master/Surge/proxy-stream-ip.conf
```
其他 IP

```bash
RULE-SET,https://raw.githubusercontent.com/wagagaha/CONR/master/Surge/proxy-ip.conf
```






