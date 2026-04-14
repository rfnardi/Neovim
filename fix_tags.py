
import os

filepath = 'lua/multi_context/init.lua'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

old_tag = '\u226a' + 'tool_end\u226b'
new_tag = chr(60) + '/tool_call' + chr(62)

count = content.count(old_tag)
content = content.replace(old_tag, new_tag)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print('Substituicoes realizadas: ' + str(count))
</arg_value>

