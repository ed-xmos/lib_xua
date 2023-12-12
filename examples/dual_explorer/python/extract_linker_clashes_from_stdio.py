import sys

text = "substitutions = [\n"

for line in sys.stdin:
    if 'Exit' == line.rstrip():
        break

    if "'" in line:
        if not "globound" in line:
            token = line.split("'")[1]
            if not "." in token:
                text += f'  "{token}",\n'

text += "]\n"


print (text)
