import sys

text = ""

for line in sys.stdin:
    if 'Exit' == line.rstrip():
        break

    if "'" in line:
        if not "globound" in line:
            token = line.split("'")[1]
            if not "." in token:
                text += f'#define {token}     {token}2\n'


print (text)
