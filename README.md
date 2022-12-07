# CONR

Clean and Open Network Rules

PC 去除广告、网站分析追踪的规则，主要是通过一些第三方插件，移动设备主要是通过代理规则，在一些开源的代理规则 [SukkaW/Surge](https://github.com/SukkaW/Surge) 上，基于个人使用习惯，做了一些补充，持续更新


## 广告过滤

## Non CN Domain

不在中国大陆、香港、台湾等提供服务


```bash
# surge
RULE-SET,https://raw.githubusercontent.com/wagagaha/CONR/master/Surge/non-cn-domain.conf
```
## Apple Service

不在中国大陆提供的服务或所提供的服务不完整，比如 Podcast, Apple News

```bash
# surge
RULE-SET,https://raw.githubusercontent.com/wagagaha/CONR/master/Surge/apple-service.conf
```

## 流媒体

## 代理 Proxy

Domain

```bash
# surge
RULE-SET,https://raw.githubusercontent.com/wagagaha/CONR/master/Surge/proxy-domain.conf
```
IP
```bash
# surge
RULE-SET,https://raw.githubusercontent.com/wagagaha/CONR/master/Surge/proxy-ip.conf
```

## 直连Direct


