#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Collect native UI templates and reuse RustDesk's checked-in language tables."""
from pathlib import Path
import json,re
root=Path(__file__).resolve().parents[2]
quoted=r'"((?:\\.|[^"\\])*)"'
pair=re.compile(r'\(\s*'+quoted+r'\s*,\s*'+quoted+r'\s*\)',re.S)
def decode(text):
    try:return json.loads('"'+text+'"')
    except ValueError:return None
def table(path):
    return {decode(k):decode(v) for k,v in pair.findall(path.read_text()) if decode(k) and decode(v)}
lang_text=(root/'src/lang.rs').read_text().split('pub const LANGS:')[1].split('];')[0]
languages=[[decode(k),decode(v)] for k,v in pair.findall(lang_text)]
cn=table(root/'src/lang/cn.rs');reverse={v:k for k,v in cn.items()}
# SwiftUI uses shorter labels for the same existing RustDesk actions.
reverse.update({'外观':'Theme','浅色':'Light','深色':'Dark','鼠标':'Mouse mode','直接触控':'Touch mode','重新连接':'Reconnect','最近连接':'Recent sessions','系统键盘':'Keyboard','自定义快捷键':'Keyboard shortcuts'})
sources=set()
for path in (root/'flutter/ios/Runner').glob('Native*.swift'):
    for raw in re.findall(quoted,path.read_text()):
        text=decode(raw)
        if text and re.search('[\u3400-\u9fff]',text) and '\\(' not in raw:sources.add(text)
# Explicit native additions for a usable English entry before optional Apple translation.
english={'登录账号': 'Sign in',
 '启用网络代理': 'Enable Network Proxy',
 '使用 Auth key 登录': 'Sign in with Auth key',
 '密钥登录': 'Auth key Sign-in',
 '语言': 'Language',
 '跟随系统': 'Follow System',
 '翻译已保存': 'Translations saved',
 '苹果翻译暂不支持此语言。': 'Apple Translate does not support this language yet.',
 '苹果翻译补全需要 iOS 18 或更新版本。': 'Completing translations requires iOS 18 or later.',
 '翻译未完成，可稍后重试。': 'Translation did not finish. Try again later.',
 '无法保存翻译': 'Unable to save translations',
 '自动补全译文': 'Automatic Translation',
 '重试翻译': 'Retry Translation',
 '优先使用内置译文，缺失的界面文字自动使用苹果翻译补全并保存在本机。首次可能需要下载语言包；苹果不支持的语言保留原文。不会翻译远程画面、主机名或输入内容。': 'Built-in translations '
                                                                                 'are used first. Apple '
                                                                                 'Translate '
                                                                                 'automatically fills '
                                                                                 'missing interface '
                                                                                 'text and saves it on '
                                                                                 'this device. Language '
                                                                                 'downloads may be '
                                                                                 'required. Unsupported '
                                                                                 'languages retain the '
                                                                                 'original text. Remote '
                                                                                 'screens, hostnames '
                                                                                 'and input are never '
                                                                                 'translated.'}
alias={'zh-cn':'cn','zh-tw':'tw','pt-pt':'pt_PT','pt-br':'ptbr'}
translations={}
# Keep original Chinese core messages as lookup keys too; only UI templates are sent to Apple.
for code,_ in languages:
    path=root/'src/lang'/f'{alias.get(code,code)}.rs'
    if not path.exists() and code=='pt-br':path=root/'src/lang/pt_BR.rs'
    target=table(path) if path.exists() else {}
    values={}
    for source,key in reverse.items():
        value=target.get(key)
        if code=='en':value=value or (key if not re.search(r'_[a-z]',key) else None)
        if value and source.count('%@')==value.count('%@'):values[source]=value
    if code=='en':values.update(english)
    if code!='zh-cn':translations[code]=values
payload={'languages':languages,'sources':sorted(sources),'translations':translations}
out=root/'flutter/ios/Runner/NativeLanguages.json'
out.write_text(json.dumps(payload,ensure_ascii=False,separators=(',',':'))+'\n')
print(f'{len(languages)} languages; {len(sources)} native source templates; {out.stat().st_size} bytes')
