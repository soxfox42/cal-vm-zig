import re
import sys

_, infile, outfile = sys.argv

OPS = [
    "NOP",
    "JMP",
    "JNZ",
    "JZ",
    "ADD",
    "SUB",
    "MUL",
    "IMUL",
    "DIV",
    "IDIV",
    "MOD",
    "IMOD",
    "DUP",
    "OVER",
    "SWAP",
    "EQU",
    "NEQU",
    "GTH",
    "LTH",
    "IGTH",
    "ILTH",
    "AND",
    "OR",
    "XOR",
    "NOT",
    "WRB",
    "WRH",
    "WRW",
    "RDB",
    "RDH",
    "RDW",
    "CALL",
    "ECALL",
    "RET",
    "SHL",
    "SHR",
    "PUSH",
    "POP",
    "HALT",
]


class CalVMWriter:
    def __init__(self):
        self.code = bytearray()
        self.data = bytearray()
        self.target = self.code
        self.labels = {}
        self.patches = {}
        self.valid = True

    def to_code(self):
        self.target = self.code

    def to_data(self):
        self.target = self.data

    def write(self, *data):
        self.target += bytes(data)

    def ref(self, label):
        if label in self.labels:
            self.write(*self.labels[label].to_bytes(4, "little"))
        else:
            if label not in self.patches:
                self.patches[label] = []
            self.patches[label].append((self.target, len(self.target)))
            self.write(0, 0, 0, 0)

    def label(self, label):
        if label in self.labels:
            print("ERROR: duplicate label")
            self.valid = False
            return
        self.labels[label] = len(self.target)
        if label in self.patches:
            for buf, addr in self.patches[label]:
                buf[addr : addr + 4] = self.labels[label].to_bytes(4, "little")
            del self.patches[label]


out = CalVMWriter()

with open(infile) as f:
    source = f.read()

source = re.sub(r";[^\n]*\n", "\n", source)
# magic incantation that grabs space-separated tokens, but counts strings as one token
tokens = re.findall(r'"(?:[^\\"]|\\.)*"|[^\s]+', source)

def process_token(token):
    if token == "[code]":
        out.to_code()
    elif token == "[data]":
        out.to_data()
    elif token == "[resb]":
        out.write(0)
    elif token == "[resh]":
        out.write(0, 0)
    elif token == "[resw]":
        out.write(0, 0, 0, 0)
    elif token[0] == "#":
        out.write(0x24)
        process_token(token[1:])
    elif token[0] == "&":
        out.ref(token[1:])
    elif token[0] == "@":
        out.label(token[1:])
    elif match := re.match(r'^"(.*)"', token):
        value = match[1]
        out.write(*value.encode("utf-8"))
    elif re.match(r"^-?[0-9]+$", token):
        value = int(token)
        if value < 0:
            value = value & 0xFFFFFFFF
        out.write(*value.to_bytes(4, "little"))
    elif token in OPS:
        opcode = OPS.index(token)
        out.write(opcode)
    elif token[-1] == "i" and token[:-1] in OPS:
        opcode = OPS.index(token[:-1])
        out.write(0x80 | opcode)
    else:
        out.write(0x9f)
        out.ref(token)


for token in tokens:
    process_token(token)

if out.patches:
    print("ERROR: Unresolved labels")
    out.valid = False

if not out.valid:
    print("Errors found, not writing output.")
    sys.exit(1)

with open(outfile, "wb") as f:
    f.write(len(out.code).to_bytes(4, "little"))
    f.write(len(out.data).to_bytes(4, "little"))
    f.write(out.code)
    f.write(out.data)
