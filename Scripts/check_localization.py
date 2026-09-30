from pathlib import Path
import json,re
root=Path(__file__).resolve().parents[1]
def literal(s,i):
    assert s[i]=='"'; i+=1; out=''; n=0
    while i<len(s):
        if s[i]=='"': return out,i+1
        if s[i:i+2]=='\\(':
            depth=1;i+=2
            while depth:
                if s[i]=='"': _,i=literal(s,i);continue
                if s[i]=='(':depth+=1
                if s[i]==')':depth-=1
                i+=1
            out+='{'+str(n)+'}';n+=1
        elif s[i]=='\\':
            out+= {'n':'\n','t':'\t','"':'"','\\':'\\'}.get(s[i+1],s[i+1]);i+=2
        else:out+=s[i];i+=1
    raise ValueError('unterminated')
def keys():
    result=set()
    for p in (root/'Sources').glob('*.swift'):
        s=p.read_text()
        for m in re.finditer(r'(?<![A-Za-z0-9_])(?:text|t)\(\s*',s):
            i=m.end();depth=0
            while i<len(s):
                if s[i]=='"':
                    value,i=literal(s,i)
                    if depth==0:result.add(value)
                    continue
                if s[i] in '([':depth+=1
                if s[i] in ')]':
                    if depth==0:break
                    depth-=1
                if s[i]==',' and depth==0:break
                i+=1
    return result
catalog=json.loads((root/'Translations.json').read_text())
missing=keys()-catalog.keys()
assert not missing, 'Missing translations: '+repr(sorted(missing))
for key,values in catalog.items():
    assert len(values)==4, key
    for value in values:
        assert value and sorted(re.findall(r'\{\d+\}',key))==sorted(re.findall(r'\{\d+\}',value)), key
source=root/'Sources/Localization.swift'
header=source.read_text().split('enum TranslationCatalog {')[0]
generated=header+'enum TranslationCatalog {\n    // French, Simplified Chinese, German, Brazilian Portuguese.\n    static let entries: [String: [String]] = [\n'+',\n'.join('        '+json.dumps(k,ensure_ascii=False)+': '+json.dumps(v,ensure_ascii=False) for k,v in catalog.items())+'\n    ]\n}\n'
import sys
if '--generate' in sys.argv: source.write_text(generated)
else:
    entries={}
    for line in source.read_text().splitlines():
        if re.match(r'^\s*".*": \[',line): entries.update(json.loads('{'+line.strip().rstrip(',')+'}'))
    assert entries==catalog, 'Generated catalog is out of date; run with --generate'
print(f'PASS: {len(keys())} source templates covered; {len(catalog)} catalog entries in four additional languages')
