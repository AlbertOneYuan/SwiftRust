#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Collect native UI templates and reuse RustDesk's checked-in language tables."""
from pathlib import Path
import json,re,sys
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
native_sources = list((root/'flutter/ios/Runner').glob('*.swift')) + [root/'src/platform/ios_native.rs']
for path in native_sources:
    for raw in re.findall(quoted,path.read_text()):
        text=decode(raw)
        if text and re.search('[\u3400-\u9fff]',text) and '\\(' not in raw:sources.add(text)
# Reviewed English translations are checked in and never require Apple Translation.
english=json.loads((root/'scripts/ios/locales/en.json').read_text())
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
missing=sorted(source for source in sources if not translations['en'].get(source))
invalid=sorted(source for source,value in translations['en'].items() if source.count('%@')!=value.count('%@') or re.search('[\u3400-\u9fff]',value))
if missing or invalid:
    raise SystemExit(json.dumps({'missingEnglish':missing,'invalidEnglish':invalid},ensure_ascii=False))
if '--check' not in sys.argv:
    out.write_text(json.dumps(payload,ensure_ascii=False,separators=(',',':'))+'\n')
print(f'{len(languages)} languages; {len(sources)} native source templates; {out.stat().st_size} bytes')
